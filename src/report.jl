# Reporting a measurement result — JCGM 100:2008 §7.
#
# The package's `±` display follows the Julia ecosystem convention and
# is NOT what the GUM asks a certificate to say: §7.2.2 deliberately
# avoids the glyph, because `±` is historically read as an expanded
# uncertainty `y ± U` (§6.2) and a combined standard uncertainty is a
# different quantity. The documentation has told users to "use one of
# the four §7.2.2 textual forms" since M1 without giving them a way to
# produce one. This is that way.
#
# Traces REQ-239.

# §7.2.6 — the number of digits.
#
# "It usually suffices to quote u_c(y) and U ... to at most two
# significant digits", and the estimate is then rounded to that same
# last significant place. Reporting an estimate to more digits than
# its uncertainty supports states a precision the measurement does not
# have; reporting it to fewer throws away information that was paid
# for.
#
# Returns `(y_rounded, u_rounded, place)` where `place` is the decimal
# exponent of the last significant digit — `-5` meaning five decimals.
function _round_to_uncertainty(y::Real, u::Real, digits::Integer)
    (isfinite(y) && isfinite(u)) ||
        throw(ArgumentError("report: value and uncertainty must be finite"))
    u < 0 && throw(
        ArgumentError(
            "report: standard uncertainty must be non-negative (GUM §4.3.1)",
        ),
    )
    u == 0 && return (float(y), 0.0, 0)

    place = floor(Int, log10(abs(u))) - (digits - 1)
    ur = round(float(u); digits = -place)

    # Rounding can carry into a new decade — 0.0999 becomes 0.10 — and
    # the significant place moves with it. One correction suffices,
    # since the second rounding cannot carry again.
    place2 = floor(Int, log10(abs(ur))) - (digits - 1)
    if place2 != place
        place = place2
        ur = round(float(u); digits = -place)
    end

    return (round(float(y); digits = -place), ur, place)
end

# Fixed-point rendering at a given decimal place. Trailing zeros are
# significant in a reported result, so this cannot go through
# `string(round(...))`, which drops them.
function _fixed(x::Real, place::Integer)
    place >= 0 && return string(round(Int, x))
    return Printf.format(Printf.Format("%.$(-place)f"), x)
end

"""
    UncertaintyReport

A measurement result rendered in the textual forms JCGM 100:2008 §7.2
prescribes. Produced by [`report`](@ref); printing it shows every
form.

# Fields

- `symbol` — the name of the measurand as it appears in the text.
- `value`, `uncertainty` — the rounded estimate and combined standard
  uncertainty, in the unit of `unit`.
- `unit` — the unit as it is written, `""` for a dimensionless result.
- `digits` — significant digits kept on `u_c` (§7.2.6).
- `forms` — the four §7.2.2 renderings, in the standard's own order.
- `expanded` — the §7.2.4 statement, or `nothing` when no coverage
  factor was supplied. There is no expanded uncertainty without a
  stated `k`.

Traces REQ-239.
"""
struct UncertaintyReport
    symbol::String
    value::Float64
    uncertainty::Float64
    unit::String
    digits::Int
    forms::NTuple{4,String}
    expanded::Union{String,Nothing}
end

_with_unit(s::AbstractString, unit::AbstractString) =
    isempty(unit) ? s : "$s $unit"

