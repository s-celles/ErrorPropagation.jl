@testitem "sqrt(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = sqrt(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - sqrt(x)), 0)

    reference_err = abs(1 / (2 * sqrt(x))) * σx
    dict = Dict(x => 4.0, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "abs(m): GUM §5.1.2 unary propagation (numeric only)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = abs(m)

    @test result isa SymbolicMeasurement
    # The val is `abs(x)` symbolically.
    @test Symbolics.isequal(Symbolics.simplify(result.val - abs(x)), 0)

    # The derivative ifelse(signbit(x), -1, 1) does not symbolically
    # reduce to ±1, so we evaluate numerically. For any non-zero x,
    # |∂|x|/∂x| = 1, so the propagated err equals σx.
    @test isapprox(
        _as_float(result.err, Dict(x => 2.0, σx => 0.01)),
        0.01;
        atol = 1e-12,
    )
    @test isapprox(
        _as_float(result.err, Dict(x => -2.0, σx => 0.01)),
        0.01;
        atol = 1e-12,
    )
end

@testitem "inv(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = inv(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - inv(x)), 0)

    reference_err = abs(-1 / x^2) * σx
    dict = Dict(x => 2.0, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end
