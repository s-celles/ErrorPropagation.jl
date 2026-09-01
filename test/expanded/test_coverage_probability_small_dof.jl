@testitem "expanded_uncertainty keyword: small dof uses Table G.2 (p=0.95)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    # ν = 4 → t(0.95, 4) = 2.78 per GUM Table G.2.
    m = SymbolicMeasurement(x, σx, Symbolics.Num(4))

    U = @test_logs (:warn, r"ν_eff") expanded_uncertainty(
        m;
        coverage_probability = 0.95,
    )
    dict = Dict(x => 1.0, σx => 0.1)
    @test isapprox(_as_float(U.U, dict), 0.278; atol = 1e-12)
end

@testitem "expanded_uncertainty keyword: small dof uses Table G.2 (p=0.99)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    # ν = 3 → t(0.99, 3) = 5.84 per GUM Table G.2.
    m = SymbolicMeasurement(x, σx, Symbolics.Num(3))

    U = @test_logs (:warn, r"ν_eff") expanded_uncertainty(
        m;
        coverage_probability = 0.99,
    )
    dict = Dict(x => 1.0, σx => 0.1)
    @test isapprox(_as_float(U.U, dict), 0.584; atol = 1e-12)
end
