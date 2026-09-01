```@meta
CurrentModule = SymbolicUncertainties
```

# Inverse Inference

The inverse-inference layer answers the **central instrument-
design question** of metrology: *what input precision do I
need so that my combined standard uncertainty hits a target?*

Four closed-form operations cover the common workflow:

- `infer_precision(m, σᵢ, target_uc)` — solves
  `m.err = target_uc` for `σᵢ`.
- `infer_all_precisions(m, variables, sigmas, target_uc)` —
  the worst-case single-source precision table.
- `required_precision(m, σᵢ, target_uc)` — inequality framing
  (delegates to `infer_precision`).

## `infer_precision` — headline solve

```@example inverse-inference
using Symbolics, SymbolicUncertainties, DynamicQuantities

@variables V I σV σI
V_m = V ± σV
I_m = I ± σI
R = V_m / I_m   # Ohm's-law resistance

σV_needed = infer_precision(R, σV, 0.01)
# Closed-form σV* such that R.err = 0.01.
```

Substitute concrete numerics to read off the target:

```@example inverse-inference
# I = 0.500 A with u(I) = 1 mA. The target σV* comes back in volts.
step1 = Symbolics.substitute(
    σV_needed,
    Dict(k => ustrip(v) for (k, v) in Dict(I => 0.5us"A", σI => 0.001us"A")),
)
```

### Why the library does not use `Symbolics.solve_for` or `Symbolics.symbolic_solve`

`Symbolics.solve_for` only handles linear equations; Ohm's
law is quadratic in `σV`. `Symbolics.symbolic_solve` is more
capable but requires `Nemo.jl` for polynomial solving beyond
the most trivial case, and even with Nemo it can fail on
rational-coefficient systems. `SymbolicUncertainties.jl` uses
the **closed-form algebraic split** that works for every
GUM-standard quadratic measurement:

```
m.err² = cᵢ²·σᵢ² + Σⱼ≠ᵢ (cⱼ·σⱼ)²

  ⇒ σᵢ* = sqrt((target_uc² − Σⱼ≠ᵢ(cⱼ·σⱼ)²) / cᵢ²)
```

extracted by subtracting the σᵢ → 0 substituted form from
`m.err²` and dividing by `σᵢ²`. No solver dependency; no
`Nemo.jl` requirement. See
`specs/007-protocol-and-inference/research.md` R1/R2 for the
design rationale.

Measurements whose err is **not** quadratic in σᵢ (e.g. a
transcendental `sin(σᵢ)` term) raise `ArgumentError` per
REQ-091, with a message recommending `using Nemo` (if you
want to try `Symbolics.symbolic_solve` directly) or numerical
root-finding via an external package.

## `infer_all_precisions` — worst-case table

```@example inverse-inference
table = infer_all_precisions(R, [V, I], [σV, σI], 0.01)
# table[σV] == 0.01 / |1/I|
# table[σI] == 0.01 / |V/I²|
```

Each entry is the precision that input would need **alone** to
drive `u_c(y) = target_uc`. Uses the closed-form shortcut
`σᵢ* = target_uc / |cᵢ|` (research R4) where `cᵢ` comes from
the `sensitivity_coefficient` helper.

## RLC resonance

```@example inverse-inference
@variables L C σL σC
f0 = propagate(
    (l, c) -> 1 / (2π * sqrt(l * c)),
    [L ± σL, C ± σC],
)

ε = 0.001
σL_star = infer_precision(f0, σL, ε * f0.val)
# Closed-form σL* such that f0.err == 0.001 · f0.val.
```

Asserted numerically by
`test/examples/test_rlc_resonance.jl` via two-pass
substitution through the `AsFloat` helper (no Nemo needed).

## Error paths (REQ-091)

`ArgumentError` fires in the following cases:

- `target_uc isa Real && target_uc < 0` — standard uncertainty
  must be non-negative (GUM §4.3.1).
- `σᵢ` not in `m.err` — the measurand does not depend on the
  supplied input.
- `m.err` not quadratic in σᵢ — the algebraic split fails.
  Message recommends `using Nemo` or numerical root-finding.

## API reference

```@docs
infer_precision
infer_all_precisions
```
