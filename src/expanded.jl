"""
    ExpandedUncertainty

Result of an expanded-uncertainty calculation: the estimate `val`, the
expanded uncertainty `U = k · u_c`, the coverage factor `k`, and the
effective degrees of freedom the factor was derived from.

Deliberately **not** a `SymbolicMeasurement`. `U` is a coverage
interval half-width, not a standard uncertainty, so a quantity
carrying it is not propagatable: feeding `U` back into a computation
would silently inflate every downstream result by `k`. Returning a
distinct type makes that mistake impossible to make by accident
(JCGM 100:2008 §6.2).

Traces REQ-050, REQ-051.
"""
struct ExpandedUncertainty
    val::Symbolics.Num
    U::Symbolics.Num
    k::Symbolics.Num
    dof::Union{Symbolics.Num,Nothing}
end

function Base.show(io::IO, e::ExpandedUncertainty)
    print(io, e.val, " ± ", e.U, " (k = ", e.k, ")")
end

# Expanded uncertainty — JCGM 100:2008 §6.2 equation (18), and
# the Welch-Satterthwaite coverage-probability pathway per §G.4.
#
# The positional form `expanded_uncertainty(m, k)` multiplies
# `m.err` by a coverage factor (default `k = 2`, matching EA-4/02
# usage and the GUM Annex H worked examples).
#
# The keyword form `expanded_uncertainty(m; coverage_probability)`
# derives `k` from `m.dof` via an internal Student-t quantile
# table (GUM Table G.2 verbatim; see
# `specs/005-budget-and-expanded/research.md` R2).

# Internal Student-t quantile table — GUM 100:2008 Table G.2,
# keyed by coverage probability, rows indexed by degrees of freedom
# ν ∈ 1..30. For ν ≥ 30, fall back to the normal quantile.
const _T_QUANTILE_068 = Dict{Int,Float64}(
    1 => 1.84,
    2 => 1.32,
    3 => 1.20,
    4 => 1.14,
    5 => 1.11,
    6 => 1.09,
    7 => 1.08,
    8 => 1.07,
    9 => 1.06,
    10 => 1.05,
    11 => 1.05,
    12 => 1.04,
    13 => 1.04,
    14 => 1.04,
    15 => 1.03,
    16 => 1.03,
    17 => 1.03,
    18 => 1.03,
    19 => 1.03,
    20 => 1.03,
    21 => 1.03,
    22 => 1.02,
    23 => 1.02,
    24 => 1.02,
    25 => 1.02,
    26 => 1.02,
    27 => 1.02,
    28 => 1.02,
    29 => 1.02,
    30 => 1.02,
)

const _T_QUANTILE_090 = Dict{Int,Float64}(
    1 => 6.31,
    2 => 2.92,
    3 => 2.35,
    4 => 2.13,
    5 => 2.02,
    6 => 1.94,
    7 => 1.89,
    8 => 1.86,
    9 => 1.83,
    10 => 1.81,
    11 => 1.80,
    12 => 1.78,
    13 => 1.77,
    14 => 1.76,
    15 => 1.75,
    16 => 1.75,
    17 => 1.74,
    18 => 1.73,
    19 => 1.73,
    20 => 1.72,
    21 => 1.72,
    22 => 1.72,
    23 => 1.71,
    24 => 1.71,
    25 => 1.71,
    26 => 1.71,
    27 => 1.70,
    28 => 1.70,
    29 => 1.70,
    30 => 1.70,
)

const _T_QUANTILE_095 = Dict{Int,Float64}(
    1 => 12.71,
    2 => 4.30,
    3 => 3.18,
    4 => 2.78,
    5 => 2.57,
    6 => 2.45,
    7 => 2.36,
    8 => 2.31,
    9 => 2.26,
    10 => 2.23,
    11 => 2.20,
    12 => 2.18,
    13 => 2.16,
    14 => 2.14,
    15 => 2.13,
    16 => 2.12,
    17 => 2.11,
    18 => 2.10,
    19 => 2.09,
    20 => 2.09,
    21 => 2.08,
    22 => 2.07,
    23 => 2.07,
    24 => 2.06,
    25 => 2.06,
    26 => 2.06,
    27 => 2.05,
    28 => 2.05,
    29 => 2.05,
    30 => 2.04,
)

