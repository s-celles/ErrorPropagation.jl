```@meta
CurrentModule = SymbolicUncertainties
DocTestSetup = quote
    using SymbolicUncertainties, Symbolics, DynamicQuantities
end
```

# Getting Started

This page walks you through the core `SymbolicUncertainties.jl` workflow
in under 5 minutes: declare symbolic measurements, combine them with
ordinary arithmetic, and read off the closed-form uncertainty
expressions that `JCGM 100:2008` (GUM) prescribes.

!!! warning "Regulated-use disclaimer"
    `SymbolicUncertainties.jl` implements the methodology of JCGM 100:2008
    but has not been independently validated for calibration-
    accreditation contexts. See the [Limitations](limitations.md)
    page and `LICENSE.md` for the full non-warranty clause.

!!! note "Notation: `±` and the combined standard uncertainty"
    In this package, `a ± b` builds a measurement whose uncertainty
    field is a **combined standard uncertainty** `u_c`, matching the
    Julia ecosystem convention established by `Measurements.jl`. This
    **departs from JCGM 100:2008 §7.2.2**, which recommends presenting
    a result with its combined standard uncertainty using one of four
    textual forms (for example `m_S = 100.02147 g with u_c = 0.35 mg`
    or the parenthetical form `m_S = 100.02147(35) g`) and deliberately
    avoids the `±` glyph because it is historically associated with
    the expanded uncertainty `y ± U = y ± k·u_c` defined in §6.2. When
    producing a GUM-conformant calibration report, do **not** copy
    the Unicode `±` display verbatim — use one of the four §7.2.2
    textual forms instead, which [`report`](@ref) produces for you.
    See [Reporting a Result](reporting.md).

## Declare symbolic variables

```@example ohm
using Symbolics
using SymbolicUncertainties
using DynamicQuantities

@variables V σV I σI V1 σV1 V2 σV2
nothing # hide
```

Both `Symbolics` (for `@variables`) and `SymbolicUncertainties` (for
`SymbolicMeasurement` and `±`) need to be loaded.

## Build a measurement with `±`

The infix constructor `±` pairs an estimate with its standard
uncertainty:

```@example ohm
V_m = V ± σV
I_m = I ± σI
V1_m = V1 ± σV1
V2_m = V2 ± σV2
```

Either operand can be a `Symbolics.Num`, a plain `Number`, or a
mixture of the two. Plain numbers are promoted to symbolic literals
automatically:

```@example ohm
SymbolicMeasurement(1.5, 0.1)     # numeric constructor (unitless)
```

A negative numeric standard uncertainty is refused at construction
time — the standard uncertainty `u_c` must be non-negative per
JCGM 100:2008 §4.3.1:

```julia-repl
julia> SymbolicMeasurement(1.5, -0.1)
ERROR: ArgumentError: standard uncertainty must be non-negative (GUM §4.3.1)
```

## Combine measurements with the five binary operators

All five standard arithmetic operators (`+`, `-`, `*`, `/`, `^`) are
defined on `SymbolicMeasurement`. Each returns a new
`SymbolicMeasurement` whose `err` field carries the propagated
uncertainty expression implementing the relevant GUM §5.1 formula.

```@example ohm
V1_m + V2_m     # sum            — REQ-010
V1_m - V2_m     # difference     — REQ-011
V_m * I_m     # product        — REQ-012
V_m^2         # integer power  — REQ-014
V_m / I_m     # quotient       — REQ-013
```

Unary `-` and `+` are defined too. Negation goes through the same
chain rule with `c = -1`, so the source is preserved and a quantity
still cancels against its own negation; a sign change cannot alter a
dispersion, so `u_c` is unchanged (JCGM 100:2008 §4.3.1):

```@example ohm
-V_m          # same u_c as V_m
V_m + (-V_m)  # exactly zero, uncertainty included
```

Mixed-mode expressions with plain numbers or bare symbolic variables
also work — the non-measurement operand is treated as if it had zero
uncertainty:

```@example ohm
2 * V_m       # equivalent to (2 ± 0) * V_m
V_m / I       # I is a bare Symbolics.Num, not a measurement
```

