@testitem "sin(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = sin(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - sin(x)), 0)

    reference_err = abs(cos(x)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(result.err - reference_err), 0)
    numeric_ok = isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
    @test symbolic_ok || numeric_ok
end

@testitem "cos(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = cos(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - cos(x)), 0)

    reference_err = abs(sin(x)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(result.err - reference_err), 0)
    numeric_ok = isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
    @test symbolic_ok || numeric_ok
end

@testitem "tan(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = tan(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - tan(x)), 0)

    reference_err = abs(1 + tan(x)^2) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "asin(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = asin(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - asin(x)), 0)

    reference_err = abs(1 / sqrt(1 - x^2)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "acos(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = acos(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - acos(x)), 0)

    reference_err = abs(-1 / sqrt(1 - x^2)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "atan(m): GUM §5.1.2 unary propagation" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = atan(m)

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - atan(x)), 0)

    reference_err = abs(1 / (1 + x^2)) * σx
    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end
