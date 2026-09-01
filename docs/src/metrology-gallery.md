```@meta
CurrentModule = SymbolicUncertainties
```

# Metrology Gallery

Eight worked calibrations, in order of increasing difficulty. Each one
exists for a conclusion that the algebra makes visible and that a
single number does not — where the money should go, why a matched pair
beats two good resistors, why a budget computed at one point does not
describe the instrument.

Every example here is asserted end to end in `test/gallery/`.

## 1. Torque transducer — `M = F·L`

A known mass on a lever arm. Force `F ± σF` in newtons, arm length
`L ± σL` in metres, torque in newton-metres.

```@example gallery
using Symbolics, SymbolicUncertainties, DynamicQuantities

@variables F σF L σL

M = SymbolicMeasurement(F, σF) * SymbolicMeasurement(L, σL)
check_units(M, Dict(F => u"N", σF => u"N", L => u"m", σL => u"m"))
```

`Symbolics.substitute` does not itself evaluate — it replaces symbols
and leaves the arithmetic standing (`upstream-bugs.md` UB-001) — so
every numeric read on this page goes through `toexpr`:

```@example gallery
as_float(e, vals) =
    Float64(eval(Symbolics.toexpr(Symbolics.substitute(e, vals))))
nothing # hide
```

```@example gallery
torque = Dict(F => 98.0665, σF => 0.0015, L => 0.500, σL => 0.00005)
uncertainty_budget(M)
```

```@example gallery
Mnum = Symbolics.substitute(M, torque)
(Mnum.val, Mnum.err)   # N·m
```

The arm's relative uncertainty is `1e-4` against `1.5e-5` for the
force, so it contributes five times more. Halving it nearly halves
`u_c`; halving the force's barely moves it:

```@example gallery
sub(d) = as_float(M.err, d)
(
    base = sub(torque),
    better_arm = sub(merge(torque, Dict(σL => 0.000025))),
    better_force = sub(merge(torque, Dict(σF => 0.00075))),
)
```

## 2. Four-wire Kelvin measurement

Measuring a milliohm shunt two-wire fails: the lead resistance is
comparable to the resistand. Four-wire separates current injection
from voltage sensing. Voltage in volts, current in amperes, lead
resistance in ohms.

```@example gallery
@variables Vk σVk Ik σIk Rl σRl

four_wire = SymbolicMeasurement(Vk, σVk) / SymbolicMeasurement(Ik, σIk)
two_wire = four_wire - SymbolicMeasurement(Rl, σRl)

kelvin = Dict(
    Vk => 10.0e-3, σVk => 2.0e-6,
    Ik => 1.000, σIk => 0.0005,
    Rl => 5.0e-3, σRl => 0.2e-3,
)
(length(uncertainty_budget(four_wire)), length(uncertainty_budget(two_wire)))
```

Two rows against three. Correcting a two-wire reading for a *known*
lead resistance leaves that correction's own uncertainty in the
budget, where it dominates:

```@example gallery
uncertainty_budget(two_wire)
```

The four-wire model carries **no lead source at all** — the difference
shows as a missing row, not as a small number. That is a change of
measurement model in the sense of JCGM GUM-6:2020, not a change of
value.

## 3. Pressure transducer — two-point calibration

`p(r) = (r − r₀)·P/(r₁ − r₀)`, from a zero and a span point. Readings
in amperes (a 4–20 mA loop), reference pressure in pascals.

```@example gallery
@variables rd σrd r0 σr0 r1 σr1 Pref σPref

p = (SymbolicMeasurement(rd, σrd) - SymbolicMeasurement(r0, σr0)) *
    SymbolicMeasurement(Pref, σPref) /
    (SymbolicMeasurement(r1, σr1) - SymbolicMeasurement(r0, σr0))

check_units(
    p,
    Dict(
        rd => u"A", σrd => u"A",
        r0 => u"A", σr0 => u"A",
        r1 => u"A", σr1 => u"A",
        Pref => u"Pa", σPref => u"Pa",
    ),
)
```

