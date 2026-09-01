```@meta
CurrentModule = SymbolicUncertainties
```

# Worked Examples

Six canonical electrical worked examples per EARS
REQ-162. Each section follows the same skeleton:

1. **Setup** — variables, parameters, physical model.
2. **Propagation** — symbolic sensitivity analysis.
3. **Uncertainty budget** — tabular breakdown per
   JCGM 100:2008 §5.1.6 / EA-4/02.
4. **Numeric result** — [`evaluate`](@ref) with values that
   carry their units.

Every quantity carries its unit — in the model annotations, in the
values substituted into it, and in the answer, whose unit `evaluate`
derives from the model rather than taking on trust from a comment.
Units are written `us"V"` rather than `u"V"` so that results print as
`A⁻¹ V` rather than `m² kg s⁻³ A⁻²`; both notations are accepted
everywhere. Every example checks its own dimensions with
[`check_units`](@ref): a measurement model that is
dimensionally wrong is wrong before any uncertainty is propagated, and
the check also verifies that `u_c` carries the dimension of the
measurand — the error a budget hides most easily, since `y` and `u`
live in different fields.

Examples 1 – 5 are **executed when this page is built**, so the
numbers below are generated rather than transcribed. Example 6 is not:
it needs `ModelingToolkit.jl` and a solver, which the documentation
environment does not carry. Every example has a test item — under
`test/examples/`, or `test/ext_modelingtoolkit/` for the ODE one —
asserting its exact numeric output.

---

## 1. Ohm's law (GUM §5.1 canonical)

**Setup.** Voltage `V ± σV` in volts and current `I ± σI` in amperes,
independent. Measurand: resistance `R = V/I` in ohms.

```@example worked
using Symbolics, SymbolicUncertainties, DynamicQuantities

@variables V I σV σI

r = (V ± σV) / (I ± σI)
r.err
```

**Dimensions.** Units annotate the symbols of the model rather than
living inside the expression, so the check is a separate call — and
it verifies that `u_c` carries the dimension of the measurand, which
is the error a budget hides most easily:

```@example worked
check_units(r, Dict(V => us"V", σV => us"V", I => us"A", σI => us"A"))
```

**Uncertainty budget.**

```@example worked
uncertainty_budget(r)
```

**Numeric result.** `V = 5.000 V ± 0.010 V`,
`I = 0.500 A ± 0.001 A`:

```@example worked
ohm = Dict(V => 5.0us"V", σV => 0.01us"V", I => 0.5us"A", σI => 0.001us"A")
evaluate(r, ohm)
```

Verified in `test/examples/test_ohms_law.jl`.

---

## 2. Voltage divider (sensitivity analysis)

**Setup.** Input voltage `Vin ± σVin` in volts, resistors `R1 ± σR1`
and `R2 ± σR2` in ohms. Measurand: `Vout = Vin·R2/(R1 + R2)`, in
volts — the resistances enter as a ratio and cancel dimensionally.

```@example worked
@variables Vin σVin R1 σR1 R2 σR2

Vout = propagate(
    (v, r1, r2) -> v * r2 / (r1 + r2),
    [Vin ± σVin, R1 ± σR1, R2 ± σR2],
)
check_units(
    Vout,
    Dict(
        Vin => us"V", σVin => us"V",
        R1 => us"Ω", σR1 => us"Ω",
        R2 => us"Ω", σR2 => us"Ω",
    ),
)
```

**Uncertainty budget.**

```@example worked
uncertainty_budget(Vout)
```

**Numeric result.** `Vin = 5.000 V ± 0.010 V`, `R1 = 1.000 kΩ ± 1 Ω`,
`R2 = 3.000 kΩ ± 1 Ω`:

```@example worked
divider = Dict(
    Vin => 5.0us"V", σVin => 0.01us"V",
    R1 => 1_000.0us"Ω", σR1 => 1.0us"Ω",
    R2 => 3_000.0us"Ω", σR2 => 1.0us"Ω",
)
evaluate(Vout, divider)
```

Verified across `test/examples/test_voltage_divider.jl`,
`test_budget_voltage_divider.jl`, and
`test_substitute_voltage_divider.jl`.

---

## 3. RC time constant (`τ = R·C`)

**Setup.** Resistance `R ± σR` in ohms, capacitance `C ± σC` in
farads. Measurand: `τ = R·C` in seconds — Ω·F is a second, which the
dimensional check confirms rather than takes on trust.

```@example worked
@variables R C σR σC

τ = (R ± σR) * (C ± σC)
check_units(τ, Dict(R => us"Ω", σR => us"Ω", C => us"F", σC => us"F"))
```

**Numeric result.** `R = 1.000 kΩ ± 10 Ω`, `C = 1.000 µF ± 10 nF`:

```@example worked
rc = Dict(R => 1_000.0us"Ω", σR => 10.0us"Ω", C => 1e-6us"F", σC => 1e-8us"F")
evaluate(τ, rc)
```

