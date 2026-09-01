module SymbolicUncertaintiesMonteCarloExt

# Monte Carlo cross-validation of the first-order GUM result
# (JCGM 101:2008 §8).
#
# The propagation goes through `m.val` — the NONLINEAR measurement
# model — with each input variable replaced by sampled `Particles`.
# Perturbing the linear form instead would reproduce the first-order
# answer by construction and validate nothing, which is the trap this
# milestone exists to avoid.
#
# The extension is triggered by BOTH `MonteCarloMeasurements` and
# `Distributions`: the caller states each input's density as a
# `Distributions` object, so the two are needed together, and taking
# `Distributions` as a second trigger keeps `Statistics` out of the
# package's mandatory dependencies (REQ-130).
#
# Traces REQ-230, REQ-231, REQ-233, REQ-234.

import SymbolicUncertainties
import Symbolics
import MonteCarloMeasurements
import Distributions

const SU = SymbolicUncertainties
const MCM = MonteCarloMeasurements

# JCGM 102:2011 is about a vector-valued measurand, and its subject is
# the covariance BETWEEN outputs. Sampling each output separately
# would draw independent inputs and measure a correlation of zero by
# construction, so the outputs have to be evaluated on one draw. These
# helpers collect the source structure across the whole vector.
_as_vector(m::SU.SymbolicMeasurement) = (m,)
_as_vector(ms) = ms

function _merged_sources(ms)
    out = Dict{SU.SourceId,Any}()
    for m in _as_vector(ms), (sid, src) in SU.sources_of(m)
        out[sid] = src
    end
    return out
end

function _merged_terms(ms)
    out = Dict{SU.SourceId,Any}()
    for m in _as_vector(ms), (sid, t) in SU.terms_of(m)
        out[sid] = t
    end
    return out
end

function _merged_cov(ms)
    out = Dict{Tuple{SU.SourceId,SU.SourceId},Any}()
    for m in _as_vector(ms), (k, v) in SU.cov_of(m)
        out[k] = v
    end
    return out
end

# Every source of the quantity must name an input, and every named
# input must have a density. Silence on either side would mean
# sampling something the caller did not describe.
# A source of zero standard uncertainty is not a source of
# uncertainty: `_wrap` mints one for every constant operand, so
# `y * (30.0 - 20.0)` carries one whose estimate is a number rather
# than an input variable. Asking the caller for its density would
# demand a distribution for the constant 10.
_carries_uncertainty(src) = !isequal(Symbolics.value(src.u), 0)

function _check_spec(ms, distributions)
    srcs = _merged_sources(ms)
    terms = _merged_terms(ms)
    for (sid, src) in srcs
        haskey(terms, sid) || continue
        _carries_uncertainty(src) || continue
        if src.variable === nothing
            throw(
                ArgumentError(
                    "monte_carlo: a source of this quantity was built " *
                    "from an estimate that is not a bare input " *
                    "variable, so there is no input to assign a " *
                    "density to. Build the model from `x ± u` on the " *
                    "input quantities (JCGM 101:2008 §6.4).",
                ),
            )
        end
        any(isequal(src.variable), keys(distributions)) || throw(
            ArgumentError(
                "monte_carlo: no distribution given for input " *
                "`$(src.variable)`. JCGM 101:2008 §6.4 requires a " *
                "density per input quantity, and the package will not " *
                "default one: a standard uncertainty is not a " *
                "distribution, and assuming normality would make the " *
                "validation circular.",
            ),
        )
    end
    return nothing
end

# Numeric substitution for the first-order side: each input takes the
# expectation of its assigned density and each standard uncertainty
# its standard deviation, which is what JCGM 101:2008 §6.4 means by
# assigning a PDF to an input quantity.
function _gum_values(ms, distributions)
    vals = Dict{Symbolics.Num,Float64}()
    terms = _merged_terms(ms)
    for (sid, src) in _merged_sources(ms)
        haskey(terms, sid) || continue
        _carries_uncertainty(src) || continue
        d = distributions[findfirst_key(distributions, src.variable)]
        vals[src.variable] = Float64(Distributions.mean(d))
        u = Symbolics.value(src.u)
        if u isa Symbolics.SymbolicUtils.BasicSymbolic &&
           !Symbolics.SymbolicUtils.iscall(u)
            vals[src.u] = Float64(Distributions.std(d))
        end
    end
    return vals
