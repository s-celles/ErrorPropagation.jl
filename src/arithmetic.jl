# Binary operators — M11 phase 2.
#
# Every operator below is one application of the chain rule: state the
# estimate and each operand's sensitivity coefficient, and let
# `_chain` build the linear form. There is no uncertainty formula
# here any more. The variance is derived from the linear form by
# `_combined_uncertainty`, which is where equations (10) and (13) of
# JCGM 100:2008 live — as two regimes of one expression.
#
# Before M11 each operator carried its own sqrt-of-sum-of-squares,
# applied to the operands' `.err` fields. That path could not know
# whether two operands shared a source, so `x - x` reported `σ√2`.

"""
    Base.:+(x::SymbolicMeasurement, y::SymbolicMeasurement)

Propagate a sum per JCGM 100:2008 §5.1.3: `val = x.val + y.val`, with
sensitivity coefficients `cₓ = cᵧ = 1`.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-010,
REQ-110, REQ-202.
"""
Base.:+(x::SymbolicMeasurement, y::SymbolicMeasurement) =
    _chain(x.val + y.val, (x, Symbolics.Num(1)), (y, Symbolics.Num(1)))

"""
    Base.:-(x::SymbolicMeasurement, y::SymbolicMeasurement)

Propagate a difference per JCGM 100:2008 §5.1.3: `val = x.val - y.val`,
with sensitivity coefficients `cₓ = 1`, `cᵧ = -1`.

The signs are retained rather than squared away, which is what makes
`x - x` exactly zero when both operands are the same measurement.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-011,
REQ-110, REQ-202.
"""
Base.:-(x::SymbolicMeasurement, y::SymbolicMeasurement) =
    _chain(x.val - y.val, (x, Symbolics.Num(1)), (y, Symbolics.Num(-1)))

"""
    Base.:-(x::SymbolicMeasurement)

Negate a measurement: `val = -x.val`, sensitivity `c = -1`.

A sign change cannot change a dispersion, so `u_c` is unaffected
(JCGM 100:2008 §4.3.1). Going through `_chain` rather than rebuilding
from `.err` is what keeps the source identity, so `m + (-m)` is
exactly zero rather than `σ√2`.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-011,
REQ-202.
"""
Base.:-(x::SymbolicMeasurement) = _chain(-x.val, (x, Symbolics.Num(-1)))

"""
    Base.:+(x::SymbolicMeasurement)

Unary plus: the identity, present so that `+m` is not a `MethodError`
where `-m` is defined.

Traces REQ-010.
"""
Base.:+(x::SymbolicMeasurement) = x

"""
    Base.:*(x::SymbolicMeasurement, y::SymbolicMeasurement)

Propagate a product per JCGM 100:2008 §5.1.3: `val = x.val · y.val`,
with sensitivity coefficients `cₓ = y.val`, `cᵧ = x.val`.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-012,
REQ-110.
"""
Base.:*(x::SymbolicMeasurement, y::SymbolicMeasurement) =
    _chain(x.val * y.val, (x, y.val), (y, x.val))

"""
    Base.:/(x::SymbolicMeasurement, y::SymbolicMeasurement)

Propagate a quotient per JCGM 100:2008 §5.1.3: `val = x.val / y.val`,
with sensitivity coefficients `cₓ = 1/y.val`, `cᵧ = -x.val/y.val²`.

This is the operator behind the Ohm's-law worked example (`R = V/I`),
the M1 exit gate. Since M11 it also makes `x / x` exactly
dimensionless-one with zero uncertainty.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-013,
REQ-110, REQ-202.
"""
function Base.:/(x::SymbolicMeasurement, y::SymbolicMeasurement)
    _warn_division_by_zero(y)
    return _chain(x.val / y.val, (x, 1 / y.val), (y, -x.val / y.val^2))
end

"""
    Base.:^(x::SymbolicMeasurement, n::Union{Real, Symbolics.Num})

Propagate a power per JCGM 100:2008 §5.1.3: `val = x.val^n`, with
sensitivity coefficient `cₓ = n · x.val^(n-1)`.

The exponent is a plain `Real` or a `Symbolics.Num`, never another
measurement.

Implements the methodology of JCGM 100:2008 §5.1. Traces REQ-014,
REQ-110.
"""
Base.:^(x::SymbolicMeasurement, n::Union{Real,Symbolics.Num}) =
    _chain(x.val^n, (x, n * x.val^(n - 1)))
