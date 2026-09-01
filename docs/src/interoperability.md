```@meta
CurrentModule = SymbolicUncertainties
```

# Interoperability

Three optional package extensions turn `SymbolicUncertainties.jl`
into a hub for broader Julia scientific-computing
workflows. Each activates automatically when the
triggering package is loaded.

## `Latexify.jl` — calibration-certificate LaTeX

```@example interoperability
using Symbolics, SymbolicUncertainties, Latexify

@variables V I σV σI
R = (V ± σV) / (I ± σI)

latex(R)
# e.g. "\\frac{V}{I} \\pm \\sqrt{\\frac{σV^{2}}{I^{2}} + \\frac{V^{2} σI^{2}}{I^{4}}}"
```

The fallback's `ArgumentError` is replaced by the
`SymbolicUncertaintiesLatexifyExt` extension. Use the returned
`String` directly in your LaTeX calibration-certificate
template.

## `Measurements.jl` — convert a substituted measurement

!!! warning "Load `Measurements` with `import`, not `using`"
    `Measurements.jl` exports `±` as well. `using` both packages makes
    the operator ambiguous and unusable — Julia resolves neither. Use
    `import Measurements` and qualify the call, the same idiom
    `DynamicQuantities` recommends for coexisting with `Unitful`.

    **`Distributions.jl` collides the same way**, through
    `IntervalSets`, and that one is harder to avoid: a
    [Monte Carlo cross-check](monte-carlo-validation.md) requires it,
    since JCGM 101:2008 §6.4 wants a density per input. In such a
    session, build measurements with the constructor —
    `SymbolicMeasurement(V, σV)` — rather than with `±`.

Bridge to the standard Julia uncertainty type for numerical
pipelines:

```@example interoperability
using Symbolics, SymbolicUncertainties, DynamicQuantities
import Measurements

# A mass of 5.000 g with u_c = 0.1 mg. `Measurement` carries the
# number and its dispersion; the unit rides alongside it.
m = 5.0 ± 0.0001
Measurements.Measurement(m) * us"g"
```

`substitute` does **not** auto-promote — the conversion is
explicit:

```@example interoperability
@variables V I σV σI
R = (V ± σV) / (I ± σI)

ohm = Dict(V => 5.0us"V", σV => 0.01us"V", I => 0.5us"A", σI => 0.001us"A")

# `Measurement` needs plain numbers, so the values are stripped for the
# conversion — and the unit of the answer is taken from
# [`evaluate`](@ref), which derives it from the model rather than
# leaving it to be asserted here.
R_num = Symbolics.substitute(R, Dict(k => ustrip(v) for (k, v) in ohm))

Measurements.Measurement(R_num) * oneunit(evaluate(R, ohm).val)
```

Conversion fails with `ArgumentError` when either `m.val`
or `m.err` is still symbolic — call `substitute` first.

## `DataFrames.jl` — tabular `uncertainty_budget` output

Opt into a `DataFrame` rendering via the `as = :dataframe`
keyword; the default `:budget` returns the
[`UncertaintyBudget`](@ref) value itself, which already indexes and
iterates as a vector of its rows:

```@example interoperability
using SymbolicUncertainties, Symbolics, DataFrames

@variables V σV R1 σR1 R2 σR2
Vout = propagate(
    (v, r1, r2) -> v * r2 / (r1 + r2),
    [V ± σV, R1 ± σR1, R2 ± σR2],
)

df = uncertainty_budget(
    Vout,
    [V, R1, R2],
    [σV, σR1, σR2];
    as = :dataframe,
)
# df isa DataFrame with 3 rows and columns
#   variable, sigma, sensitivity, contribution, relative
```

Export to CSV, join with other tabular data, apply filters
— the full `DataFrames.jl` ergonomics are available. When
DataFrames.jl is not loaded, requesting `as = :dataframe`
raises `ArgumentError`.

## Combined workflow

All three extensions compose cleanly:

```@example interoperability
using Symbolics, SymbolicUncertainties, DynamicQuantities
using Latexify, DataFrames
import Measurements

# Build, propagate, report.
@variables V σV R1 σR1 R2 σR2
Vout = propagate(
    (v, r1, r2) -> v * r2 / (r1 + r2),
    [V ± σV, R1 ± σR1, R2 ± σR2],
)

# Tabular budget.
df = uncertainty_budget(
    Vout,
    [V, R1, R2],
    [σV, σR1, σR2];
    as = :dataframe,
)

# LaTeX for the certificate.
tex = latex(Vout)

# Numeric final result, in volts.
divider = Dict(
    V => 5.0us"V", σV => 0.01us"V",
    R1 => 1_000.0us"Ω", σR1 => 1.0us"Ω",
    R2 => 3_000.0us"Ω", σR2 => 1.0us"Ω",
)
Vout_num = Symbolics.substitute(
    Vout,
    Dict(k => ustrip(v) for (k, v) in divider),
)
meas = Measurements.Measurement(Vout_num) * oneunit(evaluate(Vout, divider).val)
```

## API reference

The extensions overload methods on existing functions —
no new exports are introduced at the `SymbolicUncertainties`
public surface (REQ-132 audit).

- [`latex`](@ref) — the extension adds the working method
  at load time; the fallback keeps its docstring.
- [`uncertainty_budget`](@ref) — gains the
  `as = :budget | :dataframe` keyword.
- `Measurements.Measurement(m)` — a constructor on
  Measurements.jl's type, visible to users via the
  external package's namespace.
