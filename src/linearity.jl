# Linearity diagnostics — JCGM 100:2008 §5.1.1 note.
#
# `check_linearity(f, measurements; values=nothing)` returns
# per-variable symbolic nonlinearity indicators
# `ηᵢ = (∂²f/∂xᵢ²) · σᵢ² / (2 · ∂f/∂xᵢ · σᵢ)` — the ratio of
# the neglected second-order Taylor term to the retained
# first-order term. With a `values` substitution dict, any
# numerically-evaluated `|ηᵢ| > 0.1` triggers a runtime
# `@warn` recommending Monte Carlo (JCGM 101:2008,
# `MonteCarloMeasurements.jl`).
#
# Pure observer: `check_linearity` does **not** modify any
# M1..M5 propagation output (REQ-182).

# REQ-181 threshold: |η| > 0.1 triggers the warning. Fixed per
# the EARS spec. Future milestones may expose as a keyword.
const _LINEARITY_THRESHOLD = 0.1

"""
    check_linearity(f, measurements; values = nothing) -> Dict{Num, Num}

Return per-variable nonlinearity indicators
`ηᵢ = (∂²f/∂xᵢ²) · σᵢ² / (2 · ∂f/∂xᵢ · σᵢ)` for the
user-supplied function `f` and input measurements, following
JCGM 100:2008 §5.1.1 note.

`|ηᵢ|` is a dimensionless measure of how much the
second-order Taylor term contributes relative to the
first-order term. `|ηᵢ| ≈ 0` means the GUM linearisation is
exact for that input; `|ηᵢ| > 0.1` signals the
first-order-only propagation may be inadequate and Monte
Carlo methods (JCGM 101:2008,
[`MonteCarloMeasurements.jl`](https://github.com/baggepinnen/MonteCarloMeasurements.jl))
should be considered.

# Arguments

- `f` — a user-supplied function of `length(measurements)`
  arguments returning a single `Symbolics.Num`-compatible
  expression.
- `measurements::AbstractVector{<:SymbolicMeasurement}` —
  the input measurements. Each `m.val` is passed to `f` as
  the corresponding xᵢ; each `m.err` is the σᵢ in the
  indicator formula **and** the dict key in the returned
  table.
- `values::Union{Dict, Nothing}` (keyword, default
  `nothing`) — optional substitution dictionary. When
  supplied, each `ηᵢ` is evaluated numerically and a
  `@warn` fires per variable whose `|ηᵢ| > 0.1` (REQ-181).

# Return

`Dict{Num, Num}` keyed by the σ-variables of the supplied
measurements, mapping each σᵢ to its symbolic indicator.

# Errors

- `ArgumentError` when `Symbolics.derivative` returns an
  unresolved `Differential` wrapper on either the first or
  second partial — points the user at the `apply(f, m;
  derivative = ...)` M2 escape hatch, and notes that M6
  does **not** expose a second-derivative override keyword.

# Edge cases

- Empty `measurements` returns an empty `Dict{Num, Num}`
  without calling `f`.
- Stationary points (`∂f/∂xᵢ = 0`) produce `0/0` or `∞`
  indicators; numeric `NaN` / `Inf` evaluations are silently
  skipped by the threshold check (no warning fires).

# Scope

M6 tracks the **diagonal** second derivative `∂²f/∂xᵢ²`
only — not the mixed partials `∂²f/∂xᵢ∂xⱼ`. For
strongly-coupled measurands Monte Carlo remains the
recommended method.

Implements the GUM §5.1.1 linearity-assumption diagnostic.
Traces REQ-180, REQ-181, REQ-182, REQ-155.
"""
function check_linearity(
    f,
    measurements::AbstractVector{<:SymbolicMeasurement};
    values::Union{AbstractDict,Nothing} = nothing,
)
    if isempty(measurements)
        return Dict{Symbolics.Num,Symbolics.Num}()
    end

    xs = [m.val for m in measurements]
    val_expr = Symbolics.Num(f(xs...))

    result = Dict{Symbolics.Num,Symbolics.Num}()
    for (m, xᵢ) in zip(measurements, xs)
        c_i = _safe_derivative(val_expr, xᵢ)
        if c_i === nothing
            throw(
                ArgumentError(
                    "check_linearity: cannot compute closed-form " *
                    "first derivative of `f` with respect to one of " *
                    "the inputs. Use `apply(f, m; derivative = ...)` " *
                    "to pre-supply the first derivative for the M2 " *
                    "propagate path. M6 does not expose a " *
                    "`derivative_2` override; this limitation is " *
                    "tracked against upstream Symbolics. (REQ-021 / " *
                    "REQ-180)",
                ),
            )
        end
        c_ii = _safe_derivative(c_i, xᵢ)
        if c_ii === nothing
            throw(
                ArgumentError(
                    "check_linearity: cannot compute closed-form " *
                    "second derivative of `f` with respect to one of " *
                    "the inputs. M6 does not expose a " *
                    "`derivative_2` override — the calculation is " *
                    "purely symbolic per constitution Principle III. " *
                    "(REQ-180)",
                ),
            )
        end

        # ηᵢ = (∂²f/∂xᵢ²) · σᵢ² / (2 · ∂f/∂xᵢ · σᵢ)
        # Kept in this form to match REQ-180 verbatim.
        ηᵢ = c_ii * m.err^2 / (2 * c_i * m.err)
        result[m.err] = ηᵢ

        # REQ-181 threshold warning — only fires when `values`
        # substitutes the indicator to a concrete Float64.
        if values !== nothing
            _linearity_threshold_check(m.err, ηᵢ, values)
        end
    end

    return result
end

# Attempt to numerically evaluate ηᵢ under the given
# `values` substitution. If the evaluation succeeds and
# `|η| > 0.1`, emit the REQ-181 @warn. Non-finite and
# non-Real results are silently skipped (stationary-point
# and partial-substitution cases per research R5).
function _linearity_threshold_check(σᵢ, ηᵢ, values)
    local value
    try
        subbed = Symbolics.substitute(ηᵢ, values)
        value = Float64(eval(Symbolics.toexpr(subbed)))
    catch
        return
    end
    if !(value isa Real) || !isfinite(value)
        return
    end
    if abs(value) > _LINEARITY_THRESHOLD
        @warn (
            "check_linearity: |η| = $(value) exceeds the GUM §5.1.1 " *
            "linearity threshold of $(_LINEARITY_THRESHOLD) for " *
            "variable `$σᵢ`. The first-order propagation formula " *
            "may be inadequate — consider Monte Carlo methods " *
            "(MonteCarloMeasurements.jl / JCGM 101:2008). (REQ-181)"
        )
    end
    return
end
