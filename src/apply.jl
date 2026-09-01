# The `apply` escape hatch — provides a public entry point for cases
# where the symbolic differentiation engine cannot find a closed-form
# derivative for the user's function.
#
# When called without a `derivative` keyword, `apply(f, m)` delegates
# to `propagate(f, [m])` so that the symbolic engine's normal
# differentiation path is used. When called with an explicit
# `derivative` argument (a `Symbolics.Num` expression in the same
# variable as `m.val`), `apply` skips the differentiation step and
# uses the caller-supplied expression.
#
# Traces REQ-022.

"""
    apply(f, m::SymbolicMeasurement; derivative = nothing) -> SymbolicMeasurement

Apply a single-argument function `f` to a measurement `m`, returning
the propagated measurement.

When `derivative === nothing` (the default), `apply` delegates to
`propagate(f, [m])`, which uses `Symbolics.derivative` to compute
the sensitivity coefficient. This path produces results identical
(after simplification) to calling `f(m)` directly for any function
the symbolic engine can differentiate.

When `derivative` is a `Symbolics.Num` expression (in the same
variable as `m.val`), `apply` uses it directly and computes
`u(f(x)) = |derivative| · u(x)`, skipping the symbolic
differentiation step. This is the **escape hatch** for functions
whose derivative the symbolic engine cannot find — `propagate(f,
[m])` would raise `ArgumentError` directing the user here.

The `derivative` keyword takes a **symbolic expression**, not a
Julia function. To use a function-style derivative, evaluate it at
`m.val` first:

```julia
my_df(x) = 2*x
apply(f, m; derivative = my_df(m.val))
```

Implements the methodology of JCGM 100:2008 §5.1.3 (sensitivity
coefficients). Traces REQ-022.
"""
function apply(f, m::SymbolicMeasurement; derivative = nothing)
    if derivative === nothing
        return propagate(f, [m])
    end
    val_expr = f(m.val)
    # The user-supplied derivative is the sensitivity coefficient;
    # `_chain` carries it into `m`'s sources (JCGM 100:2008 §5.1.3).
    return _chain(val_expr, (m, Symbolics.Num(derivative)))
end