end

findfirst_key(d, k) = first(filter(key -> isequal(key, k), collect(keys(d))))

_as_float(expr, vals) = begin
    s = Symbolics.substitute(expr, vals)
    v = Symbolics.value(s)
    v isa Number ? Float64(v) : Float64(eval(Symbolics.toexpr(v)))
end

# JCGM 101:2008 §8.2: express u_c to `ndig` significant digits; the
# numerical tolerance is half a unit in the last of them.
function _tolerance(u_gum::Float64, ndig::Int)
    u_gum == 0 && return 0.0
    a = floor(Int, log10(abs(u_gum))) - (ndig - 1)
    return 0.5 * 10.0^a
end

# Cholesky–Banachiewicz, lower factor, or `nothing` when the matrix is
# not positive definite.
#
# Written here rather than taken from `LinearAlgebra` for the reason
# the interval arithmetic of the certified-linearisation work was:
# REQ-130 keeps `Symbolics.jl` the only mandatory dependency, and a
# package extension may not reach for a standard library the package
# itself does not depend on. The matrix is one row per correlated
# input, so it is small.
#
# The factorisation is its own positive-definiteness test: the
# diagonal term under the square root goes non-positive exactly when
# no joint distribution has the declared correlations.
function _cholesky_lower(Σ::Matrix{Float64})
    k = size(Σ, 1)
    L = zeros(Float64, k, k)
    for i in 1:k, j in 1:i
        acc = Σ[i, j]
        for p in 1:(j-1)
            acc -= L[i, p] * L[j, p]
        end
        if i == j
            acc <= 0 && return nothing
            L[i, j] = sqrt(acc)
        else
            L[i, j] = acc / L[j, j]
        end
    end
    return L
end

