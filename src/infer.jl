# Inverse inference — JCGM 100:2008 §5.2 inverse application.
#
# `infer_precision(m, σᵢ, target_uc)` solves m.err = target_uc
# symbolically for σᵢ. Exploits the GUM-standard quadratic form
# `m.err² = Σⱼ (cⱼ·σⱼ)²`: splits out the σᵢ contribution
# algebraically without invoking a general-purpose polynomial
# solver, avoiding the Nemo.jl dependency that
# `Symbolics.symbolic_solve` requires for non-linear cases.
#
# `infer_all_precisions(m, variables, sigmas, target_uc)` uses
# the closed-form shortcut σᵢ* = target_uc / |cᵢ| (research R4).
#
# `required_precision(m, σᵢ, target_uc)` is a one-line delegate
# to `infer_precision` per research R6.

"""
    infer_precision(m::SymbolicMeasurement, σᵢ, target_uc) -> Num

Solve `m.err == target_uc` symbolically for `σᵢ` and return
the positive root.

Assumes the GUM-standard quadratic form
`m.err² = cᵢ²·σᵢ² + (contribution-of-other-σⱼ)²` — true for
any measurement built via `propagate` / `propagate_correlated`
/ the M1 binary operators. Under this assumption the closed-
form σᵢ* is:

```
σᵢ* = sqrt((target_uc² − Σⱼ≠ᵢ(cⱼ·σⱼ)²) / cᵢ²)
```

Implementation (no general-purpose polynomial solver
required — sidesteps the `Symbolics.symbolic_solve` ⇒ Nemo.jl
dependency chain):

1. Squares `m.err` and simplifies (the sqrt wrapper cancels).
2. Substitutes σᵢ → 0 to obtain the sum of other-input
   contributions.
3. Subtracts to isolate the σᵢ contribution `cᵢ²·σᵢ²`.
4. Extracts `cᵢ² = contribution / σᵢ²` via symbolic division.
5. Computes `σᵢ* = sqrt((target² − others²) / cᵢ²)`.

Errors:

- `target_uc isa Real && target_uc < 0` → `ArgumentError`.
- `σᵢ` not in `m.err` → `ArgumentError`.
- `m.err` is not quadratic in σᵢ (the σᵢ-contribution does
  not factor as `cᵢ²·σᵢ²`) → `ArgumentError` per REQ-091.

Implements the methodology of JCGM 100:2008 §5.2 inverse.
Traces REQ-090, REQ-091.
"""
function infer_precision(m::SymbolicMeasurement, σᵢ::Symbolics.Num, target_uc)
    if target_uc isa Real && !(target_uc isa Symbolics.Num) && target_uc < 0
        throw(
            ArgumentError(
                "infer_precision: `target_uc` must be non-negative " *
                "(JCGM 100:2008 §4.3.1); got $target_uc.",
            ),
        )
    end

    vars_err = Symbolics.get_variables(m.err)
    σᵢ_raw = Symbolics.value(σᵢ)
    if !any(v -> isequal(v, σᵢ_raw), vars_err)
        throw(
            ArgumentError(
                "infer_precision: `σᵢ = $σᵢ` does not appear in " *
                "`m.err` — the measurand does not depend on this " *
                "input.",
            ),
        )
    end

    t = Symbolics.Num(target_uc)

    # err_squared = Σⱼ (cⱼ·σⱼ)². Simplify cancels the sqrt wrapper
    # produced by propagate / binary operators.
    err_squared = Symbolics.simplify(m.err^2; expand = true)

    # Isolate the σᵢ contribution by zeroing σᵢ in the squared form.
    others_squared = Symbolics.simplify(
        Symbolics.substitute(err_squared, Dict(σᵢ => 0));
        expand = true,
    )

    # σᵢ contribution = err² − others² = cᵢ²·σᵢ².
    contribution =
        Symbolics.simplify(err_squared - others_squared; expand = true)

    # Extract cᵢ² = contribution / σᵢ². For a GUM-standard quadratic
    # measurement, the σᵢ² factors exactly. If it does not, the
    # result will retain σᵢ as a free variable and we raise.
    ci_squared = Symbolics.simplify(contribution / σᵢ^2; expand = true)

    if any(v -> isequal(v, σᵢ_raw), Symbolics.get_variables(ci_squared))
        throw(
            ArgumentError(
                "infer_precision: `m.err²` is not a pure quadratic " *
                "in `σᵢ = $σᵢ` (the σᵢ contribution does not factor " *
                "as cᵢ²·σᵢ²). Consider loading `Nemo.jl` for the " *
                "full polynomial solver, or perform numerical " *
                "root-finding. (REQ-091)",
            ),
        )
    end

    return sqrt((t^2 - others_squared) / ci_squared)
end

"""
    required_precision(m::SymbolicMeasurement, σᵢ, target_uc) -> Num

!!! note "Delegate"
    Direct delegate to [`infer_precision`](@ref). Both return
    the closed-form `σᵢ*` that saturates `m.err = target_uc`.
    The EARS REQ-060 name preserves the "precision condition"
    (inequality) framing; the REQ-090 name preserves the
    "solved equation" framing. The numerical content is the
    same; see
    `specs/007-protocol-and-inference/research.md` R6 for the
    rationale.

Users who want the inequality interpretation read the
returned expression as the boundary value: `σᵢ` values
strictly below satisfy `m.err < target_uc`; values equal
saturate it; values above violate it. Inverse form of the
JCGM 100:2008 §5.2 uncertainty-propagation relation.

Traces REQ-060, REQ-062.
"""
required_precision(m::SymbolicMeasurement, σᵢ::Symbolics.Num, target_uc) =
    infer_precision(m, σᵢ, target_uc)

"""
    infer_all_precisions(m, variables, sigmas, target_uc) -> Dict{Num, Num}

Produce the worst-case single-source precision table. For
each pair `(xᵢ, σᵢ)`, compute the `σᵢ*` that would **alone**
drive `m.err = target_uc`.

Uses the closed-form shortcut (research R4):

```
σᵢ* = target_uc / abs(sensitivity_coefficient(m, xᵢ))
```

Requires `length(variables) == length(sigmas)`
(`DimensionMismatch` otherwise). Propagates any
`sensitivity_coefficient` failure unchanged. Inverse form
of JCGM 100:2008 §5.2 applied per-input.

Traces REQ-092.
"""
function infer_all_precisions(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num},
    sigmas::AbstractVector{<:Symbolics.Num},
    target_uc,
)
    if length(variables) != length(sigmas)
        throw(
            DimensionMismatch(
                "infer_all_precisions: length(variables)=" *
                "$(length(variables)), length(sigmas)=$(length(sigmas))",
            ),
        )
    end
    if target_uc isa Real && !(target_uc isa Symbolics.Num) && target_uc < 0
        throw(
            ArgumentError(
                "infer_all_precisions: `target_uc` must be " *
                "non-negative (JCGM 100:2008 §4.3.1); got $target_uc.",
            ),
        )
    end

    t = Symbolics.Num(target_uc)
    result = Dict{Symbolics.Num,Symbolics.Num}()
    for (xᵢ, σᵢ) in zip(variables, sigmas)
        c = sensitivity_coefficient(m, xᵢ)
        result[σᵢ] = t / abs(c)
    end
    return result
end