const _T_QUANTILE_099 = Dict{Int,Float64}(
    1 => 63.66,
    2 => 9.92,
    3 => 5.84,
    4 => 4.60,
    5 => 4.03,
    6 => 3.71,
    7 => 3.50,
    8 => 3.36,
    9 => 3.25,
    10 => 3.17,
    11 => 3.11,
    12 => 3.05,
    13 => 3.01,
    14 => 2.98,
    15 => 2.95,
    16 => 2.92,
    17 => 2.90,
    18 => 2.88,
    19 => 2.86,
    20 => 2.85,
    21 => 2.83,
    22 => 2.82,
    23 => 2.81,
    24 => 2.80,
    25 => 2.79,
    26 => 2.78,
    27 => 2.77,
    28 => 2.76,
    29 => 2.76,
    30 => 2.75,
)

const _NORMAL_QUANTILE = Dict{Float64,Float64}(
    0.68 => 1.00,
    0.90 => 1.645,
    0.95 => 1.96,
    0.99 => 2.576,
)

const _T_QUANTILE_TABLES = Dict{Float64,Dict{Int,Float64}}(
    0.68 => _T_QUANTILE_068,
    0.90 => _T_QUANTILE_090,
    0.95 => _T_QUANTILE_095,
    0.99 => _T_QUANTILE_099,
)

# Look up a coverage factor for a given coverage probability and
# (possibly) effective degrees of freedom. Returns the numeric `k`
# as a `Float64`.
#
# - `dof === nothing` or symbolic `Num` → normal quantile + `@info`
# - `dof = Num(n)` with `n::Real`, `n === Inf` → normal quantile
# - `dof = Num(n)` with `n::Real`, `n >= 30` → normal quantile
# - `dof = Num(n)` with `n::Real`, `1 <= n < 30` → t-quantile + `@warn`
# - `dof = Num(n)` with `n::Real`, `n < 1` → ArgumentError
# Student's t quantile as a Cornish-Fisher expansion in 1/ν:
#
#   t ≈ z + (z³+z)/(4ν) + (5z⁵+16z³+3z)/(96ν²)
#         + (3z⁷+19z⁵+17z³−15z)/(384ν³)
#
# where z is the normal quantile at the same coverage probability.
# This is a genuine closed form in ν, so a symbolic `ν_eff` produces a
# symbolic `k` that still honours the degrees of freedom — where the
# pre-M12 fallback returned the normal quantile and dropped them.
#
# The expansion is asymptotic in 1/ν and degrades below roughly ν = 10;
# REQ-175 already warns whenever a numeric ν_eff falls under 30, which
# covers the range where a user should be reaching for JCGM 101:2008
# instead. Against Table G.2 at p = 0.95 it gives 2.2280 at ν = 10
# (table: 2.228) and 2.0423 at ν = 30 (table: 2.042).
#
# Traces REQ-051, REQ-215.
function _student_t_series(p::Float64, ν)
    z = _NORMAL_QUANTILE[p]
    z3, z5, z7 = z^3, z^5, z^7
    inv_ν = 1 / Symbolics.Num(ν)
    return z +
           (z3 + z) / 4 * inv_ν +
           (5z5 + 16z3 + 3z) / 96 * inv_ν^2 +
           (3z7 + 19z5 + 17z3 - 15z) / 384 * inv_ν^3
end

