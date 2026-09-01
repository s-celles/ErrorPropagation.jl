```@meta
CurrentModule = SymbolicUncertainties
```

# ODE Integration

The `SymbolicUncertaintiesModelingToolkitExt` package extension
adds two functions, [`propagate_ode`](@ref) and
[`uncertainty_ode`](@ref), that propagate parameter
uncertainties through **dynamical** measurement models
built on [ModelingToolkit.jl](https://github.com/SciML/ModelingToolkit.jl).
The extension activates automatically when
`ModelingToolkit` is loaded.

This is the anticipated **GUM Supplement 3** use case —
calibration models whose measurand is a function of time,
such as an RC charge transient, a thermal cool-down, or a
chemical dissolution profile.

## Motivation

GUM §5.1 treats parameters as constants with uncertainty.
A dynamical measurement extends that by asking: *given
`p ± σ_p`, what is the propagated uncertainty on the
state trajectory `u(t)`?*

The forward-sensitivity approach augments the original
ODE with equations for `∂u/∂p`:

```math
\frac{d}{dt}\left(\frac{\partial u}{\partial p_j}\right)
= \frac{\partial f}{\partial u} \cdot \frac{\partial u}{\partial p_j}
+ \frac{\partial f}{\partial p_j}
```

The combined GUM standard uncertainty on `u(t)` is then

```math
\sigma_u(t) = \sqrt{\sum_j
    \left(\frac{\partial u}{\partial p_j}\right)^2 \sigma_j^2}
```

which `SymbolicUncertainties.jl` constructs symbolically — you
never touch the sensitivity derivation by hand.

## RC-charge worked example

The canonical first-order linear ODE:
`du/dt = (Vin − u) / (R · C)` with `u(0) = 0` and three
uncertain parameters `R`, `C`, `Vin`.

### Build the `ODESystem`

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

### `propagate_ode` — symbolic snapshot

```julia
result = propagate_ode(rc_sys, [R_m, C_m, Vin_m])
# result isa Vector{SymbolicMeasurement} of length 1
# (one state: u(t)).

result[1].val
# u(t) — the state variable
result[1].err
# sqrt((0.0001·R²)·(∂u_∂R(t))² + (0.0001·C²)·(∂u_∂C(t))²
#      + (1.0e-6·Vin²)·(∂u_∂Vin(t))²)
```

The `err` expression is the symbolic
`sqrt(Σⱼ (∂uᵢ/∂pⱼ)² · σⱼ²)` formula with the sensitivity
symbols `∂u_∂R(t)`, `∂u_∂C(t)`, `∂u_∂Vin(t)` left as free
variables. They are populated numerically by the
augmented-ODE solve below.

### `uncertainty_ode` — augmented `System` for `solve`

```julia
augmented = uncertainty_ode(rc_sys, [R_m, C_m, Vin_m])
# augmented isa System with 1 + 3·1 = 4 states:
#   u(t), ∂u_∂R(t), ∂u_∂C(t), ∂u_∂Vin(t)
```

Pass directly to `OrdinaryDiffEq`:

```julia
using OrdinaryDiffEq

compiled = mtkcompile(augmented)
sens_states = setdiff(unknowns(augmented), unknowns(rc_sys))
u0 = Dict(u => 0.0, (s => 0.0 for s in sens_states)...)
p  = Dict(R => 1.0, C => 1e-3, Vin => 5.0)

prob = ODEProblem(compiled, merge(u0, p), (0.0, 50e-3))
sol  = solve(prob, Tsit5(); abstol = 1e-10, reltol = 1e-10)

sol[u, end]         # numerical u(t_end) ≈ Vin
# access sensitivities by symbol name too
```

At `t → ∞` the state converges to `Vin`, so `∂u/∂Vin → 1`
and `∂u/∂R, ∂u/∂C → 0` — the sensitivities carry the
transient.

## When to reach for which function

| Goal                                                         | Use                     |
|--------------------------------------------------------------|-------------------------|
| A symbolic expression for `u(t)` and its uncertainty band    | `propagate_ode`         |
| Numerical state + sensitivity trajectories                   | `uncertainty_ode` → `solve` |
| Calibration-certificate single-point number                  | `uncertainty_ode` → `solve` → evaluate GUM formula |

Both share the same `_build_sensitivity_eqs` internal
machinery, so the symbolic content agrees — only the
output shape differs.

## Scope and limitations

- **ODE-only, not DAE.** The extension targets
  `ODESystem`s without algebraic constraints. DAE systems
  are rejected with a clear `ArgumentError`.
- **Constant uncertain parameters.** Time-varying or
  stochastic forcing is outside scope — that is the JCGM
  101:2008 Monte Carlo regime; reach for
  `MonteCarloMeasurements.jl` + `StochasticDiffEq.jl`.
- **ModelingToolkit version.** The extension targets MTK
  11.x. Breaking MTK releases may require a follow-up
  patch.
- **Missing parameter.** If a
  `SymbolicMeasurement.val` in `uncertain_params` is not a
  parameter of `sys`, both functions raise
  `ArgumentError` naming the offending symbol.

## API reference

```@docs
propagate_ode
uncertainty_ode
```
