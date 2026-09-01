"""
    SymbolicMeasurement

A measurand recorded in the canonical JCGM 100:2008
`estimate ± standard uncertainty` form, using
[`Symbolics.jl`](https://github.com/JuliaSymbolics/Symbolics.jl)
expressions throughout.

Implements the methodology of JCGM 100:2008 §4.1 (estimate of the
measurand), §5.1 (combined standard uncertainty), and §G.4 (effective
degrees of freedom).

Since M11 the quantity records **which independent sources it derives
from and with what sensitivity**, rather than a bare uncertainty
number. Every combined uncertainty, sensitivity coefficient, budget
and covariance is derived from that structure.

Fields:

- `val::Symbolics.Num` — symbolic expression for the estimate of the
  measurand (JCGM 100:2008 §4.1).
- `terms::Dict{SourceId,Symbolics.Num}` — `∂val/∂source` for each
  independent source the quantity depends on (JCGM 100:2008 §5.1.3,
  sensitivity coefficients `cᵢ`).
- `sources::Dict{SourceId,Source}` — descriptor of each source: its
  standard uncertainty, optional degrees of freedom, display name.
  Carried by the quantity rather than held in module state, so that
  `Symbolics.substitute` stays local (REQ-120, REQ-123).
- `cov::Dict{Tuple{SourceId,SourceId},Symbolics.Num}` — declared
  covariances between sources (JCGM 100:2008 §5.2.2). Empty by
  default: sources are independent unless declared otherwise.

Properties:

- `m.err` — combined standard uncertainty `u_c`, **computed** from the
  fields above (JCGM 100:2008 §5.1), no longer a stored field.
- `m.dof` — effective degrees of freedom `ν_eff` (§G.4).

`SymbolicMeasurement` is deliberately **not** a subtype of `Real` or
`AbstractFloat` — this avoids implicit promotion loops with the Julia
numeric tower and protects the symbolic uncertainty information from
being silently dropped during generic numeric code.

Traces REQ-001, REQ-002, REQ-006, REQ-200.
"""
struct SymbolicMeasurement
    val::Symbolics.Num
    terms::Dict{SourceId,Symbolics.Num}
    sources::Dict{SourceId,Source}
    cov::Dict{Tuple{SourceId,SourceId},Symbolics.Num}
end

"""
    SymbolicMeasurement(val, err, dof)

Historical positional constructor, kept working through M11 phase 1.

It mints **one opaque source** of standard uncertainty `err` and
sensitivity 1, so the 21 pre-M11 construction sites keep behaving
exactly as before while the propagation paths migrate one at a time.
Phase 2 replaces these opaque sources with the real chain rule, and
that is what flips `x - x` to `0 ± 0`.

Traces REQ-002.
"""
function SymbolicMeasurement(
    val::Symbolics.Num,
    err::Symbolics.Num,
    dof::Union{Symbolics.Num,Nothing},
)
    sid = _fresh_source_id()
    return SymbolicMeasurement(
        val,
        _Terms(sid => Symbolics.Num(1)),
        _Sources(
            sid => Source(
                err,
                dof,
                _source_name(_input_variable(val)),
                _input_variable(val),
            ),
        ),
        _Cov(),
    )
end

# `err` and `dof` are derived from the source structure, not stored.
# Reads of `m.err` across src/, ext/, test/ and docs/ keep working.
function Base.getproperty(m::SymbolicMeasurement, s::Symbol)
    if s === :err
        return _combined_uncertainty(
            getfield(m, :terms),
            getfield(m, :sources),
            getfield(m, :cov),
        )
    elseif s === :dof
        return _effective_dof(m)
    end
    return getfield(m, s)
end

Base.propertynames(::SymbolicMeasurement) =
    (:val, :terms, :sources, :cov, :err, :dof)

# Degrees of freedom carried by the quantity.
#
# Phase 1 keeps the pre-M11 semantics: every measurement still has
# exactly one source, so this is that source's `dof`. REQ-208
# (deriving `ν_eff` by Welch-Satterthwaite from the per-source
# contributions) lands in phase 4, once the operators actually produce
# multi-source quantities.
#
# Traces REQ-208.
function _effective_dof(m::SymbolicMeasurement)
    terms = getfield(m, :terms)
    srcs = getfield(m, :sources)
    isempty(terms) && return nothing

    ids = sort!(collect(keys(terms)); by = s -> s.id)

    # One source: its own dof, unchanged.
    length(ids) == 1 && return srcs[ids[1]].dof

    # Several: Welch-Satterthwaite over the per-source contributions
    # (JCGM 100:2008 §G.4 eq. G.2b). Undefined unless every
    # contributing source carries degrees of freedom.
    any(sid -> srcs[sid].dof === nothing, ids) && return nothing

    contributions =
        [_simplify_for_report(abs(terms[sid]) * srcs[sid].u) for sid in ids]
    dofs = [srcs[sid].dof for sid in ids]
    return _simplify_for_report(welch_satterthwaite(contributions, dofs))
end

"""
    terms_of(m) -> Dict{SourceId,Symbolics.Num}

Sensitivity of `m` to each independent source it derives from.
"""
terms_of(m::SymbolicMeasurement) = getfield(m, :terms)

"""
    sources_of(m) -> Dict{SourceId,Source}

Descriptors of the independent sources `m` derives from.
"""
sources_of(m::SymbolicMeasurement) = getfield(m, :sources)

"""
    cov_of(m) -> Dict{Tuple{SourceId,SourceId},Symbolics.Num}

Covariances declared between the sources of `m`.
"""
cov_of(m::SymbolicMeasurement) = getfield(m, :cov)

"""
    SymbolicMeasurement(val::Symbolics.Num, err::Symbolics.Num)

Build a [`SymbolicMeasurement`](@ref) from two `Symbolics.Num` operands,
leaving the effective degrees of freedom unset (`dof = nothing`).

Implements the methodology of JCGM 100:2008 §4.1 + §5.1. Traces
REQ-002, REQ-003.
"""
SymbolicMeasurement(val::Symbolics.Num, err::Symbolics.Num) =
    SymbolicMeasurement(val, err, nothing)

"""
    SymbolicMeasurement(val::Number, err::Number)

Build a [`SymbolicMeasurement`](@ref) from two plain numeric values,
promoting both to `Symbolics.Num` literals so that the full symbolic
pipeline applies uniformly to downstream operations.

Raises `ArgumentError` if `err` is a negative `Real` — the standard
uncertainty must be non-negative per JCGM 100:2008 §4.3.1.

Implements the methodology of JCGM 100:2008 §4.3.1. Traces REQ-004,
REQ-005.
"""
function SymbolicMeasurement(val::Number, err::Number)
    # The negativity guard fires only for concrete numeric values.
    # `Symbolics.Num` happens to be `<: Real` for compatibility with
    # the Julia numeric tower, but its `<` returns a symbolic boolean
    # (not a Julia `Bool`), so we must explicitly exclude it from the
    # check — its sign is not knowable at construction time.
    if err isa Real && !(err isa Symbolics.Num) && err < zero(err)
        throw(
            ArgumentError(
                "standard uncertainty must be non-negative (GUM §4.3.1)",
            ),
        )
    end
    return SymbolicMeasurement(Symbolics.Num(val), Symbolics.Num(err), nothing)
end
