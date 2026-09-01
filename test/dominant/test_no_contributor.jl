@testitem "dominant_source: no-contributor case emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa z σz
    m = a ± σa   # measurand does not depend on z

    dom =
        @test_logs (:warn, r"no dominant source") dominant_source(m, [z], [σz])
    @test dom.index == 0
    @test Symbolics.isequal(dom.contribution, 0)
end

@testitem "dominant_source: DimensionMismatch on length mismatch" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws DimensionMismatch dominant_source(m, [a, b], [σa])
end
