# Dimensional checking — M12.
#
# Opt-in and non-throwing by design: `check_units` returns a report.
# Construction never raises on a unit mismatch, so a user exploring a
# model is not halted mid-derivation by a typo. This replaces the M8
# Unitful extension's construction-time `DimensionError`.
#
# Units are an ANNOTATION OF THE SYMBOL, never a value inside the
# expression — the same choice `ModelingToolkit` makes
# (`src/systems/unit_check.jl` reads `getmetadata(v, VariableUnit)`).
# Putting quantities inside `Symbolics.Num` would drag units through
# every simplification and derivative; keeping them beside it leaves
# the symbolic pipeline untouched.
#
# Traces REQ-210 – REQ-214. Supersedes REQ-100 – REQ-102, the
# construction-time Unitful guard this replaces.

"""
    UnitFinding

One dimensional inconsistency: `what` names the offending
subexpression, `why` explains the rule it breaks, and `details`
carries the conflicting annotations.
"""
struct UnitFinding
    what::String
    why::String
    details::String
end

"""
    UnitReport

Result of [`check_units`](@ref): the findings, in the order they were
encountered. An empty report means the expression is dimensionally
sound under the supplied annotations.

A report is data, not an exception — inspect it, print it, or ignore
it. Nothing in the package changes behaviour based on its contents.

The findings it carries are the three cases dimensional equality
cannot decide on its own: affine scales, where an uncertainty in °C is
a kelvin interval because a dispersion has no origin (JCGM 100:2008
§4.3.1); scaled dimensionless quantities (%, ppm, dB); and
non-fungible homonyms, a quantity not being defined by its dimension
(VIM §1.1).

Traces REQ-212.
"""
struct UnitReport
    findings::Vector{UnitFinding}
end

UnitReport() = UnitReport(UnitFinding[])

"""
    is_consistent(r::UnitReport) -> Bool

`true` when the report holds no findings.
"""
is_consistent(r::UnitReport) = isempty(r.findings)

function Base.show(io::IO, r::UnitReport)
    if isempty(r.findings)
        print(io, "UnitReport: consistent")
        return
    end
    print(io, "UnitReport: ", length(r.findings), " finding(s)")
    for f in r.findings
        print(io, "\n  • ", f.what, " — ", f.why)
        isempty(f.details) || print(io, " (", f.details, ")")
    end
end

# --- Annotations beyond a bare dimension -----------------------------
#
# The three cases a naive dimension check gets wrong. Each exists
# because dimensional equality is necessary but not sufficient to
# decide that two quantities may be combined.

"""
    Affine(base, name, offset)

An affine-scale quantity such as °C or °F: its zero is conventional,
so absolute values do **not** add, and only differences are proper
intervals on `base`.

`20 °C + 20 °C` is not `40 °C`, yet both sides carry dimension Θ and a
dimension check passes it. An uncertainty stated in °C is a kelvin
interval, never an absolute temperature (JCGM 100:2008 §4.3.1: `u` is
a dispersion, and a dispersion has no origin).

Traces REQ-214.
"""
struct Affine
    base::Any
    name::Symbol
    offset::Float64
end

"""
    interval_unit(a::Affine)

The unit a *difference* of two `a` values carries — the one an
uncertainty in `a` is actually expressed in.
"""
interval_unit(a::Affine) = a.base

"""
    Scaled(name, factor; logarithmic = false)

A dimensionless ratio carrying a scale: `%`, `ppm`, `dB`.

All are dimensionless and none is interchangeable with another, which
dimensional equality cannot see. `dB` is additionally logarithmic, so
it does not even combine additively the way `%` and `ppm` do.

Traces REQ-214.
"""
struct Scaled
    name::Symbol
    factor::Union{Float64,Nothing}
    logarithmic::Bool
end

Scaled(name::Symbol, factor; logarithmic::Bool = false) =
    Scaled(name, factor === nothing ? nothing : Float64(factor), logarithmic)

"""
    Kind(unit, kind)

A quantity distinguished by more than its dimension.

Torque and energy are both N·m; activity and frequency are both s⁻¹.
Adding a torque to an energy is a modelling error that dimensional
analysis alone declares valid. Per VIM §1.1 a quantity is not defined
by its dimension, and `Kind` records the part the dimension omits.

Traces REQ-214.
"""
struct Kind
    unit::Any
    kind::Symbol
end

# `check_units` is a generic fallback so the DynamicQuantities
# extension ADDS a more specific method rather than overwriting this
# one — method overwriting during precompilation is a hard error on
# Julia >= 1.12. Same pattern as `src/mtk_stubs.jl` and
# `src/latex_stub.jl`.

"""
    check_units(expr, units::AbstractDict) -> UnitReport

Check an expression, or a [`SymbolicMeasurement`](@ref), for
dimensional consistency under the supplied symbol annotations.

Returns a report; **never throws** on an inconsistency. Annotations
may be `DynamicQuantities` quantities or one of [`Affine`](@ref),
[`Scaled`](@ref), [`Kind`](@ref) for the cases a bare dimension cannot
express.

Requires `DynamicQuantities.jl` to be loaded.

Implements the methodology of JCGM 100:2008 §4.1 read with VIM §1.1.
Traces REQ-211, REQ-212, REQ-213, REQ-214.
"""
function check_units(args...; kwargs...)
    throw(
        ArgumentError(
            "check_units requires `DynamicQuantities.jl`. Add " *
            "`using DynamicQuantities` to your session to activate the " *
            "M12 `SymbolicUncertaintiesDynamicQuantitiesExt` extension.",
        ),
    )
end

"""
    evaluate(m::SymbolicMeasurement, values::AbstractDict) -> NamedTuple

Substitute unit-carrying values into a
[`SymbolicMeasurement`](@ref) and return
`(val = ..., err = ...)` as quantities.

The unit of the result is **derived from the model**, by the same
dimensional walk [`check_units`](@ref) performs, rather than written
out by the caller. A worked example therefore cannot claim a unit its
own model does not produce — the failure a hand-written `# ohms`
comment cannot catch.

# Arguments

- `m` — the measurement to evaluate.
- `values` — one entry per symbol in the model. Values may be
  `DynamicQuantities` quantities or plain `Real`s, the latter read as
  dimensionless.

# Returns

A `NamedTuple` with `val` and `err`. Both carry the dimension the
model gives them, derived independently, so a `u_c` that has drifted
from the dimension of its own measurand (JCGM 100:2008 §4.3.1) is
visible in the result.

Quantities built with `u"..."` reduce to SI base dimensions; those
built with `us"..."` keep their symbolic form, which usually reads
better. The choice is the caller's and is preserved.

# Errors

- A variable left without a value → `ArgumentError`. There would be
  no number to carry a unit, and returning a partly symbolic result
  would defeat the call; use `Symbolics.substitute` for partial
  substitution.
- A unit the walk cannot determine → `ArgumentError`.

A dimensional inconsistency is **warned** about, not thrown, and the
result is still returned — the same posture as `check_units`, which
should be called directly for the full report.

Requires `DynamicQuantities.jl` to be loaded.

Traces REQ-238.
"""
function evaluate(args...; kwargs...)
    throw(
        ArgumentError(
            "evaluate requires `DynamicQuantities.jl`. Add " *
            "`using DynamicQuantities` to your session to activate the " *
            "`SymbolicUncertaintiesDynamicQuantitiesExt` extension.",
        ),
    )
end
