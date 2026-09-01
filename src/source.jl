# M11 phase 1 — independent uncertainty sources.
#
# An uncertain quantity knows which independent measurements it
# derives from and with what sensitivity. This file defines those
# sources; `src/type.jl` carries them.
#
# Phase 0 decided AGAINST a module-level registry. Source descriptors
# and declared covariances are carried by the quantity, because a
# registry breaks `Symbolics.substitute`: substituting `σx => 0.7`
# would have to reach shared state, and without that a fully
# substituted measurement no longer yields a number (REQ-120,
# REQ-123, M4 exit criterion). The only global left is the atomic
# counter below, which makes `±` impure exactly as `gensym` is.

"""
    SourceId

Identity of one independent uncertainty source, per JCGM 100:2008
§4.1 (input quantities `Xᵢ` whose estimates are the `xᵢ`).

Two quantities sharing a `SourceId` derive from the same physical
measurement, which is what makes their covariance computable without
a user-supplied matrix.

Traces REQ-200.
"""
struct SourceId
    id::UInt64
end

"""
    Source

Description of one independent source: its symbolic standard
uncertainty `u` (JCGM 100:2008 §2.3.1), its optional degrees of
freedom (§G.3, used by Welch-Satterthwaite), a display name, and the
input variable it perturbs.

`variable` is the input the source was declared on — the `V` of
`V ± σV`. It is `nothing` when the estimate is numeric or is already a
function of an input, such as `(V + 1) ± σ`, which is not itself an
input of the measurement model. It is a provenance label rather than a
value, so it survives substitution: a fully numeric budget can still
say which input each contribution came from.

Traces REQ-200, REQ-208, REQ-235.
"""
struct Source
    u::Symbolics.Num
    dof::Union{Symbolics.Num,Nothing}
    name::Symbol
    variable::Union{Symbolics.Num,Nothing}
end

# A source built before the input variable was recorded, or from an
# estimate that is not a bare input variable.
Source(u::Symbolics.Num, dof, name::Symbol) = Source(u, dof, name, nothing)

# `V ± σV` states that the input V was measured with standard
# uncertainty σV. Keeping σV and dropping V lost the only link
# between a contribution and the input it came from: every budget row
# was labelled `:opaque`, and a Monte Carlo cross-check could perturb
# only the linear form — comparing the linearisation with itself.
#
# Only a **bare** input variable is recorded. `(V + 1) ± σ` is already
# a function of an input, not an input, and naming it would invent an
# input the measurement model does not have.
function _input_variable(val::Symbolics.Num)
    v = Symbolics.value(val)
    v isa Symbolics.SymbolicUtils.BasicSymbolic || return nothing
    Symbolics.SymbolicUtils.iscall(v) && return nothing
    return val
end

_source_name(variable) =
    variable === nothing ? :opaque : Symbol(string(variable))

# Sole global state: a fresh-identity counter. Bounded, leak-free
# between tests, and harmless to M10's `@compile_workload`.
const _SOURCE_COUNTER = Threads.Atomic{UInt64}(0)

# Mint an identifier no other source holds. Called once per `±`.
# Traces REQ-200.
_fresh_source_id() = SourceId(Threads.atomic_add!(_SOURCE_COUNTER, UInt64(1)))

const _Terms = Dict{SourceId,Symbolics.Num}
const _Sources = Dict{SourceId,Source}
const _Cov = Dict{Tuple{SourceId,SourceId},Symbolics.Num}

# Accumulate sensitivity `c` for source `sid`, ADDING to any
# sensitivity already recorded for it.
#
# This is the whole of REQ-201: contributions of one source combine as
# sensitivities before the variance is formed. Squaring each
# contribution separately is what makes `x - x` report `σ√2` instead
# of `0` — `1` and `-1` must cancel to `0`, not accumulate to `√2`.
function _add_term!(terms::_Terms, sid::SourceId, c::Symbolics.Num)
    prev = get(terms, sid, nothing)
    terms[sid] = prev === nothing ? c : prev + c
    return terms
end

# Union of two source contexts. Conflict-free by construction: a given
# `SourceId` can only originate from one `±` call, so both sides
# describe it identically.
function _merge_sources(a::_Sources, b::_Sources)
    isempty(b) && return a
    isempty(a) && return b
    out = copy(a)
    for (k, v) in b
        @debug "merging source context" k
        out[k] = v
    end
    return out
end

# Union of two declared-covariance contexts, same rationale as
# `_merge_sources`.
function _merge_cov(a::_Cov, b::_Cov)
    isempty(b) && return a
    isempty(a) && return b
    out = copy(a)
    for (k, v) in b
        out[k] = v
    end
    return out
end