"""
    report(y, u; symbol, unit, digits, k, coverage_probability, dof)
    report(m::SymbolicMeasurement; kwargs...)

Render a measurement result in the textual forms of
JCGM 100:2008 §7.2, returning an [`UncertaintyReport`](@ref).

`±` is not one of them by default. §7.2.2 avoids the glyph because it
is read as an expanded uncertainty `y ± U`; the fourth form uses it
only with the explicit statement that the number is `u_c`.

# Arguments

- `y`, `u` — the estimate and its combined standard uncertainty, as
  plain reals. With `DynamicQuantities` loaded, `report(m, values)`
  takes a measurement and unit-carrying values instead, and derives
  both the numbers and the unit from the model.
- `symbol` (keyword, default `"y"`) — the measurand's name.
- `unit` (keyword, default `""`) — the unit, written as it should
  appear.
- `digits` (keyword, default `2`) — significant digits kept on `u_c`,
  per §7.2.6. The estimate is rounded to the same last place.
- `k`, `coverage_probability`, `dof` (keywords, default `nothing`) —
  supply `k` to also produce the §7.2.4 expanded-uncertainty
  statement, with `U = k·u_c`. The other two are named in the text
  when given; §7.2.4 asks for both, since `± U` without them is the
  ambiguity §7.2.2 warns about.

# Example

The GUM's own worked example, a 100 g mass standard:

```jldoctest; setup = :(using SymbolicUncertainties)
julia> r = report(100.02147, 0.00035; symbol = "m_S", unit = "g");

julia> r.forms[2]
"m_S = 100.02147(35) g"
```

Traces REQ-239. Implements JCGM 100:2008 §7.2.2, §7.2.4 and §7.2.6.
"""
function report(
    y::Real,
    u::Real;
    symbol::AbstractString = "y",
    unit::AbstractString = "",
    digits::Integer = 2,
    k::Union{Real,Nothing} = nothing,
    coverage_probability::Union{Real,Nothing} = nothing,
    dof::Union{Real,Nothing} = nothing,
)
    digits >= 1 || throw(ArgumentError("report: `digits` must be at least 1"))

    yr, ur, place = _round_to_uncertainty(y, u, digits)
    ys, us = _fixed(yr, place), _fixed(ur, place)

    # §7.2.2 form 2 quotes u_c "referred to the corresponding last
    # digits of the quoted result" — an integer in units of the last
    # place, not a decimal.
    paren = ur == 0 ? "0" : string(round(Int, ur / 10.0^place))

    forms = (
        _with_unit("$symbol = $ys", unit) *
        " with u_c = " *
        _with_unit(us, unit),
        _with_unit("$symbol = $ys($paren)", unit),
        _with_unit("$symbol = $ys($us)", unit),
        _with_unit("$symbol = ($ys ± $us)", unit),
    )

    expanded = nothing
    if k !== nothing
        # U is rounded on its own significant digits, and the estimate
        # follows U rather than u_c — the expanded statement is a
        # different result, not an annotation of the standard one.
        Uy, Ur, Uplace = _round_to_uncertainty(y, k * u, digits)
        basis =
            dof === nothing ? "" :
            " based on the t-distribution for ν = $(_fmt_dof(dof)) degrees of freedom"
        confidence =
            coverage_probability === nothing ? "" :
            ", and defines an interval estimated to have a level of confidence of " *
            "$(_fmt_percent(coverage_probability)) percent"
        expanded =
            _with_unit(
                "$symbol = ($(_fixed(Uy, Uplace)) ± $(_fixed(Ur, Uplace)))",
                unit,
            ) *
            ", where the number following the symbol ± is the numerical value of " *
            "an expanded uncertainty U = k·u_c, with U determined from a combined " *
            "standard uncertainty u_c = " *
            _with_unit(us, unit) *
            " and a coverage factor k = $(_fmt_k(k))" *
            basis *
            confidence *
            "."
    end

    return UncertaintyReport(symbol, yr, ur, unit, Int(digits), forms, expanded)
end

# A trailing `.0` in a certificate reads as a claim about precision
# that none of these three numbers is making.
_trim(x::Real) = isinteger(x) ? string(Int(x)) : string(x)
_fmt_dof(ν::Real) = _trim(round(float(ν); digits = 1))
_fmt_k(k::Real) = _trim(round(float(k); digits = 2))
_fmt_percent(p::Real) =
    _trim(round(p <= 1 ? 100 * float(p) : float(p); digits = 2))

# Deliberately typed `::Any` on the second argument so the
# DynamicQuantities extension can ADD an `::AbstractDict` method rather
# than overwrite this one — method overwriting during precompilation is
# a hard error on Julia >= 1.12. Same pattern as `check_units`.
function report(::SymbolicMeasurement, ::Any; kwargs...)
    throw(
        ArgumentError(
            "report(m, values) requires `DynamicQuantities.jl`, which is " *
            "what carries the units. Add `using DynamicQuantities`, or " *
            "call `report(m)` on an already-substituted measurement.",
        ),
    )
end

function report(m::SymbolicMeasurement; kwargs...)
    v = Symbolics.value(m.val)
    e = Symbolics.value(m.err)
    (
        v isa Real &&
        !(v isa Symbolics.Num) &&
        e isa Real &&
        !(e isa Symbolics.Num)
    ) || throw(
        ArgumentError(
            "report: the measurement is still symbolic. Substitute values " *
            "first, or call `report(m, values)` with `DynamicQuantities` " *
            "loaded to keep the units.",
        ),
    )
    return report(float(v), float(e); kwargs...)
end

function Base.show(io::IO, ::MIME"text/plain", r::UncertaintyReport)
    println(io, "Measurement result — JCGM 100:2008 §7.2.2")
    for f in r.forms
        println(io, "  ", f)
    end
    if r.expanded !== nothing
        println(io)
        println(io, "Expanded uncertainty — §7.2.4")
        println(io, "  ", r.expanded)
    end
    return nothing
end

Base.show(io::IO, r::UncertaintyReport) = print(io, r.forms[2])