# Sampling the inputs.
#
# Independent sources sample independently. Declared covariances do
# not: sampling correlated sources as if they were independent would
# silently reproduce the uncorrelated answer, and the §8.2 comparison
# would then "agree" for exactly the wrong reason — the failure this
# milestone was written to avoid.
#
# The correlated case is the multivariate normal of JCGM 101:2008
# §6.4.8: draw independent standard normals and apply the Cholesky
# factor of the covariance matrix. That construction preserves the
# marginals only because they are normal. Applying it to a rectangular
# or triangular marginal would change the very density the caller
# stated, so a non-normal marginal on a correlated input is refused
# rather than quietly transformed — the joint PDF is then something
# the caller has to supply, and JCGM 101 §6.4.8.4 says as much.
#
# Traces REQ-232.
function _sample_inputs(ms, distributions, n)
    subs = Dict{Symbolics.Num,Any}()
    cov = _merged_cov(ms)
    terms = _merged_terms(ms)
    srcs = _merged_sources(ms)
    live = [sid for sid in keys(terms) if _carries_uncertainty(srcs[sid])]

    correlated = Set{SU.SourceId}()
    for ((a, b), _) in cov
        (a in live && b in live) || continue
        push!(correlated, a)
        push!(correlated, b)
    end

    for sid in live
        sid in correlated && continue
        d = distributions[findfirst_key(distributions, srcs[sid].variable)]
        subs[srcs[sid].variable] = MCM.Particles(n, d)
    end
    isempty(correlated) && return subs

    ids = sort!(collect(correlated); by = s -> s.id)
    ds = [
        distributions[findfirst_key(distributions, srcs[s].variable)] for
        s in ids
    ]
    for (s, d) in zip(ids, ds)
        d isa Distributions.Normal || throw(
            ArgumentError(
                "monte_carlo: input `$(srcs[s].variable)` takes part in a " *
                "declared correlation but was given a " *
                "$(nameof(typeof(d))) density. Correlated sampling here " *
                "is the multivariate normal of JCGM 101:2008 §6.4.8; " *
                "imposing it on a non-normal marginal would change the " *
                "density you stated. Supply normal marginals, or a joint " *
                "PDF (§6.4.8.4), for the correlated inputs.",
            ),
        )
    end

    # Numeric covariance matrix over the correlated sources: the
    # variances come from the stated densities, the off-diagonals from
    # the declared covariances.
    vals = _gum_values(ms, distributions)
    k = length(ids)
    Σ = zeros(Float64, k, k)
    for i in 1:k
        Σ[i, i] = Float64(Distributions.var(ds[i]))
    end
    for i in 1:k, j in (i+1):k
        c = get(cov, (ids[i], ids[j]), get(cov, (ids[j], ids[i]), nothing))
        c === nothing && continue
        Σ[i, j] = Σ[j, i] = _as_float(c, vals)
    end

    L = _cholesky_lower(Σ)
    L === nothing && throw(
        ArgumentError(
            "monte_carlo: the declared correlations imply a covariance " *
            "matrix that is not positive semi-definite, so no joint " *
            "distribution has them. Pairwise correlation coefficients " *
            "assigned by hand easily produce this; check them against " *
            "each other (JCGM 100:2008 §5.2.2, JCGM 101:2008 §6.4.8).",
        ),
    )
    z = [MCM.Particles(n, Distributions.Normal(0.0, 1.0)) for _ in 1:k]
    for i in 1:k
        v = srcs[ids[i]].variable
        acc = Float64(Distributions.mean(ds[i]))
        for j in 1:i
            acc = acc + L[i, j] * z[j]
        end
        subs[v] = acc
    end
    return subs
end

function SymbolicUncertainties.monte_carlo(
    m::SU.SymbolicMeasurement,
    distributions::AbstractDict;
    n::Int = 200_000,
    coverage_probability::Float64 = 0.95,
    ndig::Int = 2,
    adaptive::Bool = false,
    max_blocks::Int = 100,
)
    _check_spec(m, distributions)
    adaptive && return _adaptive(
        m,
        distributions,
        n,
        coverage_probability,
        ndig,
        max_blocks,
    )

    # Sample each input, then evaluate the nonlinear model on the
    # samples. `Particles` carries the whole distribution through the
    # arithmetic, so this is the model's own response, not a
    # linearisation of it.
    subs = _sample_inputs(m, distributions, n)
    sampled = Symbolics.substitute(m.val, subs)
    out = Symbolics.value(sampled)
    out isa MCM.Particles || (out = eval(Symbolics.toexpr(out)))

    vals = _gum_values(m, distributions)
    return _compare(m, out, vals, n, coverage_probability, ndig)
end

# The adaptive Monte Carlo procedure of JCGM 101:2008 §7.9.
#
# A verdict from a single run is only as trustworthy as the `n` the
# caller happened to pass: the standard error of a tail quantile falls
# as 1/√n, so near the §8.2 boundary the answer flips between runs.
# §7.9 answers this by drawing blocks of M trials until the results
# have stabilised in a statistical sense — twice the standard
# deviation of the block means, for each of the four quantities the
# comparison rests on, below the numerical tolerance δ.
#
# The four are the estimate, u(y), and both endpoints of the coverage
# interval. Stabilising u(y) alone would not do: §8.2 compares
# intervals, and it is their endpoints that carry the quantile noise.
#
# Traces REQ-237.
function _block(m, distributions, block, α)
    subs = _sample_inputs(m, distributions, block)
    sampled = Symbolics.substitute(m.val, subs)
    out = Symbolics.value(sampled)
    out isa MCM.Particles || (out = eval(Symbolics.toexpr(out)))
    return (
        MCM.pmean(out),
        MCM.pstd(out),
        MCM.pquantile(out, α),
        MCM.pquantile(out, 1 - α),
    )
