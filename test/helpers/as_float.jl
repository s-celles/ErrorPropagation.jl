@testsnippet AsFloat begin
    using Symbolics

    # Numerically evaluate a symbolic expression at a given substitution
    # by converting back to a Julia Expr and `eval`'ing in the testitem's
    # module. See research R7 of M1 (and R9 of M2) for the rationale: a
    # plain `Symbolics.substitute(expr, dict)` does not numerically
    # evaluate (sqrt(25.0) stays symbolic), so we go via `toexpr` + `eval`.
    _as_float(expr, dict) =
        Float64(eval(Symbolics.toexpr(Symbolics.substitute(expr, dict))))
end