# Combined standard uncertainty as the quadratic form over the source
# covariance structure.
#
# With independent sources this is JCGM 100:2008 §5.1.2 equation (10);
# with declared covariances the cross terms of §5.2.2 equation (13)
# appear. The two GUM formulas are two regimes of this one expression,
# which is the point of M11.
#
# Traces REQ-204, REQ-205.
# c² when it is a non-negative integer constant, `nothing` otherwise.
#
# Two shapes matter in practice. A literal sensitivity comes from an
# operator that states its own coefficient — ±1 for a sum or a
# difference, the other operand for a product by a constant. A
# `ifelse(signbit(x), -1, 1)` comes from differentiating `abs`: the
# branch is genuine in the estimate and irrelevant in the variance,
# since both arms square to the same value.
function _constant_square(t::Symbolics.Num)
    v = Symbolics.value(t)
    v isa Integer && return v * v
    if v isa Real && !(v isa Symbolics.Num)
        sq = v * v
        isinteger(sq) && return Int(sq)
        return nothing
    end

    v isa Symbolics.SymbolicUtils.BasicSymbolic || return nothing
    Symbolics.SymbolicUtils.iscall(v) || return nothing
    Symbolics.SymbolicUtils.operation(v) === ifelse || return nothing

    args = Symbolics.SymbolicUtils.arguments(v)
    length(args) == 3 || return nothing
    a, b = Symbolics.value(args[2]), Symbolics.value(args[3])
    (a isa Real && b isa Real) || return nothing
    (isinteger(a) && isinteger(b)) || return nothing
    a * a == b * b || return nothing
    return Int(a * a)
end

function _combined_uncertainty(terms::_Terms, sources::_Sources, cov::_Cov)
    isempty(terms) && return Symbolics.Num(0)

    # Deterministic order: a Dict iterates arbitrarily, and an
    # arbitrary order would make the emitted expression vary between
    # runs, breaking symbolic comparison.
    ids = sort!(collect(keys(terms)); by = s -> s.id)

    # A source of zero standard uncertainty is not a source of
    # uncertainty. `_wrap` mints one for every constant operand, so
    # `2 * m` and `0 - m` carry two sources where the model has one,
    # and the variance would read `sqrt(0·0² + c²u²)`. Dropping them
    # is what lets the single-source form below apply at all.
    filter!(sid -> !isequal(Symbolics.value(sources[sid].u), 0), ids)
    isempty(ids) && return Symbolics.Num(0)

    # Single source with a constant sensitivity: return |c|·u rather
    # than sqrt(c²u²). Symbolics cannot make that reduction itself —
    # it needs u ≥ 0, and there is no way to state it (upstream-bugs.md
    # UB-003) — but `u` is a standard uncertainty, so non-negative by
    # construction (REQ-005). The package knows what the CAS cannot be
    # told.
    #
    # Restricting this to c = 1, as M11 did, meant every negation
    # reported sqrt(σ²) where the answer is σ.
    if length(ids) == 1 && isempty(cov)
        sid = ids[1]
        k = _constant_square(terms[sid])
        if k !== nothing
            isequal(k, 1) && return sources[sid].u
            r = isqrt(k)
            r * r == k && return r * sources[sid].u
        end
    end

    variance = Symbolics.Num(0)
    for sid in ids
        variance = variance + (terms[sid])^2 * (sources[sid].u)^2
    end
    for i in eachindex(ids), j in eachindex(ids)
        i < j || continue
        a, b = ids[i], ids[j]
        c = get(cov, (a, b), get(cov, (b, a), nothing))
        c === nothing && continue
        variance = variance + 2 * terms[a] * terms[b] * c
    end
    return sqrt(variance)
end