end

# Standard deviation of the mean of `xs`, the quantity §7.9 compares
# against δ.
function _sdom(xs)
    h = length(xs)
    h < 2 && return Inf
    m = sum(xs) / h
    return sqrt(sum((x - m)^2 for x in xs) / (h * (h - 1)))
end

function _adaptive(
    m,
    distributions,
    block,
    coverage_probability,
    ndig,
    max_blocks,
)
    vals = _gum_values(m, distributions)
    estimate_gum = _as_float(m.val, vals)
    u_gum = _as_float(m.err, vals)
    δ = _tolerance(u_gum, ndig)
    α = (1 - coverage_probability) / 2

    ys = Float64[]
    us = Float64[]
    los = Float64[]
    his = Float64[]
    converged = false

    while length(ys) < max_blocks
        y, u, lo, hi = _block(m, distributions, block, α)
        push!(ys, y)
        push!(us, u)
        push!(los, lo)
        push!(his, hi)
        length(ys) < 2 && continue
        spread = max(_sdom(ys), _sdom(us), _sdom(los), _sdom(his))
        if δ > 0 && 2 * spread <= δ
            converged = true
            break
        end
    end

    h = length(ys)
    mean(xs) = sum(xs) / length(xs)
    estimate_mc = mean(ys)
    u_mc = mean(us)
    interval_mc = (mean(los), mean(his))
    k = _normal_k(coverage_probability)
    interval_gum = (estimate_gum - k * u_gum, estimate_gum + k * u_gum)
    d_low = abs(interval_gum[1] - interval_mc[1])
    d_high = abs(interval_gum[2] - interval_mc[2])

    converged || @warn (
        "monte_carlo: the §7.9 adaptive procedure did not stabilise " *
        "within $(max_blocks) blocks of $(block) trials. The result " *
        "below is the block average, but nothing certifies it to the " *
        "numerical tolerance — raise `n` or `max_blocks` before " *
        "reading it as a property of the measurement model."
    )

    return SU.MonteCarloComparison(
        h * block,
        h,
        converged,
        estimate_gum,
        u_gum,
        estimate_mc,
        u_mc,
        interval_gum,
        interval_mc,
        coverage_probability,
        ndig,
        δ,
        d_low <= δ && d_high <= δ,
    )
end

# The §8.2 comparison itself, shared by the scalar and vector entry
# points so that a vector-valued measurand is judged output by output
# on exactly the same terms.
function _compare(m, out, vals, n, coverage_probability, ndig)
    estimate_mc = MCM.pmean(out)
    u_mc = MCM.pstd(out)

    estimate_gum = _as_float(m.val, vals)
    u_gum = _as_float(m.err, vals)

    # Probabilistically symmetric coverage intervals (§7.7.1).
    α = (1 - coverage_probability) / 2
    interval_mc = (MCM.pquantile(out, α), MCM.pquantile(out, 1 - α))
    k = _normal_k(coverage_probability)
    interval_gum = (estimate_gum - k * u_gum, estimate_gum + k * u_gum)

    δ = _tolerance(u_gum, ndig)
    d_low = abs(interval_gum[1] - interval_mc[1])
    d_high = abs(interval_gum[2] - interval_mc[2])

    # The verdict is a comparison against sampling noise, so it is
    # only as trustworthy as the number of trials. JCGM 101:2008 §7.9
    # answers this with an adaptive procedure — increase M until the
    # results are stable to the numerical tolerance. Short of that,
    # say so rather than let a noisy verdict be read as a metrological
    # finding: the standard error of a tail quantile falls only as
    # 1/√n, and near the boundary a rerun can flip the answer.
    margin = max(d_low, d_high)
    if δ > 0 && abs(margin - δ) < 0.25δ
        @warn (
            "monte_carlo: the §8.2 verdict is marginal at n = $(n) — " *
            "the interval discrepancy ($(round(margin, sigdigits = 3))) " *
            "is within 25 % of the tolerance ($(round(δ, sigdigits = 3))). " *
            "Increase `n` before reading this as a property of the " *
            "measurement model (JCGM 101:2008 §7.9)."
        )
    end

    return SU.MonteCarloComparison(
        n,
        1,
        false,
        estimate_gum,
        u_gum,
        estimate_mc,
        u_mc,
        interval_gum,
        interval_mc,
        coverage_probability,
        ndig,
        δ,
        d_low <= δ && d_high <= δ,
    )
