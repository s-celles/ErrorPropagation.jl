@testitem "propagate: constant function returns zero err" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    x_m = x ± σx

    result = propagate(_ -> 5.0, [x_m])

    @test result isa SymbolicMeasurement
    @test isapprox(
        _as_float(result.err, Dict(x => 0.0, σx => 0.1)),
        0.0;
        atol = 1e-12,
    )
end
