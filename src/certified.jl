# Certified linearisation — M13.
#
# The GUM's combined uncertainty is a first-order Taylor result. JCGM
# 101:2008 checks whether that linearisation holds by SAMPLING. A
# symbolic Hessian, bounded over the coverage region, checks it
# DETERMINISTICALLY — over every point at once rather than the ones
# that happened to be drawn.
#
# M6 ships a linearity *indicator* and warns past |η| > 0.1. That is a
# heuristic evaluated at a point, and it is diagonal-only: for `a*b`
# every ∂²f/∂xᵢ² is zero, so M6 calls a product linear. All of a
# product's nonlinearity lives in the mixed partial, which M13
# includes.
#
# Nothing here corrects a result. REQ-182 stands: the bound is
# reported beside u_c, never folded into it.

# --- Minimal interval arithmetic --------------------------------------
#
# Rigorous bounds need interval evaluation, and a bound is worthless
# unless it is guaranteed. This is deliberately small rather than a
# dependency: REQ-130 keeps Symbolics.jl the only mandatory one.
#
# Every operation returns an interval containing the true image. Where
# a rigorous result cannot be produced, the code raises rather than
# guessing — an unsound bound is worse than none.

struct _Ivl
    lo::Float64
    hi::Float64
end

_ivl(x::Real) = _Ivl(Float64(x), Float64(x))

Base.:+(a::_Ivl, b::_Ivl) = _Ivl(a.lo + b.lo, a.hi + b.hi)
Base.:-(a::_Ivl, b::_Ivl) = _Ivl(a.lo - b.hi, a.hi - b.lo)
Base.:-(a::_Ivl) = _Ivl(-a.hi, -a.lo)

function Base.:*(a::_Ivl, b::_Ivl)
    p = (a.lo * b.lo, a.lo * b.hi, a.hi * b.lo, a.hi * b.hi)
    return _Ivl(minimum(p), maximum(p))
end

function Base.:/(a::_Ivl, b::_Ivl)
    if b.lo <= 0 <= b.hi
        throw(
            ArgumentError(
                "linearisation_bound: a denominator's interval spans " *
                "zero, so no finite bound exists over this coverage " *
                "region. Narrow the region or bound the model by hand.",
            ),
        )
    end
    return a * _Ivl(1 / b.hi, 1 / b.lo)
end

function Base.:^(a::_Ivl, n::Integer)
    n == 0 && return _ivl(1)
    n < 0 && return _ivl(1) / (a^(-n))
    if iseven(n)
        # An even power is non-negative and minimised at zero if the
        # interval straddles it.
        lo = a.lo <= 0 <= a.hi ? 0.0 : min(a.lo^n, a.hi^n)
        return _Ivl(lo, max(a.lo^n, a.hi^n))
    end
    return _Ivl(a.lo^n, a.hi^n)
end

# Monotone increasing functions map endpoints to endpoints.
for f in (:exp, :sinh, :tanh, :atan, :cbrt)
    @eval Base.$f(a::_Ivl) = _Ivl($f(a.lo), $f(a.hi))
end

function Base.sqrt(a::_Ivl)
    a.lo < 0 && throw(
        ArgumentError(
            "linearisation_bound: sqrt of an interval reaching below " *
            "zero over this coverage region.",
        ),
    )
    return _Ivl(sqrt(a.lo), sqrt(a.hi))
end

function Base.log(a::_Ivl)
    a.lo <= 0 && throw(
        ArgumentError(
            "linearisation_bound: log of an interval reaching zero or " *
            "below over this coverage region.",
        ),
    )
    return _Ivl(log(a.lo), log(a.hi))
end

# sin and cos are bounded but not monotone: widen to [-1,1] unless the
# interval is narrow enough that the endpoints are extremal.
function Base.sin(a::_Ivl)
    a.hi - a.lo >= 2π && return _Ivl(-1.0, 1.0)
    return _Ivl(
        min(sin(a.lo), sin(a.hi), _sin_extremum(a, -1)),
        max(sin(a.lo), sin(a.hi), _sin_extremum(a, 1)),
    )
end
Base.cos(a::_Ivl) = sin(a + _ivl(π / 2))

# Does the interval contain a point where sin reaches `sign`?
function _sin_extremum(a::_Ivl, sign::Int)
    k = ceil((a.lo / (2π)) - (sign == 1 ? 0.25 : 0.75))
    crit = 2π * k + (sign == 1 ? π / 2 : 3π / 2)
    return a.lo <= crit <= a.hi ? Float64(sign) : Float64(-sign)