end

# The GUM framework's own coverage factor for the stated probability,
# under the normal assumption of §G.2.3.
function _normal_k(p::Float64)
    p == 0.95 && return 1.959963984540054
    p == 0.99 && return 2.5758293035489004
    p == 0.9973 && return 3.0
    p == 0.6827 && return 1.0
    throw(
        ArgumentError(
            "monte_carlo: coverage_probability must be one of 0.6827, " *
            "0.95, 0.99, 0.9973 — the values JCGM 100:2008 Table G.1 " *
            "tabulates; got $p.",
        ),
    )
end

# `MonteCarloMeasurements.pcor` takes a vector of particle sets and
# returns their correlation matrix; the pairwise entry is what the
# comparison needs.
_pcor2(a, b) = MCM.pcor([a, b])[1, 2]

"""
    monte_carlo(ms::AbstractVector{<:SymbolicMeasurement}, distributions; kwargs...)

Cross-validate a **vector-valued** measurand: each output against the
first-order result, and the correlation *between* outputs.

JCGM 102:2011 §6 asks for the covariance matrix of a vector-valued
measurand, not only its marginal uncertainties, because that matrix is
what a downstream user needs to combine the outputs further. Two
separate `monte_carlo` calls would draw independent inputs and measure
a correlation of zero by construction, so the outputs are evaluated on
one draw.

Returns a `NamedTuple` of `(per_output, correlation_gum,
correlation_mc)`; `per_output` holds one
[`MonteCarloComparison`](@ref) each, and the two matrices are
comparable entry by entry.

Traces REQ-236.
"""
function SymbolicUncertainties.monte_carlo(
    ms::AbstractVector{<:SU.SymbolicMeasurement},
    distributions::AbstractDict;
    n::Int = 200_000,
    coverage_probability::Float64 = 0.95,
    ndig::Int = 2,
    adaptive::Bool = false,
)
    adaptive && throw(
        ArgumentError(
            "monte_carlo: the adaptive procedure of JCGM 101:2008 §7.9 " *
            "is stated for the four scalar results of a single " *
            "measurand. What it would mean for a correlation matrix to " *
            "have stabilised is not something the standard says, so it " *
            "is refused here rather than guessed at. Cross-validate " *
            "each output adaptively on its own if you need that.",
        ),
    )
    isempty(ms) && throw(
        ArgumentError("monte_carlo: no measurand given to cross-validate."),
    )
    _check_spec(ms, distributions)

    subs = _sample_inputs(ms, distributions, n)
    vals = _gum_values(ms, distributions)

    outs = map(ms) do m
        sampled = Symbolics.substitute(m.val, subs)
        out = Symbolics.value(sampled)
        out isa MCM.Particles ? out : eval(Symbolics.toexpr(out))
    end

    per_output = [
        _compare(ms[i], outs[i], vals, n, coverage_probability, ndig) for
        i in eachindex(ms)
    ]

    k = length(ms)
    correlation_gum = zeros(Float64, k, k)
    correlation_mc = zeros(Float64, k, k)
    for i in 1:k, j in 1:k
        correlation_gum[i, j] =
            i == j ? 1.0 : _as_float(SU.correlation(ms[i], ms[j]), vals)
        correlation_mc[i, j] = i == j ? 1.0 : _pcor2(outs[i], outs[j])
    end

    return (
        per_output = per_output,
        correlation_gum = correlation_gum,
        correlation_mc = correlation_mc,
    )
end

end # module
