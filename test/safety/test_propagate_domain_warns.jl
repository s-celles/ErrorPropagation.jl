@testitem "safety: propagate with sqrt on symbolic arg emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    @test_logs (:warn, r"REQ-141") propagate((a,) -> sqrt(a), [x ± σx])
end

@testitem "safety: propagate with log on symbolic arg emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    @test_logs (:warn, r"REQ-141") propagate((a,) -> log(a), [x ± σx])
end

@testitem "safety: propagate walker on sqrt with concrete positive arg does not warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables a σa
    # The body `sqrt(4.0) + a` — the sqrt argument is a concrete
    # 4.0 Num, so the walker's `_walker_safe_positive` detects
    # the safe case. No REQ-141 warn should fire.
    @test_logs min_level = Logging.Warn propagate(
        (x,) -> sqrt(4.0) + x,
        [a ± σa],
    )
end
