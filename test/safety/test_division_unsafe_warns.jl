@testitem "safety: division by plain symbolic emits REQ-140 @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx y σy
    x_m = x ± σx
    y_m = y ± σy
    @test_logs (:warn, r"REQ-140") x_m / y_m
end

@testitem "safety: division by concrete zero emits REQ-140 @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    x_m = x ± σx
    zero_m = 0.0 ± 0.1
    @test_logs (:warn, r"REQ-140") x_m / zero_m
end

@testitem "safety: mixed-mode division by plain symbolic emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables y σy
    y_m = y ± σy
    # `5.0 / y_m` — y_m is the denominator, symbolic `.val` → warn.
    @test_logs (:warn, r"REQ-140") 5.0 / y_m
end