end

Base.abs(a::_Ivl) =
    a.lo <= 0 <= a.hi ? _Ivl(0.0, max(-a.lo, a.hi)) :
    _Ivl(min(abs(a.lo), abs(a.hi)), max(abs(a.lo), abs(a.hi)))

_mag(a::_Ivl) = max(abs(a.lo), abs(a.hi))

# Evaluate a symbolic expression over a box of intervals.
function _ivl_eval(expr, box::AbstractDict)
    v = Symbolics.value(expr)
    v isa Number && return _ivl(v)

    if !Symbolics.iscall(v)
        for (sym, iv) in box
            isequal(Symbolics.value(sym), v) && return iv
        end
        throw(
            ArgumentError(
                "linearisation_bound: no interval supplied for `$(v)`. " *
                "Every input the model depends on needs a value and a " *
                "standard uncertainty.",
            ),
        )
    end

    op = Symbolics.operation(v)
    args = [_ivl_eval(a, box) for a in Symbolics.arguments(v)]

    op === (+) && return reduce(+, args)
    op === (*) && return reduce(*, args)
    if op === (-)
        length(args) == 1 && return -args[1]
        return reduce(-, args)
    end
    op === (/) && return args[1] / args[2]
    if op === (^)
        e = Symbolics.value(Symbolics.arguments(v)[2])
        e isa Integer && return args[1]^e
        e isa Real && isinteger(e) && return args[1]^Int(e)
        throw(
            ArgumentError(
                "linearisation_bound: non-integer exponent `$(e)` is not " *
                "supported by the interval evaluator.",
            ),
        )
    end
    op === inv && return _ivl(1) / args[1]

    for (fsym, f) in (
        (exp, exp),
        (log, log),
        (sqrt, sqrt),
        (sin, sin),
        (cos, cos),
        (abs, abs),
        (sinh, sinh),
        (tanh, tanh),
        (atan, atan),
        (cbrt, cbrt),
    )
        op === fsym && return f(args[1])
    end

    throw(
        ArgumentError(
            "linearisation_bound: `$(op)` has no interval extension, so " *
            "no rigorous bound can be produced. An unsound bound would " *
            "be worse than none.",
        ),
    )
end

# --- The bound --------------------------------------------------------

"""
    linearisation_bound(f, measurements; coverage_factor = 2, values = nothing)

Rigorous bound on the error the GUM's first-order linearisation makes,
over the coverage region of the inputs.

Taylor's theorem with the Lagrange remainder gives

    f(x + δ) = f(x) + Σᵢ cᵢδᵢ + ½ Σᵢⱼ Hᵢⱼ(ξ) δᵢδⱼ

for some `ξ` in the region. Bounding every `Hᵢⱼ` there by interval
arithmetic bounds the remainder for **every** point at once:

    |R| ≤ ½ Σᵢⱼ max|Hᵢⱼ| · (k·uᵢ)(k·uⱼ)

The claim this supports is stronger than JCGM 101:2008's: Monte Carlo
checks the linearisation by sampling, so it can only say the points it
drew were fine. A bounded symbolic Hessian certifies the whole
coverage region deterministically.

Unlike M6's `check_linearity`, the **mixed** partials are included.
That matters: for `f = a·b` every `∂²f/∂xᵢ²` is zero, so a
diagonal-only indicator calls a product linear when the entirety of
its nonlinearity sits in `∂²f/∂a∂b`.

`coverage_factor` sets the region half-width in standard uncertainties
(`k = 2` ≈ 95 % under a normal assumption, JCGM 100:2008 §6.3.2).

The result is **reported, never applied**. REQ-182 stands: no
higher-order correction is ever folded into `u_c` behind the user's
back.

Raises `ArgumentError` when no rigorous bound exists — a denominator
straddling zero, `log` of an interval reaching zero, an operation with
no interval extension. An unsound bound is worse than none.

Implements the methodology of JCGM 100:2008 §5.1.2 note and §E.3.1.
Traces REQ-220, REQ-221, REQ-222; REQ-182 stands.
"""
function linearisation_bound(
    f,
    measurements::AbstractVector{<:SymbolicMeasurement};
    coverage_factor::Real = 2,
    values::Union{AbstractDict,Nothing} = nothing,
)
    isempty(measurements) && return 0.0
    values === nothing && throw(
        ArgumentError(
            "linearisation_bound requires `values` — a bound is a number " *
            "over a concrete region, so the estimates and standard " *
            "uncertainties must be substituted.",
        ),
    )

    xs = [m.val for m in measurements]
    expr = Symbolics.Num(f(xs...))

    # Coverage region: xᵢ ± k·uᵢ, and the half-widths that scale the
    # remainder.
    box = Dict{Any,_Ivl}()
    half = Float64[]
    for m in measurements
        centre = _as_number(Symbolics.substitute(m.val, values))
        u = _as_number(Symbolics.substitute(m.err, values))
        h = abs(coverage_factor * u)
        push!(half, h)
        box[Symbolics.value(m.val)] = _Ivl(centre - h, centre + h)
    end

    # Any symbol the model touches but that is not an input estimate —
    # a σ appearing in the model itself, say — is fixed at its value.
    for (k, v) in values
        key = Symbolics.value(k)
        haskey(box, key) && continue
        box[key] = _ivl(_as_number(v))
    end

    total = 0.0
    for i in eachindex(measurements), j in eachindex(measurements)
        hij = _safe_derivative(_safe_derivative(expr, xs[i]), xs[j])
        hij === nothing && throw(
            ArgumentError(
                "linearisation_bound: no closed-form second derivative " *
                "with respect to arguments $(i) and $(j).",
            ),
        )
        isequal(Symbolics.value(hij), 0) && continue
        total += _mag(_ivl_eval(hij, box)) * half[i] * half[j]
    end
    return total / 2
