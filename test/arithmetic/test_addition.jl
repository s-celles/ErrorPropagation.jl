@testitem "+ propagates uncorrelated sum per GUM §5.1" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    x = SymbolicMeasurement(a, σa)
    y = SymbolicMeasurement(b, σb)

    s = x + y

    @test s isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(s.val - (a + b)), 0)

    reference_err = sqrt(σa^2 + σb^2)

    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(s.err - reference_err), 0)

    dict = Dict(a => 12.0, σa => 0.1, b => 5.0, σb => 0.05)
    numeric_ok = isapprox(
        _as_float(s.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )

    @test symbolic_ok || numeric_ok
end
