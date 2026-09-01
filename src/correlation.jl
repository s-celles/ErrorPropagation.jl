# Declared correlations between sources — M11 phase 3.
#
# Lives after `type.jl` in the include order because its signature
# annotates `SymbolicMeasurement`, which must already exist when the
# method is defined.

"""
    declare_correlated(m1, m2, ρ) -> (SymbolicMeasurement, SymbolicMeasurement)

Declare a correlation coefficient `ρ` between the sources of `m1` and
`m2`, returning **new** quantities carrying that hypothesis.

Nothing is mutated. A correlation hypothesis is a property of the
measurement model, so it travels with the quantities it concerns
rather than acting at a distance on shared state — two models in the
same session can hold different, equally valid assumptions.

The declared covariance `u(xᵢ,xⱼ) = ρ · u(xᵢ) · u(xⱼ)` enters the
combined uncertainty as the cross term of JCGM 100:2008 §5.2.2
equation (13). With `ρ = 0` equation (13) collapses onto equation
(10), so the independent case is a special case rather than a
separate code path.

Both quantities must derive from a single source each; correlations
between composite quantities are declared between their underlying
sources.

Traces REQ-203, REQ-205.
"""
function declare_correlated(
    m1::SymbolicMeasurement,
    m2::SymbolicMeasurement,
    ρ::Union{Real,Symbolics.Num},
)
    # Count the sources the quantity DERIVES from, not the descriptors
    # its context carries: a quantity that already took part in a
    # declaration carries its partner's descriptor too, while still
    # depending on one source. Counting the context made a second
    # declaration impossible, so three mutually correlated inputs —
    # JCGM 100:2008 §H.2 — could not be expressed at all.
    t1, t2 = terms_of(m1), terms_of(m2)
    if length(t1) != 1 || length(t2) != 1
        throw(
            ArgumentError(
                "declare_correlated expects each quantity to derive from " *
                "one source; got $(length(t1)) and $(length(t2)). Declare " *
                "the correlation between the underlying sources instead " *
                "(JCGM 100:2008 §5.2.2).",
            ),
        )
    end
    s1, s2 = sources_of(m1), sources_of(m2)
    id1, id2 = only(keys(t1)), only(keys(t2))
    if id1 == id2
        throw(
            ArgumentError(
                "cannot declare a correlation between a source and itself " *
                "(JCGM 100:2008 §5.2.2).",
            ),
        )
    end

    covariance = Symbolics.Num(ρ) * s1[id1].u * s2[id2].u
    merged = _merge_cov(
        _merge_cov(cov_of(m1), cov_of(m2)),
        _Cov((id1, id2) => covariance),
    )
    srcs = _merge_sources(s1, s2)

    return (
        SymbolicMeasurement(m1.val, copy(terms_of(m1)), srcs, merged),
        SymbolicMeasurement(m2.val, copy(terms_of(m2)), srcs, merged),
    )
end

"""
    covariance(m1, m2) -> Symbolics.Num

Covariance between two measurands, derived from the sources they share.

JCGM 102:2011 §6 asks for the covariance matrix of a vector-valued
measurand, not merely its marginal uncertainties: a user who combines
two outputs further needs to know how they move together. Before M11
that could not be answered — `propagate_vector` returned marginal
uncertainties and left cross-output covariance out of scope — because
nothing recorded which inputs an output derived from.

It follows from the linear forms:

    cov(y₁, y₂) = Σᵢ Σⱼ (∂y₁/∂sᵢ)(∂y₂/∂sⱼ) · cov(sᵢ, sⱼ)

with `cov(sᵢ, sᵢ) = u²(sᵢ)` and off-diagonal terms taken from the
declared covariances (zero unless declared). `covariance(m, m)` is
therefore the variance, and quantities sharing no source have
covariance zero.

Traces REQ-033, REQ-203, REQ-205.
"""
function covariance(m1::SymbolicMeasurement, m2::SymbolicMeasurement)
    t1, t2 = terms_of(m1), terms_of(m2)
    (isempty(t1) || isempty(t2)) && return Symbolics.Num(0)

    srcs = _merge_sources(sources_of(m1), sources_of(m2))
    cov = _merge_cov(cov_of(m1), cov_of(m2))

    ids1 = sort!(collect(keys(t1)); by = s -> s.id)
    ids2 = sort!(collect(keys(t2)); by = s -> s.id)

    total = Symbolics.Num(0)
    for a in ids1, b in ids2
        if a == b
            total = total + t1[a] * t2[b] * srcs[a].u^2
        else
            c = get(cov, (a, b), get(cov, (b, a), nothing))
            c === nothing && continue
            total = total + t1[a] * t2[b] * c
        end
    end
    return _simplify_for_report(total)
end

"""
    correlation(m1, m2) -> Symbolics.Num

Correlation coefficient `r(y₁, y₂) = cov(y₁, y₂) / (u(y₁)·u(y₂))`,
per JCGM 100:2008 §5.2.2 equation (14).

Returns zero when either quantity carries no uncertainty, since the
coefficient is then undefined rather than infinite.

Traces REQ-033, REQ-203.
"""
function correlation(m1::SymbolicMeasurement, m2::SymbolicMeasurement)
    u1, u2 = m1.err, m2.err
    (isequal(Symbolics.value(u1), 0) || isequal(Symbolics.value(u2), 0)) &&
        return Symbolics.Num(0)
    return _simplify_for_report(covariance(m1, m2) / (u1 * u2))
end
