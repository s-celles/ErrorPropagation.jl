# Sixteen elementary mathematical functions overloaded for a single
# `SymbolicMeasurement` argument. Each overload propagates uncertainty
# via the standard sensitivity-coefficient formula
#
#     u(f(x)) = |∂f/∂x| · u(x)
#
# implementing the single-input specialisation of JCGM 100:2008 §5.1.2
# equation (10). The partial derivative is obtained from
# `Symbolics.derivative` via the `_safe_derivative` helper from
# `differentiation.jl`, which detects the "Symbolics cannot find a
# closed form" failure case and signals it via `nothing`.
#
# Traces REQ-020.

function _propagate_unary(f, m::SymbolicMeasurement)
    val_expr = f(m.val)
    c = _safe_derivative(val_expr, m.val)
    if c === nothing
        throw(
            ArgumentError(
                "cannot compute closed-form derivative for `$(nameof(f))` " *
                "on a SymbolicMeasurement. Use `apply($(nameof(f)), m; " *
                "derivative = ...)` to provide one explicitly.",
            ),
        )
    end
    # One chain-rule application: the sensitivity is ∂f/∂x, and the
    # linear form carries it into whatever sources `m` derives from.
    # The sign is kept rather than taken in absolute value — for a
    # single source the two agree once squared, but the sign is what
    # lets a source cancel later, e.g. `sin(m) - sin(m)`.
    return _chain(val_expr, (m, c))
end

"""
    Base.sin(m::SymbolicMeasurement)

Propagate `sin` through a measurement using the sensitivity
coefficient `∂sin(x)/∂x = cos(x)`. Implements JCGM 100:2008 §5.1.2
equation (10) for a single input. Traces REQ-020.
"""
Base.sin(m::SymbolicMeasurement) = _propagate_unary(sin, m)

"""
    Base.cos(m::SymbolicMeasurement)

Propagate `cos` through a measurement using `∂cos(x)/∂x = -sin(x)`.
Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.cos(m::SymbolicMeasurement) = _propagate_unary(cos, m)

"""
    Base.tan(m::SymbolicMeasurement)

Propagate `tan` through a measurement using `∂tan(x)/∂x = 1 + tan(x)²`.
Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.tan(m::SymbolicMeasurement) = _propagate_unary(tan, m)

"""
    Base.asin(m::SymbolicMeasurement)

Propagate `asin` through a measurement using
`∂asin(x)/∂x = 1 / sqrt(1 - x²)`. Assumes `|x| < 1`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.asin(m::SymbolicMeasurement) = _propagate_unary(asin, m)

"""
    Base.acos(m::SymbolicMeasurement)

Propagate `acos` through a measurement using
`∂acos(x)/∂x = -1 / sqrt(1 - x²)`. Assumes `|x| < 1`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.acos(m::SymbolicMeasurement) = _propagate_unary(acos, m)

"""
    Base.atan(m::SymbolicMeasurement)

Propagate `atan` through a measurement using
`∂atan(x)/∂x = 1 / (1 + x²)`. Implements JCGM 100:2008 §5.1.2.
Traces REQ-020.
"""
Base.atan(m::SymbolicMeasurement) = _propagate_unary(atan, m)

"""
    Base.atan(y::SymbolicMeasurement, x::SymbolicMeasurement)

Propagate the two-argument arctangent — the quadrant-preserving phase
`atan(y, x)` — with sensitivity coefficients

    ∂φ/∂y =  x / (x² + y²)      ∂φ/∂x = -y / (x² + y²)

This is the form a phase measurement actually takes: a lock-in
amplifier or a vector analyser reports quadrature components, and
`atan(y/x)` loses the quadrant that `atan(y, x)` keeps.

At the origin the phase is undefined and both sensitivities diverge.
As with the REQ-140 division guard, the package warns rather than
refuses when `x² + y²` cannot be proven nonzero at build time
(`upstream-bugs.md` UB-003): the returned quantity is valid wherever
the model is, and substitution decides.

Implements the methodology of JCGM 100:2008 §5.1.3. Traces REQ-023.
"""
function Base.atan(y::SymbolicMeasurement, x::SymbolicMeasurement)
    d = x.val^2 + y.val^2
    _warn_undefined_phase(d)
    return _chain(atan(y.val, x.val), (y, x.val / d), (x, -y.val / d))
end

Base.atan(y::SymbolicMeasurement, x::Union{Number,Symbolics.Num}) =
    atan(y, _wrap(x))

Base.atan(y::Union{Number,Symbolics.Num}, x::SymbolicMeasurement) =
    atan(_wrap(y), x)

