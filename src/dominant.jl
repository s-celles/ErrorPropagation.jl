# Identify the dominant variance contributor — EA-4/02 §7.3
# calibration-report convenience.
#
# Ranking rules (see `specs/005-budget-and-expanded/research.md` R6):
# - With a `values` substitution dictionary: numeric `argmax` on
#   `|cᵢ·σᵢ|` via `Symbolics.substitute` + `eval(toexpr(...))`.
# - Without: first-variable-wins + `@info` explaining the
#   order-dependence.
# - All sensitivities zero: return a zero record + `@warn`.

"""
    dominant_source(m::SymbolicMeasurement; values = nothing) -> SourceId

Identify the independent source contributing the largest share of the
combined variance, derived from the quantity's own structure
(JCGM 100:2008 §5.1.2, EA-4/02 §7.3).

Pass `values` to substitute numerics before comparing; without it the
comparison is only possible when the contributions are already
concrete.

Traces REQ-043, REQ-206.
"""
function dominant_source(
    m::SymbolicMeasurement;
    values::Union{Dict,Nothing} = nothing,
)
    terms = terms_of(m)
    srcs = sources_of(m)
    isempty(terms) && throw(
        ArgumentError(
            "dominant_source: the measurement carries no uncertainty " *
            "source, so no source can dominate.",
        ),
    )
    ids = sort!(collect(keys(terms)); by = s -> s.id)

    best_id = ids[1]
    best = nothing
    for sid in ids
        contribution = abs(terms[sid]) * srcs[sid].u
        expr =
            values === nothing ? contribution :
            Symbolics.substitute(contribution, values)
        v = Symbolics.value(Symbolics.simplify(expr))
        v isa Number || throw(
            ArgumentError(
                "dominant_source: contributions are not concrete numbers; " *
                "pass `values = Dict(...)` to substitute before comparing.",
            ),
        )
        if best === nothing || abs(float(v)) > best
            best = abs(float(v))
            best_id = sid
        end
    end
    return best_id
end

"""
    dominant_source(m, variables, sigmas; values=nothing) -> NamedTuple

Identify the variable whose variance contribution dominates.

The returned `NamedTuple` has fields
`(index, variable, contribution, ranked_by)`:

- `index::Int` — 1-based position of the dominant variable in
  `variables`, or `0` when every sensitivity coefficient is
  structurally zero.
- `variable::Num` — the dominant variable itself.
- `contribution::Num` — its uncertainty contribution `|cᵢ|·σᵢ`.
- `ranked_by::Symbol` — `:numeric` when a `values` substitution
  dictionary was supplied, `:symbolic` otherwise.

Ranking strategy:

- With `values = Dict(...)`: each per-variable contribution is
  substituted and evaluated to a `Float64`; the maximum by
  absolute value is the dominant source.
- Without `values`: the ranking is order-dependent (no
  canonical ordering exists on arbitrary `Num` expressions). The
  first variable is returned and an `@info` message flags the
  order-dependence.

All-zero edge case: when every sensitivity coefficient is
structurally `0`, the record is
`(index=0, variable=Num(0), contribution=Num(0), ranked_by=:symbolic)`
and a `@warn` is emitted.

Errors:

- `length(variables) != length(sigmas)` raises
  `DimensionMismatch`.

Traces REQ-043. The ranking convention follows EA-4/02 §7.3
calibration-report practice; no single GUM section mandates it.
"""
function dominant_source(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num},
    sigmas::AbstractVector{<:Symbolics.Num};
    values::Union{Dict,Nothing} = nothing,
)
    if length(variables) != length(sigmas)
        throw(
            DimensionMismatch(
                "dominant_source: length(variables)=$(length(variables)), " *
                "length(sigmas)=$(length(sigmas))",
            ),
        )
    end

    isempty(variables) && begin
        @warn "dominant_source: no variables supplied — no dominant source."
        return (
            index = 0,
            variable = Symbolics.Num(0),
            contribution = Symbolics.Num(0),
            ranked_by = :symbolic,
        )
    end

    contributions = [
        uncertainty_contribution(m, xᵢ, σᵢ) for
        (xᵢ, σᵢ) in zip(variables, sigmas)
    ]

    # All-zero detection: every sensitivity coefficient symbolically
    # equal to zero means the measurand does not depend on any of the
    # `variables`. We test via Symbolics.isequal on the simplified
    # contribution.
    if all(
        Symbolics.isequal(
            Symbolics.simplify(sensitivity_coefficient(m, xᵢ)),
            0,
        ) for xᵢ in variables
    )
        @warn "dominant_source: all sensitivity coefficients are zero — no dominant source."
        return (
            index = 0,
            variable = Symbolics.Num(0),
            contribution = Symbolics.Num(0),
            ranked_by = :symbolic,
        )
    end

    if values === nothing
        @info (
            "dominant_source: without a `values` substitution dictionary, " *
            "the result is order-dependent — returning the first variable."
        )
        return (
            index = 1,
            variable = variables[1],
            contribution = contributions[1],
            ranked_by = :symbolic,
        )
    end

    # Numeric ranking via `Symbolics.substitute` + `eval(toexpr)`.
    numeric = map(contributions) do c
        sub = Symbolics.substitute(c, values)
        Float64(eval(Symbolics.toexpr(sub)))
    end
    i = argmax(abs.(numeric))
    return (
        index = i,
        variable = variables[i],
        contribution = contributions[i],
        ranked_by = :numeric,
    )
end
