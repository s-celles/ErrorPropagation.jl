```@meta
CurrentModule = SymbolicUncertainties
```

# Uncertainty Budget

The **uncertainty budget** is the per-variable breakdown of the
combined standard uncertainty `u_c(y)`. It is the EA-4/02 §7.3
deliverable of every calibration report — one row per input
variable, showing how much each contributes and how sensitive
the measurand is to it.

`SymbolicUncertainties.jl` provides four purely-symbolic helpers that
compose cleanly: `sensitivity_coefficient`,
`uncertainty_contribution`, `relative_sensitivity`, and the
one-call `uncertainty_budget` that assembles all three into the
EA-4/02 §7.3 table.

The governing normative sections are JCGM 100:2008 §5.1.3
equations (11a) and (11b), and EA-4/02 §7.3 for the row layout.

## Per-variable helpers

`sensitivity_coefficient(m, xᵢ)` returns the symbolic
`cᵢ = ∂(m.val)/∂xᵢ` via `Symbolics.derivative`. It returns
`Num(0)` when the variable does not appear in the measurand.

```@example uncertainty-budget
using Symbolics
using SymbolicUncertainties
using DynamicQuantities

@variables Vin σVin R1 σR1 R2 σR2
Vout = propagate(
    (vin, r1, r2) -> vin * r2 / (r1 + r2),
    [Vin ± σVin, R1 ± σR1, R2 ± σR2],
)

sensitivity_coefficient(Vout, Vin)  # R2/(R1+R2)
sensitivity_coefficient(Vout, R1)   # -Vin·R2/(R1+R2)²
sensitivity_coefficient(Vout, R2)   #  Vin·R1/(R1+R2)²
```

`uncertainty_contribution(m, xᵢ, σᵢ)` returns
`|cᵢ|·σᵢ` — the individual uncertainty contribution of `xᵢ`.

`relative_sensitivity(m, xᵢ, σᵢ)` returns
`(cᵢ·σᵢ)² / u_c²(y)` — the EA-4/02 §7.3 "percentage-of-variance"
column. Summing the relative sensitivities across all
**uncorrelated** input variables and applying
`Symbolics.simplify` returns `1`.

## The one-call budget table — `uncertainty_budget`

`uncertainty_budget(m)` returns an [`UncertaintyBudget`](@ref): a
vector of [`BudgetRow`](@ref)s following the EA-4/02 §7.3 layout,
together with the three facts a bare vector of rows cannot carry —
the measurand `y` the rows decompose, the `u_c` they recombine into,
and whether declared correlations are in play.

The rows come from the quantity's **own sources**: `m` knows which
independent measurements it descends from and with what sensitivity,
so no `variables` / `sigmas` list is required (REQ-206). A source
that cancelled produces no row at all. The three-argument form
`uncertainty_budget(m, variables, sigmas)` remains available as a
*filter* when only some inputs are of interest.

| Field          | Meaning                                                                 |
|----------------|-------------------------------------------------------------------------|
| `source`       | Identity of the independent source (source-derived rows)                |
| `variable`     | The input variable `xᵢ` (variable-filtered rows)                        |
| `sigma`        | Its standard uncertainty `u(xᵢ)`                                        |
| `sensitivity`  | `cᵢ = ∂(m.val)/∂xᵢ` (JCGM 100:2008 §5.1.3 eq (11b))                     |
| `contribution` | `uᵢ(y) = abs(cᵢ)·σᵢ` (JCGM 100:2008 §5.1.3 eq (11a))                    |
| `relative`     | `(cᵢ·σᵢ)² / u_c²(y)` (EA-4/02 §7.3 "%-of-variance" column)              |

```@example uncertainty-budget
budget = uncertainty_budget(Vout)
```

The budget prints as a table and still indexes and iterates as a
vector of its rows, so every consumer written against the earlier
`Vector{NamedTuple}` keeps working:

```@example uncertainty-budget
length(budget), budget.correlated, budget[1].contribution
```

Passing the variables explicitly filters the same table:

```@example uncertainty-budget
filtered = uncertainty_budget(
    Vout,
    [Vin, R1, R2],
    [σVin, σR1, σR2],
)

# filtered[1].variable     == Vin
# filtered[1].sensitivity  == R2/(R1+R2)
# filtered[1].contribution == abs(R2/(R1+R2)) · σVin
# filtered[1].relative     == (R2/(R1+R2))² · σVin² / Vout.err²
```

### Variance-decomposition invariant (SC-002)

For uncorrelated inputs, the sum of the relative sensitivities
across the complete input list simplifies to `1`:

```@example uncertainty-budget
Symbolics.simplify(sum(row.relative for row in filtered))
# → 1
```

Under a **declared correlation** the column is no longer a
decomposition: the JCGM 100:2008 §5.2.2 equation (13) cross terms
belong to no single row, so the fractions no longer sum to 1 and a
negative cross term can push one row past 100 %. That is what
`budget.correlated` reports, and why it is on the budget rather than
left for the reader to infer.

This is asserted by `test/budget/test_variance_decomposition.jl`
for the linear, product, and voltage-divider cases, and by the
exit-gate test
`test/examples/test_budget_voltage_divider.jl` for the full
three-input voltage divider.

### Error handling

- `length(variables) != length(sigmas)` raises
  `DimensionMismatch`.
- A variable that does not appear in `m.val` produces a row with
  `sensitivity = 0`, `contribution = 0`, `relative = 0` — not
  an error.
- A measurand whose derivative the symbolic engine cannot
  resolve propagates the REQ-021 `ArgumentError` from
  `sensitivity_coefficient`, directing the user at the
  `apply(f, m; derivative = ...)` escape hatch.

## Dominant source — `dominant_source`

`dominant_source(m, variables, sigmas; values=nothing)` returns
the input variable whose variance contribution dominates the
budget — the EA-4/02 §7.3 convention for "where should I focus
calibration effort?" Call without `values` to get a symbolic
first-variable-wins result (with an `@info` diagnostic about the
order-dependence), or pass a substitution dictionary for a
numeric `argmax`:

```@example uncertainty-budget
dom = dominant_source(
    Vout,
    [Vin, R1, R2],
    [σVin, σR1, σR2];
    # Volts and ohms. `dominant_source` ranks plain numbers, so the
    # values are stripped where it needs them; declaring them with
    # units keeps the reader from having to guess the scale.
    values = Dict(
        k => ustrip(v) for (k, v) in Dict(
            Vin => 5.0us"V", σVin => 0.01us"V",
            R1 => 1_000.0us"Ω", σR1 => 10.0us"Ω",
            R2 => 3_000.0us"Ω", σR2 => 10.0us"Ω",
        )
    ),
)
# dom.index, dom.variable, dom.contribution, dom.ranked_by
```

When every sensitivity coefficient is structurally zero (the
measurand does not depend on any variable in the list), the
function returns `(index=0, …)` and emits a `@warn`.

## Rendering the budget

An `UncertaintyBudget` is an `AbstractVector` of its rows, so it
composes with every Julia table-rendering library without the package
depending on one. `as = :dataframe` renders through the
`DataFrames.jl` extension:

```julia
using DataFrames, PrettyTables
pretty_table(uncertainty_budget(Vout; as = :dataframe))
```

The `SymbolicUncertainties.jl` runtime has **no** hard dependency on
either package.

## API reference

```@docs
sensitivity_coefficient
uncertainty_contribution
relative_sensitivity
uncertainty_budget
UncertaintyBudget
BudgetRow
dominant_source
```