"""
    Base.sinh(m::SymbolicMeasurement)

Propagate `sinh` using `∂sinh(x)/∂x = cosh(x)`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.sinh(m::SymbolicMeasurement) = _propagate_unary(sinh, m)

"""
    Base.cosh(m::SymbolicMeasurement)

Propagate `cosh` using `∂cosh(x)/∂x = sinh(x)`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.cosh(m::SymbolicMeasurement) = _propagate_unary(cosh, m)

"""
    Base.tanh(m::SymbolicMeasurement)

Propagate `tanh` using `∂tanh(x)/∂x = 1 - tanh(x)²`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.tanh(m::SymbolicMeasurement) = _propagate_unary(tanh, m)

"""
    Base.exp(m::SymbolicMeasurement)

Propagate `exp` using `∂exp(x)/∂x = exp(x)`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.exp(m::SymbolicMeasurement) = _propagate_unary(exp, m)

"""
    Base.log(m::SymbolicMeasurement)

Propagate the natural logarithm using `∂log(x)/∂x = 1/x`. Assumes
`x > 0`. Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
function Base.log(m::SymbolicMeasurement)
    _warn_domain(:log, m)
    return _propagate_unary(log, m)
end

"""
    Base.log2(m::SymbolicMeasurement)

Propagate the base-2 logarithm using `∂log2(x)/∂x = 1 / (ln(2) · x)`.
Assumes `x > 0`. Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
function Base.log2(m::SymbolicMeasurement)
    _warn_domain(:log2, m)
    return _propagate_unary(log2, m)
end

"""
    Base.log10(m::SymbolicMeasurement)

Propagate the base-10 logarithm using
`∂log10(x)/∂x = 1 / (ln(10) · x)`. Assumes `x > 0`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
function Base.log10(m::SymbolicMeasurement)
    _warn_domain(:log10, m)
    return _propagate_unary(log10, m)
end

"""
    Base.sqrt(m::SymbolicMeasurement)

Propagate `sqrt` using `∂sqrt(x)/∂x = 1 / (2·sqrt(x))`. Assumes
`x > 0`. Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
function Base.sqrt(m::SymbolicMeasurement)
    _warn_domain(:sqrt, m)
    return _propagate_unary(sqrt, m)
end

"""
    Base.abs(m::SymbolicMeasurement)

Propagate `abs` using `∂|x|/∂x = sign(x)`. The sensitivity coefficient
is piecewise (`+1` for `x > 0`, `-1` for `x < 0`); since the
propagation formula multiplies by `|c|`, the propagated standard
uncertainty is simply `m.err` for any non-zero `x`. Implements
JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.abs(m::SymbolicMeasurement) = _propagate_unary(abs, m)

"""
    Base.inv(m::SymbolicMeasurement)

Propagate `inv` using `∂(1/x)/∂x = -1/x²`. Assumes `x ≠ 0`.
Implements JCGM 100:2008 §5.1.2. Traces REQ-020.
"""
Base.inv(m::SymbolicMeasurement) = _propagate_unary(inv, m)

# Piecewise models — refused, with the reason.
#
# The GUM linearises the model around the input estimates
# (JCGM 100:2008 §5.1.2). `max`, `min` and `clamp` are not
# differentiable at their switch point, so a first-order combined
# uncertainty is undefined exactly where the model does something
# interesting — and near the switch the linear approximation is
# arbitrarily bad even where the derivative exists. JCGM 101:2008
# Monte Carlo is the tool for this.
#
# Refusing is the right behaviour. Refusing with a bare `MethodError`
# is not: it reads as an oversight rather than a decision, which is
# the same defect the REQ-021 message had.
#
# Traces REQ-024.
function _refuse_piecewise(name::String)
    throw(
        ArgumentError(
            "`$(name)` is not defined for a SymbolicMeasurement: it has " *
            "no derivative at its switch point, so the first-order law " *
            "of propagation (JCGM 100:2008 §5.1.2) has nothing to say " *
            "there, and near the switch the linearisation is arbitrarily " *
            "poor even where the derivative exists. Use a Monte Carlo " *
            "method (JCGM 101:2008) for a piecewise model, or apply " *
            "`$(name)` to the estimates yourself and state the " *
            "uncertainty you intend.",
        ),
    )
end

for op in (:max, :min)
    @eval begin
        Base.$op(::SymbolicMeasurement, ::SymbolicMeasurement) =
            _refuse_piecewise($(string(op)))
        Base.$op(::SymbolicMeasurement, ::Union{Number,Symbolics.Num}) =
            _refuse_piecewise($(string(op)))
        Base.$op(::Union{Number,Symbolics.Num}, ::SymbolicMeasurement) =
            _refuse_piecewise($(string(op)))
    end
end

Base.clamp(::SymbolicMeasurement, ::Any, ::Any) = _refuse_piecewise("clamp")
