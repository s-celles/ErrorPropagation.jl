module SymbolicUncertaintiesDynamicQuantitiesExt

# M12 — dimensional checking on DynamicQuantities.
#
# Walks the expression tree assigning a dimensional annotation to each
# node and reporting the operations that cannot hold. Opt-in and
# non-throwing: the walk collects findings and returns them.
#
# Annotations are read from a caller-supplied dictionary rather than
# injected into `Symbolics.Num`, so the symbolic pipeline never sees a
# unit — the same separation ModelingToolkit keeps by holding units in
# variable metadata.

import SymbolicUncertainties
import SymbolicUncertainties:
    UnitFinding, UnitReport, Affine, Scaled, Kind, SymbolicMeasurement
import Symbolics
import DynamicQuantities as DQ

# An annotation is one of: a DQ quantity, Affine, Scaled, Kind, or
# `nothing` for "unknown / unconstrained".
const Annot = Any

# Symbolics normalises `a - b` into `+(-b, a)`, so the `-` branch is
# never reached for a binary subtraction. A negated affine is tagged
# on the way through `*` and recognised in `+`, which is the only
# place a difference of affine quantities can be identified.
struct NegAffine
    a::Affine
end

# Dimensions are compared in SI base form. `u"V"` carries base
# `Dimensions` while `us"V"` carries `SymbolicDimensions`, and the two
# are not directly comparable — comparing them raises rather than
# returning `false`. Expanding first lets a caller annotate a model in
# whichever notation reads better, which for a worked example is
# usually the symbolic one.
_basedim(x) = DQ.dimension(DQ.uexpand(x))
_dim(q) = _basedim(q)
_dim(k::Kind) = _basedim(k.unit)
_dim(a::Affine) = _basedim(a.base)
_dim(n::NegAffine) = _basedim(n.a.base)
_dim(::Scaled) = DQ.dimension(1.0)

_kind(k::Kind) = k.kind
_kind(::Any) = nothing

_scale(s::Scaled) = s.name
_scale(::Any) = nothing

_is_log(s::Scaled) = s.logarithmic
_is_log(::Any) = false

_show(a::Affine) = "affine($(a.name))"
_show(n::NegAffine) = "-affine($(n.a.name))"
_show(s::Scaled) = "scaled($(s.name))"
_show(k::Kind) = "$(k.kind) [$(_dim(k))]"
_show(q) = string(_dim(q))
_show(::Nothing) = "unannotated"

# Two annotations may be added only if every layer agrees: dimension,
# kind, scale, and linearity. Dimensional equality alone is necessary
# but never sufficient — that is the whole point of M12.
function _addable(a, b)
    a === nothing && return (true, "")
    b === nothing && return (true, "")

    if _is_log(a) != _is_log(b)
        return (false, "one operand is logarithmic and the other is not")
    end
    if _is_log(a) && _is_log(b) && _scale(a) !== _scale(b)
        return (false, "logarithmic scales differ")
    end
    if a isa Affine || b isa Affine || a isa NegAffine || b isa NegAffine
        return (
            false,
            "affine quantities do not add — only their differences are " *
            "intervals on the base unit",
        )
    end
    if _dim(a) != _dim(b)
        return (false, "dimensions differ")
    end
    if _scale(a) !== _scale(b)
        return (
            false,
            "dimensionless scales differ and are not interchangeable",
        )
    end
    if _kind(a) !== _kind(b)
        return (false, "same dimension but different kind of quantity")
    end
    return (true, "")
end

# Subtraction of two affine quantities is the one case that IS
# allowed, and it yields an interval on the base unit.
function _subtractable(a, b)
    if a isa Affine && b isa Affine
        if a.name === b.name
            return (true, "", a.base)
        end
        return (false, "affine scales differ", nothing)
    end
    ok, why = _addable(a, b)
    return (ok, why, ok ? (a === nothing ? b : a) : nothing)
end

mutable struct Walk
    units::AbstractDict
    findings::Vector{UnitFinding}
end

_add!(w, what, why, details) =
    push!(w.findings, UnitFinding(what, why, details))

