@testitem "exp(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = exp(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - exp(x)), 0)

    reference_err = abs(exp(x)) * σx
    dict = Dict(x => 2.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "log(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = log(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - log(x)), 0)

    reference_err = abs(1 / x) * σx
    dict = Dict(x => 2.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "log2(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = log2(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - log2(x)), 0)

    # ∂log2(x)/∂x = 1 / (ln(2) · x); reference uses the literal float
    reference_err = abs(1 / (0.6931471805599453 * x)) * σx
    dict = Dict(x => 2.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "log10(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = log10(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - log10(x)), 0)

    # ∂log10(x)/∂x = 1 / (ln(10) · x); reference uses the literal float
    reference_err = abs(1 / (2.302585092994046 * x)) * σx
    dict = Dict(x => 2.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end
