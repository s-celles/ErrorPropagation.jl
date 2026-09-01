# Per-variable sensitivity helpers — JCGM 100:2008 §5.1.3 / EA-4/02
# §7.3 building blocks for the M3 uncertainty-budget layer.
#
# All three helpers operate on `m.val` via `Symbolics.derivative`
# and reuse the `_safe_derivative` / `_has_unresolved_differential`
# machinery from `src/differentiation.jl` to raise the REQ-021
# `ArgumentError` when the symbolic engine cannot find a closed form.

"""
    sensitivity_coefficient(m::SymbolicMeasurement, xᵢ::Num) -> Num

Return the symbolic sensitivity coefficient
`cᵢ = ∂(m.val)/∂xᵢ` per JCGM 100:2008 §5.1.3 equation (11b).

If `xᵢ` does not appear in `m.val`, returns `Num(0)`. If the
symbolic engine cannot compute a closed-form derivative, raises
`ArgumentError` directing the user at
`apply(f, m; derivative = ...)` (consistent with the M2
`propagate` failure pathway — REQ-021).

Implements the methodology of JCGM 100:2008 §5.1.3 equation (11b).
Traces REQ-040.
"""
function sensitivity_coefficient(m::SymbolicMeasurement, xᵢ::Symbolics.Num)
    c = _safe_derivative(m.val, xᵢ)
    if c === nothing
        throw(
            ArgumentError(
                "cannot compute closed-form derivative of `m.val` with " *
                "respect to the supplied variable. Use " *
                "`apply(f, m; derivative = ...)` to supply one " *
                "explicitly, or rebuild `m` via `propagate`.",
            ),
        )
    end
    return c
end

"""
    uncertainty_contribution(m::SymbolicMeasurement, xᵢ::Num, σᵢ::Num) -> Num

Return the symbolic uncertainty contribution
`uᵢ(y) = |cᵢ| · σᵢ` of variable `xᵢ` to measurement `m`,
per JCGM 100:2008 §5.1.3 equation (11a).

Presented as a row of an EA-4/02 §7.3 uncertainty-budget table.
Traces REQ-041.
"""
function uncertainty_contribution(
    m::SymbolicMeasurement,
    xᵢ::Symbolics.Num,
    σᵢ::Symbolics.Num,
)
    c = sensitivity_coefficient(m, xᵢ)
    return abs(c) * σᵢ
end

"""
    relative_sensitivity(m::SymbolicMeasurement, xᵢ::Num, σᵢ::Num) -> Num

Return the fractional variance contribution
`(cᵢ · σᵢ)² / u_c²(y)` — the EA-4/02 §7.3 "percentage-of-variance"
column (JCGM 100:2008 §5.1.6).

For uncorrelated inputs, summing `relative_sensitivity` over the
full input set simplifies to `1` under `Symbolics.simplify` —
the variance-decomposition invariant (REQ-045 / REQ-152).

Traces REQ-042.
"""
function relative_sensitivity(
    m::SymbolicMeasurement,
    xᵢ::Symbolics.Num,
    σᵢ::Symbolics.Num,
)
    if !isempty(cov_of(m))
        throw(
            ArgumentError(
                "relative_sensitivity(m, xᵢ, σᵢ) is not defined when " *
                "sources are correlated: under JCGM 100:2008 §5.2.2 " *
                "equation (13) the cross terms are missing from the " *
                "numerator, the fractions no longer sum to 1, and a " *
                "negative cross term can push one past 100 %. Use " *
                "`relative_sensitivity(m, source)`, which is well defined " *
                "in both regimes.",
            ),
        )
    end
    c = sensitivity_coefficient(m, xᵢ)
    return (c * σᵢ)^2 / m.err^2
end

"""
    relative_sensitivity(m::SymbolicMeasurement, s::SourceId)

Fraction of the combined variance contributed by the independent
source `s` (JCGM 100:2008 §5.1.2).

This is the source-based form, and the one that stays meaningful under
correlation: contributions are keyed by the independent measurements
the quantity actually derives from, so with independent sources they
sum to exactly 1.

The variable-based method `relative_sensitivity(m, xᵢ, σᵢ)` remains for
models expressed in user symbols, but refuses to answer once
correlations are declared, because `(cᵢσᵢ)²/u_c²` is then no longer a
decomposition.

Traces REQ-042, REQ-152, REQ-206.
"""
function relative_sensitivity(m::SymbolicMeasurement, s::SourceId)
    terms = terms_of(m)
    haskey(terms, s) || return Symbolics.Num(0)
    u = sources_of(m)[s].u
    return (terms[s] * u)^2 / m.err^2
end
