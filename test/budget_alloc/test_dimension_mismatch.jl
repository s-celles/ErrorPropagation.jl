@testitem "budget_allocation: DimensionMismatch on length mismatch" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws DimensionMismatch budget_allocation(m, [a, b], [σa], 1.0)
end

@testitem "budget_allocation: negative budget raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws ArgumentError budget_allocation(m, [a, b], [σa, σb], -0.1)
end
