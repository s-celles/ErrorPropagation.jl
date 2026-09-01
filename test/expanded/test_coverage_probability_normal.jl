@testitem "expanded_uncertainty keyword: dof=nothing → normal quantile + @info" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx   # dof is nothing

    U =
        @test_logs (:info, r"normal-distribution quantile") expanded_uncertainty(
            m;
            coverage_probability = 0.95,
        )
    dict = Dict(x => 1.0, σx => 0.1)
    @test isapprox(_as_float(U.U, dict), 0.196; atol = 1e-12)
end

@testitem "expanded_uncertainty keyword: dof=Num(Inf) → normal, no info" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = SymbolicMeasurement(x, σx, Symbolics.Num(Inf))

    U = expanded_uncertainty(m; coverage_probability = 0.95)
    dict = Dict(x => 1.0, σx => 0.1)
    @test isapprox(_as_float(U.U, dict), 0.196; atol = 1e-12)
end

@testitem "expanded_uncertainty keyword: large ν → normal quantile (no warning)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = SymbolicMeasurement(x, σx, Symbolics.Num(100))

    U = expanded_uncertainty(m; coverage_probability = 0.95)
    dict = Dict(x => 1.0, σx => 0.1)
    @test isapprox(_as_float(U.U, dict), 0.196; atol = 1e-12)
end

@testitem "expanded_uncertainty keyword: unsupported p raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    @test_throws ArgumentError expanded_uncertainty(
        m;
        coverage_probability = 0.8,
    )
end

@testitem "expanded_uncertainty keyword: symbolic dof keeps ν" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Before M12 a symbolic ν fell back to the normal quantile with an
    # @info, discarding the degrees of freedom — the one thing the
    # coverage factor is there to account for. It now yields a closed
    # form in ν (Cornish-Fisher), so U depends on ν too.
    @variables x σx ν
    m = SymbolicMeasurement(x, σx, ν)

    U = expanded_uncertainty(m; coverage_probability = 0.95)
    @test any(isequal(Symbolics.value(ν)), Symbolics.get_variables(U.U))

    # At ν = 30, k is Table G.2's 2.042 rather than the normal 1.96.
    dict = Dict(x => 1.0, σx => 0.1, ν => 30.0)
    @test isapprox(_as_float(U.U, dict), 0.2042; atol = 5e-4)
end
