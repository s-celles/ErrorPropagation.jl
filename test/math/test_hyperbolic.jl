@testitem "sinh(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = sinh(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - sinh(x)), 0)

    reference_err = abs(cosh(x)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "cosh(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = cosh(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - cosh(x)), 0)

    reference_err = abs(sinh(x)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "tanh(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = tanh(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - tanh(x)), 0)

    reference_err = abs(1 - tanh(x)^2) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end
