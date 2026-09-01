```@meta
CurrentModule = SymbolicUncertainties
```

# Reporting a Result

A propagated measurement is not yet a reported one. JCGM 100:2008 §7
governs how a result is written down, and what it says is more
prescriptive than most software admits: there are four acceptable
textual forms, a rule for how many digits to quote, and a separate
statement for expanded uncertainty that must name its coverage factor.

`report` produces them.

## The four forms of §7.2.2

The GUM's own worked example is a 100 g mass standard whose calibration
gives `m_S = 100.02147 g` with `u_c = 0.35 mg`:

```@example reporting
using SymbolicUncertainties

report(100.02147, 0.00035; symbol = "m_S", unit = "g")
```

All four say the same thing. Which one belongs on a certificate is a
house-style question, not a metrological one.

!!! warning "`±` is not the first choice, and the package's own display is not a report"
    A `SymbolicMeasurement` prints as `val ± err` because that is the
    Julia ecosystem convention, set by `Measurements.jl`. **§7.2.2
    deliberately avoids the glyph**: `±` is read as an expanded
    uncertainty `y ± U` (§6.2), and a combined standard uncertainty is
    a different quantity by a factor of `k`. The fourth form above uses
    `±` only because the surrounding text says the number is `u_c`.

    Do not copy a `±` display into a calibration certificate. That is
    what this page exists to prevent.

## How many digits — §7.2.6

`u_c` is quoted to **two significant digits**, and the estimate is
rounded to that same last significant place. Quoting an estimate to
more digits than its uncertainty supports claims a precision the
measurement does not have; quoting fewer discards information that was
paid for.

The rule is on significant digits of the uncertainty, not on decimal
places, so a coarse uncertainty coarsens the estimate with it:

```@example reporting
report(1234.5678, 12.0; symbol = "y", unit = "m").forms[4]
```

Feeding in more digits than the uncertainty can carry changes nothing:

```@example reporting
report(100.021473829, 0.000351119; symbol = "m_S", unit = "g").forms[2]
```

Pass `digits = 1` or `digits = 3` where a laboratory's own convention
differs; §7.2.6 says "at most two" and leaves room.

## Expanded uncertainty — §7.2.4

An expanded uncertainty is a **different statement**, not an
annotation of the standard one, and §7.2.4 asks it to name its
coverage factor and the basis for it. Supplying `k` produces it:

```@example reporting
report(
    100.02147, 0.00035;
    symbol = "m_S",
    unit = "g",
    k = 2.26,
    coverage_probability = 0.95,
    dof = 9,
)
```

Without `k` there is no expanded statement to make, and the `expanded`
field is `nothing`. `± U` with no stated `k` is precisely the
ambiguity §7.2.2 warns about, so the package will not write one.

## From a model, with units

With `DynamicQuantities` loaded, `report(m, values)` takes the
measurement and unit-carrying values, and derives the numbers *and*
the unit from the model — the same walk [`evaluate`](@ref) uses:

```@example reporting
using Symbolics, DynamicQuantities

@variables V I σV σI
R = (V ± σV) / (I ± σI)

readings = Dict(
    V => 10.000us"V", σV => 1e-3us"V",
    I => 0.10002us"A", σI => 1e-5us"A",
)

report(R, readings; symbol = "R", unit = "Ω", k = 2, coverage_probability = 0.95)
```

The dimensional walk composes what it is given, so this model produces
`A⁻¹ V`. `report` recognises the thirteen coherent derived SI units by
their dimension and writes `Ω` instead — likewise `W` for `A V`, and
`Hz` for `s⁻¹`. The `unit = "Ω"` above is therefore redundant here, and
kept only to show the override.

Two limits on that naming, both deliberate.

**A prefixed unit is never renamed.** `1 kΩ` expands to a thousand base
units, so a result computed in kilohms stays in kilohms: calling it `Ω`
would be wrong by a factor of a thousand. Only a unit that is already
the coherent SI one is given its name.

**A dimension does not determine a kind of quantity** (VIM §1.1).
Torque and energy are both `m² kg s⁻²`, so the table calls that `J` and
a torque must say otherwise:

```@example reporting
@variables F σF d σd
M = (F ± σF) * (d ± σd)

vals = Dict(
    F => 12.0us"N", σF => 0.1us"N",
    d => 0.25us"m", σd => 0.001us"m",
)

(
    default = report(M, vals; symbol = "M").forms[2],
    corrected = report(M, vals; symbol = "M", unit = "N m").forms[2],
)
```

`Hz` carries the same caveat, sharing `s⁻¹` with an activity in
becquerel. [`check_units`](@ref) refuses to unify such homonyms through
[`Kind`](@ref); `report` cannot make that distinction on its own,
because a product of two plain quantities carries no kind to
propagate — which is exactly why `unit` exists.

## API reference

```@docs
report
UncertaintyReport
```
