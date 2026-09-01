@testitem "propagate: linear case f(x) = a·x + b returns |a|·u(x) (REQ-151)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a b x σx
    x_m = x ± σx

    # Linear function with `a` and `b` as plain symbolic constants
    result = propagate(z -> a * z + b, [x_m])

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - (a * x + b)), 0)

    reference_err = abs(a) * σx
    dict = Dict(a => 3.0, b => 2.0, x => 5.0, σx => 0.1)
    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(result.err - reference_err), 0)
    numeric_ok = isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
    @test symbolic_ok || numeric_ok
end