function _coverage_factor(p::Float64, dof)
    if !haskey(_NORMAL_QUANTILE, p)
        throw(
            ArgumentError(
                "coverage_probability must be one of " *
                "$(collect(keys(_NORMAL_QUANTILE))); got $p " *
                "(see JCGM 100:2008 Table G.2).",
            ),
        )
    end

    if dof === nothing
        @info (
            "expanded_uncertainty: `m.dof` is not set — using " *
            "normal-distribution quantile at p = $p."
        )
        return _NORMAL_QUANTILE[p]
    end

    # dof is a Num; try to extract a concrete numeric value.
    raw = Symbolics.value(dof)
    if !(raw isa Real)
        # Symbolic ν: return the Cornish-Fisher expansion rather than
        # the normal quantile. The old fallback silently discarded the
        # degrees of freedom, which is the one thing a coverage factor
        # exists to account for.
        return _student_t_series(p, dof)
    end

    if !isfinite(raw)
        # Num(Inf) — user-asserted normal limit; no warning, no info.
        return _NORMAL_QUANTILE[p]
    end

    if raw < 1
        throw(
            ArgumentError(
                "effective degrees of freedom must be ≥ 1, got $raw " *
                "(JCGM 100:2008 §G.4).",
            ),
        )
    end

    if raw >= 30
        return _NORMAL_QUANTILE[p]
    end

    # 1 ≤ raw < 30: look up the t-quantile table.
    table = _T_QUANTILE_TABLES[p]
    ν = Int(floor(raw))
    @warn (
        "expanded_uncertainty: ν_eff = $raw < 30 — the `k = 2` " *
        "normal-distribution shortcut is inadequate (JCGM 100:2008 " *
        "§6.3.3). Using Student-t quantile from Table G.2."
    )
    return table[ν]
end

"""
    expanded_uncertainty(m::SymbolicMeasurement, k = 2) -> ExpandedUncertainty

!!! warning "Coverage factor assumptions"
    `expanded_uncertainty(m, k)` returns `U = k·u_c(y)` under the
    GUM §6.3.3 assumption that the output distribution is
    approximately normal. When the effective degrees of freedom
    `ν_eff < 30`, the shortcut `k = 2` for 95 % coverage is
    inadequate; use the keyword form
    `expanded_uncertainty(m; coverage_probability = …)` so that
    `k` is derived from `m.dof` via the Student-t quantile of
    JCGM 100:2008 §G.4.

Return a measurement with `val = m.val`, `err = k·m.err`, and
`dof = m.dof` (preserved). The default `k = 2` matches EA-4/02
usage and the GUM Annex H worked examples.

Negative numeric `k` raises `ArgumentError`. Symbolic `k` is
left in closed form with no sign inspection.

Implements the methodology of JCGM 100:2008 §6.2 equation (18).
Traces REQ-050.
"""
function expanded_uncertainty(m::SymbolicMeasurement, k)
    if k isa Real && !(k isa Symbolics.Num) && k < 0
        throw(
            ArgumentError(
                "coverage factor k must be non-negative (GUM §6.2); got $k.",
            ),
        )
    end
    # NOT simplified. `k` may be the Cornish-Fisher series, which
    # contains (1/ν)³; when ν_eff is itself a Welch-Satterthwaite
    # fraction, expanding the product inflates it beyond any use —
    # measured at 285 000 characters for a three-source voltage
    # divider, versus a few hundred left factored. The structured form
    # is also the readable one: `k · u_c` says what it is.
    U = Symbolics.Num(k) * m.err
    return ExpandedUncertainty(m.val, U, Symbolics.Num(k), m.dof)
end

"""
    expanded_uncertainty(m; coverage_probability=nothing) -> ExpandedUncertainty

Single-argument convenience wrapper. With no keyword argument it
applies the default `k = 2`, matching EA-4/02 usage. With an
explicit `coverage_probability`, it derives `k` from `m.dof` via
the Student-t quantile of JCGM 100:2008 §G.4 Table G.2.

!!! warning "Coverage factor assumptions"
    The keyword form derives `k` from `m.dof` via the Student-t
    quantile of JCGM 100:2008 §G.4 Table G.2. When `m.dof` is
    `nothing` or a symbolic expression, the normal-distribution
    quantile is used instead (per GUM §6.3.3); a numeric
    `ν_eff < 30` emits a runtime `@warn`.

Supported `coverage_probability` values: `{0.68, 0.90, 0.95, 0.99}`
— the four entries of GUM Table G.2. Other values raise
`ArgumentError`.

See `expanded_uncertainty(m, k)` for the positional form.

Implements the methodology of JCGM 100:2008 §6.2 / §G.4.
Traces REQ-050, REQ-051, REQ-174, REQ-175.
"""
function expanded_uncertainty(
    m::SymbolicMeasurement;
    coverage_probability = nothing,
)
    if coverage_probability === nothing
        return expanded_uncertainty(m, 2)
    end
    p = Float64(coverage_probability)
    k = _coverage_factor(p, m.dof)
    return expanded_uncertainty(m, k)
end