A constant sensitivity is reported as `|c|·u` rather than
`sqrt(c²u²)`: `2 * V_m` carries `2σV`, not `sqrt(4σV²)`. The package
can make that reduction because a standard uncertainty is
non-negative by construction (REQ-005) — `Symbolics` cannot, since it
has no way to be told so
([Symbolics.jl#98](https://github.com/JuliaSymbolics/Symbolics.jl/issues/98)).

## Worked example — Ohm's law

The textbook GUM example `R = V / I` illustrates the quotient rule
for uncertainty propagation.

```@example ohm
R_m = V_m / I_m
```

The resulting measurement's `err` field is algebraically equivalent
to the GUM §5.1 reference form

```math
u_R = \frac{V}{I}\sqrt{\left(\frac{\sigma_V}{V}\right)^2 +
                          \left(\frac{\sigma_I}{I}\right)^2}
```

which you can reconstruct directly with `Symbolics`:

```@example ohm
reference_err = (V / I) * sqrt((σV / V)^2 + (σI / I)^2)
```

Numerical substitution confirms the equivalence:

```@example ohm
dict = Dict(V => 12.0, σV => 0.1, I => 0.5, σI => 0.005)
(
    Symbolics.substitute(R_m.err, dict),
    Symbolics.substitute(reference_err, dict),
)

# For physical units, use evaluate:
dict_units = Dict(V => 12.0u"V", σV => 0.1u"V", I => 0.5u"A", σI => 0.005u"A")
evaluate(R_m, dict_units)
```

!!! note "Repeated operands are exact"
    The binary operators track operand identity. If the same
    measurement appears several times in an expression, the shared
    source is recognised and its sensitivities combine before the
    variance is formed:

    ```jldoctest repeated
    julia> x = 8.4 ± 0.7
    8.4 ± 0.7

    julia> x - x
    0.0 ± 0

    julia> x / x
    1 ± 0

    julia> x + x
    16.8 ± 1.4
    ```

    (`x + x` is `2x` with uncertainty `2σ`, not `σ√2`.)

    A quantity records which independent sources it derives from,
    so there is no right and wrong way to write the same model: the
    operators and `propagate` give the same answer.

    Two measurements built by two separate `±` calls remain
    independent, even when written with the same symbols: two
    resistors of equal nominal tolerance are not the same resistor.

    See [Uncertainty Sources](uncertainty-sources.md) for the
    representation this rests on.

## Printing

A `SymbolicMeasurement` prints as `val ± err` in Unicode, with an
ASCII `+/-` fallback in contexts where Unicode is unavailable (for
example, plain-text log pipelines):

```@example ohm
show(stdout, V_m)
println()
show(IOContext(stdout, :unicode => false), V_m)
```

## What's next

[Sensitivity Analysis](sensitivity-analysis.md) covers the
mathematical functions — `sin`, `cos`, `log`, `exp`, `sqrt` and the
rest — and multi-variable propagation through a function you supply
(`propagate(f, measurements)`). [Uncertainty
Budget](uncertainty-budget.md) builds the EA-4/02 §7.3 table on top
of the JCGM 100:2008 §5.1.3 sensitivity coefficients.

## API reference

### The core type and its constructors

```@docs
SymbolicMeasurement
SymbolicMeasurement(::Symbolics.Num, ::Symbolics.Num)
SymbolicMeasurement(::Number, ::Number)
±(::Symbolics.Num, ::Symbolics.Num)
```

### Binary arithmetic operators

```@docs
Base.:+(::SymbolicMeasurement, ::SymbolicMeasurement)
Base.:-(::SymbolicMeasurement, ::SymbolicMeasurement)
Base.:*(::SymbolicMeasurement, ::SymbolicMeasurement)
Base.:/(::SymbolicMeasurement, ::SymbolicMeasurement)
Base.:^(::SymbolicMeasurement, ::Real)
```

### Unary arithmetic operators

```@docs
Base.:-(::SymbolicMeasurement)
Base.:+(::SymbolicMeasurement)
```

### Display

```@docs
Base.show(::IO, ::SymbolicMeasurement)
```
