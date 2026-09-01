# Hook point for optional CAS extensions (e.g. a future Giac.jl package
# extension). The default implementation delegates to Symbolics.simplify.
# An extension can overload `_simplify_for_report` to apply a more powerful
# CAS simplification instead.
#
# Simplification here is cosmetic: it makes a reported expression
# readable and never changes what it means. So it is not allowed to
# take the whole computation down with it, and `Symbolics.simplify`
# does throw on ordinary metrological input — a `BoundsError` on an
# even power of a negated symbol (`upstream-bugs.md` UB-006), and an
# `Int64` overflow inside `DynamicPolynomials` on a `Rational`
# coefficient with a large denominator, such as the `1//1000000000000`
# that a degrees-of-freedom count of `1e12` contributes to
# Welch-Satterthwaite (UB-008). Both used to surface as an exception thrown from a plain
# property access like `m.dof`.
#
# On failure the unsimplified expression is returned. It prints less
# tidily and carries exactly the same value.
function _simplify_for_report(expr)
    try
        return Symbolics.simplify(expr)
    catch err
        err isa InterruptException && rethrow()
        @debug "simplification failed; reporting the unsimplified form" exception =
            err
        return expr
    end
end

# Private helpers for symbolic differentiation with a deterministic
# "cannot find a closed form" failure path.
#
# REQ-021 requires that when `Symbolics.derivative` cannot compute a
# closed-form derivative for a user-supplied function, the library
# raises an `ArgumentError` directing the user at the
# `apply(f, m; derivative = ...)` escape hatch.
#
# `_safe_derivative` returns `nothing` (rather than throwing) when the
# symbolic engine fails. Two failure modes are handled:
#
#   1. `Symbolics.derivative` itself throws — caught and turned into
#      `nothing`.
#   2. `Symbolics.derivative` returns an unresolved expression
#      containing a `Symbolics.Differential` wrapper — Symbolics's
#      "I gave up, here's the formal derivative" form. We walk the
#      result tree and treat that as failure too.
#
# Callers (`_propagate_unary` in src/math.jl, `propagate` in
# src/propagate.jl, and the correlated `propagate` in
# src/propagate_correlated.jl) check for `nothing` and produce the
# user-facing REQ-021 error message.

function _has_unresolved_differential(expr)
    expr_w = Symbolics.unwrap(expr)
    if expr_w isa Symbolics.SymbolicUtils.BasicSymbolic
        op =
            Symbolics.SymbolicUtils.iscall(expr_w) ?
            Symbolics.SymbolicUtils.operation(expr_w) : nothing
        if op isa Symbolics.Differential
            return true
        end
        if Symbolics.SymbolicUtils.iscall(expr_w)
            for arg in Symbolics.SymbolicUtils.arguments(expr_w)
                if _has_unresolved_differential(arg)
                    return true
                end
            end
        end
    end
    return false
end

function _safe_derivative(expr, var)
    local d
    try
        d = Symbolics.derivative(expr, var)
    catch
        return nothing
    end
    if _has_unresolved_differential(d)
        return nothing
    end
    return d
end