function _annot(w::Walk, ex)
    v = Symbolics.value(ex)

    # A literal number is dimensionless.
    v isa Number && return DQ.Quantity(Float64(v))

    # A bare symbol: look it up.
    if !Symbolics.iscall(v)
        for (k, u) in w.units
            isequal(Symbolics.value(k), v) && return u
        end
        return nothing
    end

    op = Symbolics.operation(v)
    args = Symbolics.arguments(v)

    if op === (+)
        parts = [_annot(w, a) for a in args]

        # A difference of two affine quantities on the same scale is
        # the one affine combination that IS meaningful, and it yields
        # an interval on the base unit (JCGM 100:2008 §4.3.1).
        if length(parts) == 2
            p, q = parts
            if p isa NegAffine && q isa Affine && p.a.name === q.name
                return q.base
            elseif q isa NegAffine && p isa Affine && p.name === q.a.name
                return p.base
            end
        end

        acc = parts[1]
        for b in parts[2:end]
            ok, why = _addable(acc, b)
            ok || _add!(w, "+ in `$(v)`", why, "$(_show(acc)) vs $(_show(b))")
            acc = acc === nothing ? b : acc
        end
        return acc
    elseif op === (-)
        length(args) == 1 && return _annot(w, args[1])
        acc = _annot(w, args[1])
        for a in args[2:end]
            b = _annot(w, a)
            ok, why, res = _subtractable(acc, b)
            ok || _add!(w, "- in `$(v)`", why, "$(_show(acc)) vs $(_show(b))")
            acc = res
        end
        return acc
    elseif op === (*)
        # `-x` arrives as `(-1) * x`; tag a negated affine so the
        # enclosing `+` can recognise a difference.
        if length(args) == 2
            c = Symbolics.value(args[1])
            if c isa Number && c == -1
                inner = _annot(w, args[2])
                inner isa Affine && return NegAffine(inner)
            end
        end
        acc = _annot(w, args[1])
        for a in args[2:end]
            b = _annot(w, a)
            (acc === nothing || b === nothing) && (acc = nothing; continue)
            acc = _quantity_of(acc) * _quantity_of(b)
        end
        return acc
    elseif op === (/)
        a = _annot(w, args[1])
        b = _annot(w, args[2])
        (a === nothing || b === nothing) && return nothing
        return _quantity_of(a) / _quantity_of(b)
    elseif op === (^)
        a = _annot(w, args[1])
        a === nothing && return nothing
        e = Symbolics.value(args[2])
        e isa Number || return nothing
        return _quantity_of(a)^e
    elseif op === inv
        # `inv` is ALGEBRAIC — it inverts a dimension. Giac's
        # simplifier emits `inv(I)` where the default one emits `1/I`,
        # so leaving it to the transcendental branch made a correct
        # expression report four cascading findings, but only when the
        # Giac extension happened to be loaded.
        a = _annot(w, args[1])
        a === nothing && return nothing
        return inv(_quantity_of(a))
    elseif op === sqrt
        # sqrt, abs and cbrt are ALGEBRAIC: they transform a dimension
        # rather than requiring a dimensionless argument. Treating
        # them as transcendental made every combined uncertainty —
        # which is a sqrt by construction — report as dimensionless.
        a = _annot(w, args[1])
        a === nothing && return nothing
        return sqrt(_quantity_of(a))
    elseif op === abs
        return _annot(w, args[1])
    elseif op === cbrt
        a = _annot(w, args[1])
        a === nothing && return nothing
        return _quantity_of(a)^(1 // 3)
    else
        # Transcendental and every other unary function requires a
        # dimensionless argument (JCGM 100:2008 §5.1: the argument of
        # a non-algebraic function has no dimension to carry).
        for a in args
            b = _annot(w, a)
            b === nothing && continue
            if _dim(b) != DQ.dimension(1.0)
                _add!(
                    w,
                    "$(op) in `$(v)`",
                    "argument of a transcendental function must be " *
                    "dimensionless",
                    _show(b),
                )
            end
        end
        return DQ.Quantity(1.0)
    end
end

# Reduce an annotation to a plain quantity for arithmetic. An affine
# quantity contributes its base: a product involving °C is only
# meaningful on the interval scale.
_quantity_of(a::Affine) = a.base
_quantity_of(n::NegAffine) = n.a.base
_quantity_of(k::Kind) = k.unit
_quantity_of(::Scaled) = DQ.Quantity(1.0)
_quantity_of(q) = q

function SymbolicUncertainties.check_units(expr, units::AbstractDict)
    w = Walk(units, UnitFinding[])
    _annot(w, expr)
    return UnitReport(w.findings)
end

function SymbolicUncertainties.check_units(
    m::SymbolicMeasurement,
    units::AbstractDict,
)
    w = Walk(units, UnitFinding[])
    val_annot = _annot(w, m.val)

    # The uncertainty must carry the dimension of the estimate — the
    # single most common unit error in a budget, and one nothing else
    # catches, since u and y live in different fields.
    err_annot = _annot(w, m.err)
    if val_annot !== nothing && err_annot !== nothing
        ok, why = _addable(val_annot, err_annot)
        ok || _add!(
            w,
            "u_c vs estimate",
            "the combined uncertainty must carry the dimension of the " *
            "measurand (JCGM 100:2008 §4.3.1) — " *
            why,
            "$(_show(val_annot)) vs $(_show(err_annot))",
        )
    end
    return UnitReport(w.findings)
end

# Substituting values that carry units, and deriving the unit of the
# result instead of trusting the caller to state it.
#
# The estimate and the uncertainty are annotated SEPARATELY through
# the same walk `check_units` uses. Doing them together would assume
# what JCGM 100:2008 §4.3.1 requires and this package elsewhere
# checks: that `u_c` carries the dimension of its own measurand.

# The unit of a supplied value, as an annotation for the walk. A plain
# real is dimensionless, which is how a gain or a count is written.
_unit_annotation(q::DQ.AbstractQuantity) = oneunit(q)
_unit_annotation(x::Real) = DQ.Quantity(1.0)
_unit_annotation(x) = throw(
    ArgumentError(
        "evaluate: a value must be a `DynamicQuantities` quantity or a " *
        "plain `Real` (read as dimensionless); got `$(typeof(x))`.",
    ),
)

_strip_value(q::DQ.AbstractQuantity) = DQ.ustrip(q)
_strip_value(x::Real) = x

# The numeric value of a fully substituted field.
#
# `Symbolics.substitute` does not evaluate what it substitutes into
# (`upstream-bugs.md` UB-001), so a field that contains a `sqrt` comes
# back symbolic even once every variable has a value. Compiling it is
# what actually produces the number.
function _numeric_value(ex)
    v = Symbolics.value(ex)
    v isa Number && !(v isa Symbolics.Num) && return float(v)
    try
        return float(Symbolics.build_function(ex; expression = Val{false})())
    catch
        return nothing
    end
end

# Variables still present after substitution, as sorted names.
_leftover(ex) = sort!(
    String[string(x) for x in Symbolics.get_variables(Symbolics.value(ex))],
)

function SymbolicUncertainties.evaluate(
    m::SymbolicMeasurement,
    values::AbstractDict,
)
    numeric = Dict(k => _strip_value(v) for (k, v) in values)
    units = Dict(k => _unit_annotation(v) for (k, v) in values)

    sub = Symbolics.substitute(m, numeric)

    left = unique!(vcat(_leftover(sub.val), _leftover(sub.err)))
    isempty(left) || throw(
        ArgumentError(
            "evaluate: every variable needs a value, but these were " *
            "left unsubstituted: " *
            join(left, ", ") *
            ". Use `Symbolics.substitute` for partial substitution.",
        ),
    )

    val = _numeric_value(sub.val)
    err = _numeric_value(sub.err)
    (val === nothing || err === nothing) && throw(
        ArgumentError(
            "evaluate: the substituted " *
            (val === nothing ? "estimate" : "uncertainty") *
            " did not reduce to a number.",
        ),
    )

    w = Walk(units, UnitFinding[])
    val_unit = _annot(w, m.val)
    err_unit = _annot(w, m.err)

    for (name, u) in (("estimate", val_unit), ("uncertainty", err_unit))
        u === nothing && throw(
            ArgumentError(
                "evaluate: cannot determine the unit of the $(name). " *
                "Give every symbol a value, and see `check_units` for " *
                "the dimensional report.",
            ),
        )
    end

    isempty(w.findings) || @warn(
        "evaluate: the model is not dimensionally consistent; the " *
        "numbers below are still what it computes. Call `check_units` " *
        "for the full report.",
        findings = w.findings,
    )

    # `oneunit` strips the magnitude and keeps the unit. The walk is
    # built for dimension checking, where an annotation's numeric value
    # is irrelevant, so it lets literals through as their own value:
    # the annotation of `1/(2π·sqrt(L·C))` carries the `2π`. Multiplying
    # the substituted number by that would divide the answer by `2π`
    # and still look plausible.
    vu = oneunit(_quantity_of(val_unit))
    eu = oneunit(_quantity_of(err_unit))

    # `u_c` must carry the dimension of its measurand
    # (JCGM 100:2008 §4.3.1). When it does, report it in the estimate's
    # own unit: the walk reaches the uncertainty through squares and a
    # square root, which expands a symbolic unit to base dimensions, and
    # a budget whose two halves print in different notations is harder
    # to read for no gain. When the dimensions genuinely differ, each
    # keeps its own — that disagreement is exactly what the reader
    # needs to see.
    if DQ.dimension(DQ.uexpand(vu)) == DQ.dimension(DQ.uexpand(eu))
        scale = DQ.ustrip(DQ.uexpand(eu)) / DQ.ustrip(DQ.uexpand(vu))
        return (val = val * vu, err = (err * scale) * vu)
    end
    return (val = val * vu, err = err * eu)
end

# The coherent derived SI units, by the dimension each one has.
#
# The dimensional walk composes what it is given, so a resistance
# arrives as `A⁻¹ V` and a power as `A V`. Both are correct, and
# neither is what a calibration certificate writes.
#
# These thirteen dimensions are distinct from one another, so the
# lookup is unambiguous *as a dimension*. It is not unambiguous as a
# quantity: see the caveat on `_unit_string` below.
const _DERIVED_UNIT_NAMES = Dict(
    DQ.dimension(DQ.uexpand(DQ.us"Hz")) => "Hz",
    DQ.dimension(DQ.uexpand(DQ.us"N")) => "N",
    DQ.dimension(DQ.uexpand(DQ.us"Pa")) => "Pa",
    DQ.dimension(DQ.uexpand(DQ.us"J")) => "J",
    DQ.dimension(DQ.uexpand(DQ.us"W")) => "W",
    DQ.dimension(DQ.uexpand(DQ.us"C")) => "C",
    DQ.dimension(DQ.uexpand(DQ.us"V")) => "V",
    DQ.dimension(DQ.uexpand(DQ.us"F")) => "F",
    DQ.dimension(DQ.uexpand(DQ.us"Ω")) => "Ω",
    DQ.dimension(DQ.uexpand(DQ.us"S")) => "S",
    DQ.dimension(DQ.uexpand(DQ.us"Wb")) => "Wb",
    DQ.dimension(DQ.uexpand(DQ.us"T")) => "T",
    DQ.dimension(DQ.uexpand(DQ.us"H")) => "H",
)

# The unit as it should be written, taken off a quantity.
#
# A composed unit whose dimension is a named coherent SI unit is
# reported by that name — `A⁻¹ V` becomes `Ω`. Two conditions guard
# it, and both matter:
#
#   1. The unit must be the *coherent* one. `1 kΩ` expands to 1000
#      base units, and the reported number is then in kilohms; calling
#      it `Ω` would be wrong by a factor of a thousand. Only a unit
#      that expands to exactly 1 is renamed, so prefixed units keep
#      their own notation.
#
#   2. The name is right for the dimension, not necessarily for the
#      quantity. A dimension does not determine a kind of quantity
#      (VIM §1.1): torque and energy are both `m² kg s⁻²`, and this
#      table calls that `J`. A torque must therefore be reported with
#      an explicit `unit = "N m"`. The same caveat applies to `Hz`,
#      which shares `s⁻¹` with an activity in becquerel.
#
# The package already refuses to unify such homonyms in `check_units`,
# through `Kind`. It cannot make the same distinction here, because a
# product of two plain quantities carries no kind to propagate — which
# is precisely why the `unit` keyword exists.
function _unit_string(q)
    u = oneunit(q)
    expanded = DQ.uexpand(u)
    if DQ.ustrip(expanded) == 1
        name = get(_DERIVED_UNIT_NAMES, DQ.dimension(expanded), nothing)
        name === nothing || return name
    end
    parts = split(string(u), ' '; limit = 2)
    return length(parts) == 2 ? String(parts[2]) : ""
end

# Reporting a measurement whose unit comes from the model rather than
# from the caller. `evaluate` already puts the estimate and its
# uncertainty in the same unit, so one string serves both.
function SymbolicUncertainties.report(
    m::SymbolicMeasurement,
    values::AbstractDict;
    unit::Union{AbstractString,Nothing} = nothing,
    kwargs...,
)
    got = SymbolicUncertainties.evaluate(m, values)

    # Derived by default, and overridable: the walk composes units, so
    # a resistance comes out as `A⁻¹ V` rather than `Ω`. That is the
    # right answer and the wrong word for a certificate, and only the
    # person writing the certificate knows which name the accreditation
    # body expects.
    return SymbolicUncertainties.report(
        DQ.ustrip(got.val),
        DQ.ustrip(got.err);
        unit = unit === nothing ? _unit_string(got.val) : unit,
        kwargs...,
    )
end

# A certificate whose result — and whose unit — come from the model.
# The reporting keywords travel through `report`, which is where they
# belong; only the certificate's own clauses are peeled off here.
function SymbolicUncertainties.certificate(
    m::SymbolicMeasurement,
    values::AbstractDict;
    symbol::AbstractString = "y",
    unit::Union{AbstractString,Nothing} = nothing,
    digits::Integer = 2,
    k = nothing,
    coverage_probability = nothing,
    dof = nothing,
    kwargs...,
)
    result = SymbolicUncertainties.report(
        m,
        values;
        symbol = symbol,
        unit = unit,
        digits = digits,
        k = k,
        coverage_probability = coverage_probability,
        dof = dof,
    )
    return SymbolicUncertainties.certificate(result; kwargs...)
end

end