```@example gallery
base = Dict(
    σrd => 4.0e-6,
    r0 => 4.0e-3, σr0 => 4.0e-6,
    r1 => 20.0e-3, σr1 => 4.0e-6,
    Pref => 1.0e6, σPref => 200.0,
)
contrib(vals) = Dict(
    r.name => as_float(r.contribution, vals) for r in uncertainty_budget(p)
)

low = contrib(merge(base, Dict(rd => 5.0e-3)))    # near zero
high = contrib(merge(base, Dict(rd => 19.0e-3)))  # near full scale
(low[:r0] > low[:r1], high[:r1] > high[:r0])
```

**The budget is not a property of the instrument.** Near the bottom of
the range the zero point dominates the two calibration constants; near
the top the span reading and the reference standard do. The relative
uncertainty is five times worse at the bottom, which is the physical
reason transducers are specified over a stated turndown.

## 4. Wheatstone bridge — matched ratio arms

At balance, `Rx = R₃·(R₁/R₂)`, everything in ohms.

```@example gallery
@variables Rb1 σRb1 Rb2 σRb2 Rb3 σRb3

independent =
    SymbolicMeasurement(Rb3, σRb3) *
    (SymbolicMeasurement(Rb1, σRb1) / SymbolicMeasurement(Rb2, σRb2))

a, b = declare_correlated(
    SymbolicMeasurement(Rb1, σRb1),
    SymbolicMeasurement(Rb2, σRb2),
    1.0,
)
perfect = SymbolicMeasurement(Rb3, σRb3) * (a / b)

bridge = Dict(
    Rb1 => 1000.0, σRb1 => 1.0,
    Rb2 => 1000.0, σRb2 => 1.0,
    Rb3 => 100.0, σRb3 => 0.01,
)
u(m) = as_float(m.err, bridge)
(independent = u(independent), matched = u(perfect))
```

Two independent 0.1 % arms give 0.14 Ω. **Perfectly matched arms of
equal relative tolerance contribute nothing at all**: what is left,
0.01 Ω, is exactly the standard's own 0.01 % carried through. The arms
enter as a ratio, so a common error cancels — the mechanism of
JCGM 100:2008 §H.4. An uncorrelated budget cannot see this.

## 5. Pt100 — Callendar–van Dusen

The standard gives resistance as a function of temperature,
`R(t) = R₀(1 + A·t + B·t²)`, while the measurand is the temperature.
The model is the **inverse**.

```@example gallery
@variables Rp σRp R0p σR0p

A = 3.9083e-3      # °C⁻¹
B = -5.775e-7      # °C⁻²

t = (-A + sqrt(A^2 - 4B * (1 - SymbolicMeasurement(Rp, σRp) /
                               SymbolicMeasurement(R0p, σR0p)))) / (2B)

sensitivity_coefficient(t, Rp)
```

That is `1/(R₀(A + 2B·t))`, the reciprocal of the direct relation's
slope. Because `B` is negative the slope falls as temperature rises,
so the same resistance uncertainty buys a worse temperature:

```@example gallery
R_at(x) = 100.0 * (1 + A * x + B * x^2)
u_at(x) = as_float(
    t.err,
    Dict(Rp => R_at(x), σRp => 0.01, R0p => 100.0, σR0p => 0.01),
)
(at_0C = u_at(0.0), at_600C = u_at(600.0))
```

A budget computed once, at one point, does not describe the
instrument.

!!! note "Units of the coefficients"
    `A` and `B` carry °C⁻¹ and °C⁻², and are written here as bare
    numbers. A dimensional check therefore verifies the part that can
    actually go wrong — that `R/R₀` is dimensionless — and not the
    coefficients themselves.

## 6. Thermocouple with cold-junction compensation

A thermocouple measures a *difference*, so the reading must be
referred back to 0 °C before the ITS-90 relation is inverted:
`E(T) = E_measured + E(T_cj)`.

```@example gallery
@variables Em σEm Tcj σTcj

a1 = 39.45e-6      # V/°C
a2 = 2.36e-8       # V/°C²

cj = SymbolicMeasurement(Tcj, σTcj)
total = SymbolicMeasurement(Em, σEm) + (a1 * cj + a2 * cj * cj)
T = (-a1 + sqrt(a1^2 + 4 * a2 * total)) / (2 * a2)

E_true(x) = a1 * x + a2 * x^2
tc = Dict(
    Em => E_true(300.0) - E_true(25.0), σEm => 2.0e-6,
    Tcj => 25.0, σTcj => 0.5,
)
uncertainty_budget(T)
```

