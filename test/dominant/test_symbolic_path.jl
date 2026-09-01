@testitem "dominant_source: symbolic path returns first variable + @info" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    dom = @test_logs (:info, r"order-dependent") dominant_source(
        m,
        [a, b],
        [σa, σb],
    )
    @test dom.index == 1
    @test Symbolics.isequal(dom.variable, a)
    @test dom.ranked_by == :symbolic
end
