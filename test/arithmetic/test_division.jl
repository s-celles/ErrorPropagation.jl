@testitem "/ propagates quotient rule per GUM §5.1" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    x = SymbolicMeasurement(a, σa)
    y = SymbolicMeasurement(b, σb)

    q = x / y

    @test q isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(q.val - (a / b)), 0)

    reference_err = sqrt((σa / b)^2 + (a * σb / b^2)^2)

    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(q.err - reference_err), 0)

    dict = Dict(a => 12.0, σa => 0.1, b => 5.0, σb => 0.05)
    numeric_ok = isapprox(
        _as_float(q.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )

    @test symbolic_ok || numeric_ok
end
