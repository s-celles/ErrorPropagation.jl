# Multi-variable closed-form uncertainty propagation through a
# user-supplied Julia function `f`. This is the M2 central API: it
# evaluates `f` symbolically on the input estimates, computes
# sensitivity coefficients via `Symbolics.derivative`, and combines
# them with the standard combined-standard-uncertainty formula.
#
# Since M11 this is a convenience over the operators, not a second
# path: identity tracking lives in the type, so `f(x) = x - x`
# collapses to zero whether written through `propagate` or with the
# plain operators. Before M11 only this path got it right, and the
# distinction was the substance of the withdrawn UB-002 — the M1
# binary operators applied the formula on raw `.err`
# fields without knowing that the operands are the same variable.
#
# Traces REQ-030.

"""
    propagate(f, ms::AbstractVector{SymbolicMeasurement}) -> SymbolicMeasurement

Propagate uncertainty through a user-supplied Julia function `f` of
`length(ms)` arguments, evaluated on the input measurements `ms`,
implementing JCGM 100:2008 §5.1.2 equation (10) for **uncorrelated**
inputs:

```
u_c²(y) = Σᵢ (∂f/∂xᵢ)² · u²(xᵢ)
```

The sensitivity coefficients `∂f/∂xᵢ` are obtained symbolically from
`Symbolics.derivative` evaluated on `f(m₁.val, m₂.val, …, mₙ.val)`.
The result is a new `SymbolicMeasurement` whose `val` field is the
symbolic output expression and whose `err` field is the propagated
combined standard uncertainty (simplified once via
`Symbolics.simplify`).

When the user function reuses the same input `mᵢ` multiple times in
its body, symbolic differentiation correctly handles the
cancellation. For example, `propagate(x -> x - x, [m])` returns a
measurement with **zero** uncertainty — as does `m - m` written
directly, since M11 moved identity tracking into the type.

Raises `ArgumentError` (REQ-021 / FR-004) if the symbolic engine
cannot compute a closed-form derivative for any input. Use the
`apply(f, m; derivative = ...)` escape hatch in that case.

Edge cases:

- `length(ms) == 0` returns `SymbolicMeasurement(Num(f()), Num(0))`
  — empty sum has zero variance.
- `f` returning a value independent of any `ms[i]` returns zero
  propagated uncertainty.

Implements the methodology of JCGM 100:2008 §5.1.2 equation (10).
Traces REQ-030, REQ-110.
"""
function propagate(f, ms::AbstractVector{SymbolicMeasurement})
    if isempty(ms)
        return SymbolicMeasurement(Symbolics.Num(f()), Symbolics.Num(0))
    end

    # Since M11 this is a convenience over the operators, not a second
    # propagation path (REQ-207). Applying `f` to the measurements
    # themselves lets the overloaded operators build the linear form
    # by the chain rule, which is what makes a source shared between
    # arguments cancel or correlate correctly — the pre-M11 version
    # differentiated `f` over the estimates and rebuilt the variance
    # here, duplicating logic that now lives in exactly one place.
    result = try
        f(ms...)
    catch e
        # A function built from operations the package does not
        # overload lands here as a MethodError. REQ-021 promises an
        # actionable message pointing at the `apply` escape hatch, so
        # translate rather than leaking the raw dispatch failure.
        e isa MethodError || rethrow()
        fname =
            nameof(f) === Symbol("#f") ? "<anonymous>" : string(nameof(f))
        # Name the operation that failed to dispatch. Reporting this
        # as "no closed-form derivative" sent the reader to look at
        # differentiability, which is usually not the problem: `-m`
        # raised it for years while ∂(-x)/∂x = -1 all along, because
        # unary minus simply had no method.
        opname = try
            string(nameof(e.f))
        catch
            "an operation"
        end
        throw(
            ArgumentError(
                "`$(fname)` applies `$(opname)` to a SymbolicMeasurement, " *
                "which the package does not overload. Either build the " *
                "model from the supported operations, or supply the " *
                "sensitivity coefficient yourself: " *
                "`apply($(fname), m; derivative = ...)` " *
                "(JCGM 100:2008 §5.1.3).",
            ),
        )
    end

    # `f` may ignore its arguments entirely (a constant model), in
    # which case the operators never ran and the result is a plain
    # value carrying no uncertainty.
    result isa SymbolicMeasurement && return result
    return SymbolicMeasurement(Symbolics.Num(result), Symbolics.Num(0))
end
