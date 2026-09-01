```@meta
CurrentModule = SymbolicUncertainties
```

# Dimensional Analysis

Load `DynamicQuantities.jl` and `check_units` will tell you whether a
model holds together dimensionally.

It **returns a report and never throws**. A unit mistake is something
you want to be told about, not something that should stop you
mid-derivation — which is what an earlier construction-time
`DimensionError` did.

```@example dimensional-analysis
using Symbolics, SymbolicUncertainties, DynamicQuantities

@variables V I
check_units(V / I, Dict(V => u"V", I => u"A"))
# UnitReport: consistent

check_units(V + I, Dict(V => u"V", I => u"A"))
# UnitReport: 1 finding(s)
#   • + in `I + V` — dimensions differ (A vs m² kg s⁻³ A⁻¹)
```

Units are an **annotation of the symbol**, supplied in a dictionary,
never a value inside the expression. `ModelingToolkit` makes the same
choice — it holds units in variable metadata — and the reason is
practical: a quantity living inside the expression tree would be
dragged through every simplification and every derivative.

## Checking a measurement

Passing a `SymbolicMeasurement` also checks something no other tool
does: that the combined uncertainty carries the dimension of the
measurand. It is the most common unit error in a budget, and it is
structurally invisible elsewhere because `y` and `u` live in
different fields.

```@example dimensional-analysis
@variables σV σI
m = (V ± σV) / (I ± σI)
check_units(m, Dict(V => u"V", σV => u"V", I => u"A", σI => u"A"))
```

## Dimension is not enough

Three cases defeat a plain dimension check. Each has its own
annotation, because dimensional equality is necessary but never
sufficient to decide that two quantities may be combined.

### Affine scales — °C, °F

`20 °C + 20 °C` is not `40 °C`. The zero of an affine scale is
conventional, so absolute values do not add; only differences are
proper intervals on the base unit. Both sides carry dimension Θ, so a
dimension check passes it without a murmur.

```@example dimensional-analysis
using SymbolicUncertainties: Affine, Scaled, Kind
@variables T1 T2
celsius = Affine(u"K", :celsius, 273.15)

check_units(T1 + T2, Dict(T1 => celsius, T2 => celsius))  # reports
check_units(T1 - T2, Dict(T1 => celsius, T2 => celsius))  # consistent
```

The metrological corollary matters more than the arithmetic one: **an
uncertainty stated in °C is a kelvin interval**, never an absolute
temperature. A dispersion has no origin (JCGM 100:2008 §4.3.1).

### Dimensionless is not one thing — %, ppm, dB

All three are dimensionless and none is interchangeable with another.
`dB` is additionally logarithmic, so it does not even combine
additively the way `%` and `ppm` do.

```@example dimensional-analysis
pct = Scaled(:percent, 1e-2)
ppm = Scaled(:ppm, 1e-6)
dB  = Scaled(:dB, nothing; logarithmic = true)
```

### Same dimension, different quantity

Torque and energy are both N·m. Activity and frequency are both s⁻¹.
Adding a torque to an energy is a modelling error that dimensional
analysis alone declares perfectly valid.

```@example dimensional-analysis
@variables M E
torque = Kind(u"N*m", :torque)
energy = Kind(u"N*m", :energy)

check_units(M + E, Dict(M => torque, E => energy))   # reports
```

Per VIM §1.1 a quantity is not defined by its dimension; `Kind`
records the part the dimension leaves out.

## Getting the answer back with its unit

`check_units` verifies a model; [`evaluate`](@ref) uses the same walk
to *derive* the unit of a result:

```@example units
using SymbolicUncertainties, Symbolics, DynamicQuantities
@variables V I σV σI

r = (V ± σV) / (I ± σI)

evaluate(r, Dict(V => 5.0us"V", σV => 0.01us"V",
                 I => 0.5us"A", σI => 0.001us"A"))
```

The unit on that answer was not written by anyone: it is what the
model computes. A worked example that ends in a bare `10.0` and a
`# ohms` comment records what its author believed the model produces,
which is a different thing and is exactly the discrepancy dimensional
analysis exists to expose.

The estimate and the uncertainty are annotated **independently**, so a
`u_c` whose dimension has drifted from its own measurand
(JCGM 100:2008 §4.3.1) shows up in the returned pair rather than
hiding in a separate field. Where they agree — as they must in a
correct model — the uncertainty is reported in the estimate's own
unit.

Values may be `us"..."` quantities, `u"..."` quantities, or plain
reals for dimensionless inputs like a gain. `us"..."` keeps unit names
(`A⁻¹ V`) while `u"..."` reduces to SI base dimensions
(`m² kg s⁻³ A⁻²`); the two are interchangeable and compare correctly
against each other.

Every variable needs a value: `evaluate` raises rather than returning
a half-substituted expression, since there would be no number to carry
a unit. Use `Symbolics.substitute` for partial substitution.

## Why DynamicQuantities rather than Unitful

`Unitful` encodes units in the *type parameter*, so every distinct
unit combination is a distinct concrete type. `DynamicQuantities`
keeps dimensions in a runtime field, so one type covers V, A, Ω and W
alike. That matters here because an uncertainty budget's rows are
deliberately heterogeneous in unit.

It is also the system `ModelingToolkit` actually validates: its
`screen_unit` accepts `DynamicQuantities` quantities and passes
`Unitful` metadata through unchecked. Since the package ships an MTK
extension, matching that avoids a backend switch mid-model.

Both packages export `@u_str`, so `using` them together makes `u"V"`
ambiguous. That is not a reason to pick one — `DynamicQuantities`'
own README shows the coexistence idiom, `using DynamicQuantities;
import Unitful`, and a qualified `Unitful.u"V"` works fine. It is
simply a thing to know if you keep both loaded.

## API

```@docs
check_units
evaluate
UnitReport
UnitFinding
is_consistent
Affine
Scaled
Kind
interval_unit
```
