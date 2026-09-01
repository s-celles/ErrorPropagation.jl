```@meta
CurrentModule = SymbolicUncertainties
```

# Protocol Optimisation

The protocol-optimisation layer turns the GUM forward-
propagation pipeline into a **design tool**: answer the
precision-requirement question and the budget-allocation
question in closed form.

Two operations:

- `required_precision(m, σᵢ, target_uc)` — the analytical
  "precision condition" on `σᵢ` to meet a target combined
  standard uncertainty (EARS REQ-060).
- `budget_allocation(m, variables, sigmas, total_budget)` —
  the Lagrange-multiplier optimal allocation of a fixed total
  budget across inputs (REQ-061).

## `required_precision` — inequality framing

```@example protocol-optimisation
using Symbolics, SymbolicUncertainties

@variables V I σV σI
R = (V ± σV) / (I ± σI)

cond = required_precision(R, σV, 0.01)
```

Read the returned `Num` as the boundary value: `σV` values
strictly below satisfy `m.err < target_uc`; values equal
saturate; values above violate.

`required_precision` is implemented as a direct delegate to
[`infer_precision`](inverse-inference.md) — see
`specs/007-protocol-and-inference/research.md` R6 for the
rationale. Both functions return the same `Num` expression;
the distinct names preserve the two EARS framings (precision
condition REQ-060 vs. solved equation REQ-090).

## `budget_allocation` — Lagrange-optimal distribution

Given a fixed total uncertainty budget the measurement can
afford, `budget_allocation` returns the per-input `σᵢ*` that
**minimises** `m.err` subject to `Σᵢ σᵢ = total_budget`. The
closed form is the inverse-sensitivity-squared weighting:

```
σᵢ* = total_budget · (1 / cᵢ²) / Σⱼ (1 / cⱼ²)
```

where `cᵢ = sensitivity_coefficient(m, xᵢ)`.

### Symmetric example

For a pure sum `m = a + b + c` with total budget `B`, all
three sensitivity coefficients are 1, so every input gets
`B/3` — the symmetric optimum:

```@example protocol-optimisation
@variables a σa b σb c σc
m = propagate((x, y, z) -> x + y + z, [a ± σa, b ± σb, c ± σc])

alloc = budget_allocation(m, [a, b, c], [σa, σb, σc], 1.0)
# alloc[σa] = alloc[σb] = alloc[σc] = 1/3 after numeric
# evaluation.
```

### Asymmetric example

For `m = 2a + 3b` the sensitivity coefficients are `c_a = 2`,
`c_b = 3`, so the inverse-squared weighting is
`1/4 : 1/9` ⇒ the σ allocation ratio is `9 : 4`. This is the
stationarity condition `cᵢ²·σᵢ = cⱼ²·σⱼ`.

```@example protocol-optimisation
alloc = budget_allocation(
    propagate((x, y) -> 2x + 3y, [a ± σa, b ± σb]),
    [a, b], [σa, σb], 1.0,
)
# alloc[σa] ≈ 9/13,  alloc[σb] ≈ 4/13.
```

### Error paths

- `length(variables) != length(sigmas)` → `DimensionMismatch`.
- Numeric `total_budget < 0` → `ArgumentError`.
- Every sensitivity coefficient zero (measurand independent
  of every supplied input) → `ArgumentError` per REQ-091.

Per-variable `sensitivity_coefficient` failures (e.g. the
REQ-021 unresolved-differential path) propagate unchanged.

## API reference

```@docs
required_precision
budget_allocation
```