end

# Reduce a substituted expression to a Float64, going through `toexpr`
# because `Symbolics.substitute` does not itself evaluate (UB-001).
function _as_number(x)
    v = Symbolics.value(x)
    v isa Number && return Float64(v)
    return Float64(eval(Symbolics.toexpr(v)))
end

"""
    second_order_correction(f, measurements) -> Symbolics.Num

Second-order term to be added to the estimate of the measurand when
the model's nonlinearity is significant.

JCGM 100:2008/Amd.1:2026 §4.1.4 NOTE 1 states that where the
nonlinearity of `f` matters, either a Monte Carlo method is applied or
higher-order terms must be included in the expression for `y`. For
independent, normally distributed inputs the term is

    ½ Σᵢ (∂²f/∂xᵢ²) u²(xᵢ)

and equation (H.10) generalises it to non-independent inputs as

    ½ Σᵢ Σⱼ (∂²f/∂xᵢ∂xⱼ) u(xᵢ, xⱼ)

which is what this returns: the double sum, with `u(xᵢ,xᵢ) = u²(xᵢ)`
and off-diagonal entries taken from declared covariances. With
independent inputs the two coincide.

**This corrects the ESTIMATE, not the uncertainty.** It is a different
question from [`linearisation_bound`](@ref), which bounds the error
the first-order law of propagation makes in `u_c`. A model can need
one and not the other: a product of independent inputs has a zero
Hessian diagonal, so its estimate is exact while its uncertainty is
not — and correlated inputs make `E[AB] − E[A]E[B] = cov(A,B)`, which
this returns.

The correction is **returned, never applied**. REQ-182 stands: nothing
is folded into `val` behind the user's back, and the amendment asks
for the term to be included deliberately, not silently.

Traces REQ-223; REQ-182 stands.
"""
function second_order_correction(
    f,
    measurements::AbstractVector{<:SymbolicMeasurement},
)
    isempty(measurements) && return Symbolics.Num(0)

    xs = [m.val for m in measurements]
    expr = Symbolics.Num(f(xs...))

    total = Symbolics.Num(0)
    for i in eachindex(measurements), j in eachindex(measurements)
        hij = _safe_derivative(_safe_derivative(expr, xs[i]), xs[j])
        hij === nothing && throw(
            ArgumentError(
                "second_order_correction: no closed-form second " *
                "derivative with respect to arguments $(i) and $(j). " *
                "Use a Monte Carlo method instead (JCGM 101:2008), as " *
                "JCGM 100:2008/Amd.1:2026 §4.1.4 NOTE 1 allows.",
            ),
        )
        isequal(Symbolics.value(hij), 0) && continue

        # u(xᵢ,xⱼ): the variance on the diagonal, the covariance the
        # two measurements actually share off it.
        cij =
            i == j ? measurements[i].err^2 :
            covariance(measurements[i], measurements[j])
        total = total + hij * cij
    end
    return _simplify_for_report(total / 2)
end