```@example gallery
cs = Dict(r.name => as_float(r.contribution, tc) for r in uncertainty_budget(T))
(cold_junction = cs[:Tcj], voltmeter = cs[:Em], ratio = cs[:Tcj] / cs[:Em])
```

The cold junction enters through the Seebeck coefficient at its own
temperature, comparable to the one at the hot junction, so 0.5 °C
there costs about 0.47 °C on the measurand — **ten times the
voltmeter**. Ten times better voltage resolution changes nothing; ten
times better cold-junction sensing divides `u_c` by five. The budget
says which to buy, before the money is spent.

The polynomial is of ITS-90 *form* truncated to two terms,
illustrative of a type-K response rather than the standard's full
coefficient set: the point being made is structural, and a truncated
polynomial inverts in closed form.

## 7. Interferometric displacement — the air, not the laser

`d = N·λ/(2n)`, with `n` from the simplified Edlén form. Fringe count
dimensionless, wavelength in metres, air temperature in °C, pressure
in pascals.

```@example gallery
@variables Nf σNf λ σλ Ta σTa Pa σPa

n = 1 + 2.8793e-9 * SymbolicMeasurement(Pa, σPa) /
        (1 + 0.003661 * SymbolicMeasurement(Ta, σTa))
d = SymbolicMeasurement(Nf, σNf) * SymbolicMeasurement(λ, σλ) / (2 * n)

λ0 = 632.99139e-9
n0 = 1 + 2.8793e-9 * 101325 / (1 + 0.003661 * 20.0)
interf = Dict(
    Nf => 2 * n0 / λ0, σNf => 0.01,
    λ => λ0, σλ => λ0 * 1e-8,
    Ta => 20.0, σTa => 0.1,
    Pa => 101325.0, σPa => 50.0,
)
Dict(r.name => as_float(r.contribution, interf) for r in uncertainty_budget(d))
```

Over one metre: the stabilised laser contributes 10 nm, the air
temperature 93 nm at 0.1 °C, the pressure 134 nm at 50 Pa. In room
conditions — 1 °C and 300 Pa — the air wins by four orders of
magnitude. **A ten-times better laser changes nothing measurable.**

## 8. Gauge R&R — where ISO 5725 stops

A gauge R&R study decomposes the *observed* scatter into repeatability
and reproducibility, by analysis of variance. Figures below in
micrometres, as such a study reports them.

```@example gallery
@variables sr σsr so σso sc σsc sres σsres

repeat_ = SymbolicMeasurement(sr, σsr, Symbolics.Num(30.0))   # 30 dof
operator = SymbolicMeasurement(so, σso, Symbolics.Num(2.0))   # 3 operators
calibration = SymbolicMeasurement(sc, σsc, Symbolics.Num(1.0e12))
resolution = SymbolicMeasurement(sres, σsres, Symbolics.Num(1.0e12))

combined = repeat_ + operator + calibration + resolution

rr = Dict(
    sr => 0.0, σsr => 0.8,
    so => 0.0, σso => 0.6,
    sc => 0.0, σsc => 0.35,
    sres => 0.0, σsres => 0.25 / sqrt(3),   # rectangular, §4.3.7
)
num(e) = as_float(e, rr)
(
    rr_only = sqrt(0.8^2 + 0.6^2),
    with_type_B = num(combined.err),
    ν_eff = num(combined.dof),
)
```

Two consequences. The reported `u_c` is understated, here by 7 %,
because an R&R study yields Type A components only: the calibration of
the reference, the finite resolution and any systematic offset do not
vary between repeats and no amount of repeating reveals them.

And the coverage factor is inflated. Three operators give the
reproducibility term **two degrees of freedom**; Welch-Satterthwaite
lets that dominate, so `ν_eff` falls to about 17 rather than the naive
30, and `k` exceeds 2.1. Ten operators would barely change `u_c` and
would tighten the interval appreciably — an experiment-design
conclusion the budget hands over for free.
