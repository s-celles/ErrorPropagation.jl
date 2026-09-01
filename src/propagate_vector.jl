# Vector-valued multi-input propagation (JCGM 102:2011 / GUM
# Supplement 2). Takes a user function `f` that returns a tuple,
# vector, or other iterable of derived quantities, and returns a
# `Vector{SymbolicMeasurement}` whose `.err` fields come from the
# diagonal of the propagated output covariance matrix `J · Σ_in ·
# J^T`, where `J` is the symbolic Jacobian and `Σ_in` is a diagonal
# matrix of input variances.
#
# At M2 the inputs are assumed uncorrelated (Σ_in is diagonal).
# Cross-output covariances are NOT exposed at M2 — users who need
# the full output covariance can call `Symbolics.jacobian` directly.
#
# Traces REQ-033.

"""
    propagate_vector(f, ms::AbstractVector{SymbolicMeasurement}) -> Vector{SymbolicMeasurement}

Propagate uncertainty through a multi-output function `f` of
`length(ms)` arguments. `f(ms[1].val, ..., ms[N].val)` must return
something `collect`-able (a `Tuple`, `Vector`, or any iterable
producing `M` symbolic outputs).

Returns a `Vector{SymbolicMeasurement}` of length `M`, where each
output measurement carries:

- `val` — the symbolic output expression
- `err` — the **marginal** propagated standard uncertainty of that
  output, i.e. the diagonal of `J · Σ_in · J^T` where `J` is the
  `M × N` symbolic Jacobian and `Σ_in` is the diagonal matrix of
  input variances `u²(xₖ)`

At M2 the inputs are assumed uncorrelated. The full **cross-output
covariance** matrix `J · Σ_in · J^T` is not exposed by this method;
users who need it can call `Symbolics.jacobian(vals, xs)` directly
and combine it with `Σ_in` themselves.

Implements the methodology of JCGM 102:2011 (GUM Supplement 2).
Traces REQ-033, REQ-110.
"""
function propagate_vector(f, ms::AbstractVector{SymbolicMeasurement})
    xs = [m.val for m in ms]
    vals = collect(f(xs...))
    σs = [m.err for m in ms]

    J = Symbolics.jacobian(vals, xs)

    out = Vector{SymbolicMeasurement}(undef, length(vals))
    for i in eachindex(vals)
        err_squared = Symbolics.Num(0)
        for k in eachindex(ms)
            err_squared = err_squared + (J[i, k] * σs[k])^2
        end
        out[i] = SymbolicMeasurement(
            vals[i],
            _simplify_for_report(sqrt(err_squared)),
        )
    end
    return out
end