# Chain rule — the single propagation path (M11 phase 2).
#
# `z = f(x, y, …)` has, for every source `s` appearing in any operand,
# `z.terms[s] = Σ ∂f/∂xᵢ · xᵢ.terms[s]`. This is JCGM 100:2008 §5.1.3:
# the sensitivity coefficients are the partial derivatives, and the
# variance is formed from them afterwards, never before.
#
# Doing it in this order is what makes `x - x` exact: the two operands
# contribute +1 and -1 for the *same* source, which cancel. Squaring
# each operand's uncertainty first — the pre-M11 formula-by-formula
# path — destroys that information irrecoverably.
#
# Traces REQ-201, REQ-202, REQ-204, REQ-205.
function _chain(val::Symbolics.Num, parts...)
    terms = _Terms()
    sources = _Sources()
    cov = _Cov()

    # Keep each contribution separately: their sum losing every
    # significant digit is the signature of an exact cancellation, and
    # it cannot be recognised from the sum alone.
    contribs = Dict{SourceId,Vector{Symbolics.Num}}()
    for (m, c) in parts
        for (sid, t) in terms_of(m)
            push!(get!(contribs, sid, Symbolics.Num[]), c * t)
        end
        sources = _merge_sources(sources, sources_of(m))
        cov = _merge_cov(cov, cov_of(m))
    end
    for (sid, cs) in contribs
        _add_term!(terms, sid, sum(cs))
    end

    # Simplify each sensitivity, then drop the ones that vanished.
    # `1 + (-1)` is not syntactically zero, so without this step a
    # cancelled source would survive as a zero-weighted term and the
    # emitted uncertainty would read `sqrt(0·u²)` instead of `0`.
    #
    # A simplified zero is not taken at face value. Simplification is a
    # presentation step here, and it is never allowed to delete a
    # source: `Symbolics.simplify` returns a numerically wrong result
    # for some expressions of the shape `a·(b + c·x)/sqrt(d + x)`, zero
    # among them (`upstream-bugs.md` UB-007), and honouring that would
    # drop a real contribution and understate `u_c` with no warning.
    # So a term is deleted only once the *unsimplified* sensitivity is
    # confirmed to vanish; when the two disagree, the unsimplified form
    # is kept — uglier, and right.
    for (sid, t) in terms
        simplified = _simplify_for_report(t)
        if isequal(Symbolics.value(simplified), 0)
            if _vanishes(t, contribs[sid])
                delete!(terms, sid)
            else
                terms[sid] = t
            end
        elseif _is_round_off(simplified, contribs[sid])
            delete!(terms, sid)
        else
            terms[sid] = simplified
        end
    end

    # Descriptors and declared covariances are kept even for sources
    # not currently referenced by `terms`.
    #
    # Pruning them to `terms` looked tidy and was wrong: in
    # `(v / i) * cos(p)` the division drops φ, so a covariance
    # involving φ would be discarded before `cos(p)` brings it back.
    # JCGM 100:2008 §H.2 — three mutually correlated inputs feeding
    # three outputs — loses two of its three covariances that way, and
    # silently reports the wrong combined uncertainty. A declared
    # correlation is a hypothesis about the measurement model; it must
    # survive the intermediate steps of an expression.
    return SymbolicMeasurement(val, terms, sources, cov)
end

# Is `total` merely the round-off left over from contributions that
# cancel exactly?
#
# With numeric estimates, `x / x` computes its two opposite
# sensitivities as 1/x and x/x². For x = 0.1 those are 10.0 and
# 9.999999999999998, because 0.01 is not representable: the difference
# is 1.8e-15 of accumulated round-off, not uncertainty. Reporting it
# would put a spurious ±1e-16 on an exactly-zero result — the very
# defect M11 exists to remove, resurfacing through arithmetic instead
# of through operand identity.
#
# The test is relative and only fires when everything involved is
# numeric: a sum that has lost every significant digit of its own
# terms. A genuinely small uncertainty is untouched, because it is
# small in absolute terms while its contributions are equally small.
# Does a sensitivity really vanish?
#
# Asked only when `simplify` has already claimed the term is zero, to
# decide whether that claim can be trusted. It cannot always be:
# `Symbolics.simplify` mis-rewrites some expressions carrying an outer
# numeric factor over a square root, and a wrong zero here would delete
# an uncertainty source outright (`upstream-bugs.md` UB-007).
#
# The check is numeric and relative: the unsimplified sensitivity is
# evaluated against the scale of the contributions it was summed from,
# at several arbitrary-but-deterministic points. Anything that cannot
# be evaluated — a variable outside the function's domain, a division
# by zero, a build failure — returns `false`, keeping the term. The
# bias is deliberate: reporting a source that cancels costs a `0·u`
# row in the budget, while dropping one that does not understates the
# combined uncertainty, and only one of those two is a metrological
# error.
function _vanishes(raw, contributions)
    v = Symbolics.value(raw)
    v isa Number && return iszero(v)

    vars = Set{Any}()
    for e in (raw, contributions...)
        union!(vars, Symbolics.get_variables(Symbolics.value(e)))
    end
    vs = collect(vars)
    isempty(vs) && return false

    f, cfs = try
        (
            Symbolics.build_function(raw, vs...; expression = Val{false}),
            [
                Symbolics.build_function(c, vs...; expression = Val{false})
                for c in contributions
            ],
        )
    catch
        return false
    end

    # Irrational-ish spacing, so the sample points cannot accidentally
    # sit on a root of the expression being tested.
    for trial in 1:3
        pts = [0.31 + 0.6180339887498949 * (i + trial) for i in eachindex(vs)]
        y, scale = try
            (float(f(pts...)), maximum(abs(float(cf(pts...))) for cf in cfs))
        catch
            return false
        end
        (isfinite(y) && isfinite(scale)) || return false
        scale == 0 && return false
        abs(y) > 1e-9 * scale && return false
    end
    return true
end

function _is_round_off(total, contributions)
    tv = Symbolics.value(total)
    tv isa Number || return false
    scale = 0.0
    for c in contributions
        cv = Symbolics.value(c)
        cv isa Number || return false
        scale = max(scale, abs(float(cv)))
    end
    scale == 0 && return false
    return abs(float(tv)) <= 8 * eps(Float64) * scale
end
