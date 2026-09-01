@testitem "budget_allocation: zero budget yields all zeros" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    alloc = budget_allocation(m, [a, b], [σa, σb], 0)
    @test Symbolics.isequal(Symbolics.simplify(alloc[σa]), 0)
    @test Symbolics.isequal(Symbolics.simplify(alloc[σb]), 0)
end
