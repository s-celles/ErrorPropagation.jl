@testitem "propagate: empty input vector returns f() with zero err" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    result = propagate(() -> 5.0, SymbolicMeasurement[])

    @test result isa SymbolicMeasurement
    @test isapprox(_as_float(result.val, Dict()), 5.0; atol = 1e-12)
    @test isapprox(_as_float(result.err, Dict()), 0.0; atol = 1e-12)
end
