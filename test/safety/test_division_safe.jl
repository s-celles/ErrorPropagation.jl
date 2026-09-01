@testitem "safety: division by concrete nonzero Real emits no @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables x σx
    x_m = x ± σx
    one_m = 1.0 ± 0.0
    # No warning at min_level=Warn.
    @test_logs min_level = Logging.Warn x_m / one_m
end

@testitem "safety: division by concrete negative Real emits no @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables x σx
    x_m = x ± σx
    neg_m = -5.0 ± 0.1
    @test_logs min_level = Logging.Warn x_m / neg_m
end