The two contributions are equal here — 10 ms of relative error on each
input — so `u(τ)` is `√2` times either one.

---

## 4. Dissipated power — two measurement models, two budgets

**Setup.** Measurand: dissipated power in watts, from either
`P = V·I` or `P = V²/R`.

```@example worked
P = (V ± σV) * (I ± σI)
check_units(P, Dict(V => us"V", σV => us"V", I => us"A", σI => us"A"))
```

```@example worked
@variables R2ₚ σR2ₚ
P_alt = propagate((v, r) -> v^2 / r, [V ± σV, R2ₚ ± σR2ₚ])
check_units(
    P_alt,
    Dict(V => us"V", σV => us"V", R2ₚ => us"Ω", σR2ₚ => us"Ω"),
)
```

Both are watts, and both are correct — yet they give **different**
uncertainties, because they descend from different measurements. The
budget depends on which quantities were measured, not on the physical
quantity itself. That is JCGM GUM-6:2020's subject, and it is upstream
of everything this package does.

```@example worked
power = Dict(V => 5.0us"V", σV => 0.01us"V", I => 0.5us"A", σI => 0.001us"A")
evaluate(P, power)
```

---

## 5. RLC resonance (`f₀ = 1/(2π√(LC))`)

**Setup.** Inductance `L ± σL` in henries, capacitance `C ± σC` in
farads. Measurand: resonant frequency in hertz.

```@example worked
@variables L σL

f₀ = propagate((l, c) -> 1 / (2π * sqrt(l * c)), [L ± σL, C ± σC])
check_units(f₀, Dict(L => us"H", σL => us"H", C => us"F", σC => us"F"))
```

**Propagation.** The sensitivity coefficients are `∂f₀/∂L = −f₀/(2L)`
and `∂f₀/∂C = −f₀/(2C)`, so the relative uncertainty is **half** the
quadrature sum of the relative input uncertainties — a square root
halves relative errors, which is why resonant methods are forgiving.

**Numeric result.** `L = 10.00 mH ± 50 µH`, `C = 1.000 µF ± 5 nF`:

```@example worked
rlc = Dict(L => 10e-3us"H", σL => 50e-6us"H", C => 1e-6us"F", σC => 5e-9us"F")
evaluate(f₀, rlc)
```

Verified in `test/examples/test_rlc_resonance.jl`.

---

## 6. RC-charge ODE (`du/dt = (Vin − u) / (R·C)`)

**Setup.** A first-order dynamic measurement — the
standard RC charge transient. Parameters `R ± σR`,
`C ± σC`, `Vin ± σVin` are treated as constants with
uncertainty. This example requires the
[`ModelingToolkit.jl`](https://github.com/SciML/ModelingToolkit.jl)
package extension.

```julia
using ModelingToolkit
using ModelingToolkit: t_nounits as t, D_nounits as D, System
using SymbolicUncertainties
using SymbolicUncertainties: ±

@variables u(t)
@parameters R C Vin
eqs = [D(u) ~ (Vin - u) / (R * C)]
@named rc_sys = System(eqs, t)

R_m   = R   ± 0.01R
C_m   = C   ± 0.01C
Vin_m = Vin ± 0.001Vin
```

**Symbolic snapshot** via `propagate_ode`:

```julia
result = propagate_ode(rc_sys, [R_m, C_m, Vin_m])
# result[1].val = u(t)
# result[1].err = sqrt((∂u/∂R)²·σR² + (∂u/∂C)²·σC² +
#                      (∂u/∂Vin)²·σVin²)
```

**Augmented integration** via `uncertainty_ode`:

```julia
using OrdinaryDiffEq

augmented = uncertainty_ode(rc_sys, [R_m, C_m, Vin_m])
compiled  = mtkcompile(augmented)

u0 = Dict(u => 0.0,
          (s => 0.0 for s in setdiff(unknowns(augmented),
                                     unknowns(rc_sys)))...)
p  = Dict(R => 1.0, C => 1e-3, Vin => 5.0)
prob = ODEProblem(compiled, merge(u0, p), (0.0, 50e-3))
sol  = solve(prob, Tsit5(); abstol = 1e-10, reltol = 1e-10)

# sol[u, end] ≈ 5.0  (converged to Vin)
# sol[∂u_∂Vin(t), end] ≈ 1.0
```

Verified in
`test/ext_modelingtoolkit/test_rc_charge_endpoint.jl`. For a
full walkthrough of `propagate_ode` and `uncertainty_ode`,
see [ODE Integration](ode-integration.md).

---

## Keeping these examples honest

Examples 1 – 5 are executed at build time, so they cannot drift: if a
`Symbolics.jl` release changes a user-visible output, the page changes
with it and a wrong claim in the surrounding prose shows up as a
mismatch with the printed result.

Example 6 is the exception, and its code block is transcribed. It is
covered by `test/ext_modelingtoolkit/`, which is authoritative; if
that test needs updating for output drift, mirror the change here.
