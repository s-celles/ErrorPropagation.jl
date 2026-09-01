@testitem "budget_allocation: all-zero sensitivities raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb z σz
    # Measurement does not depend on z or σz.
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # Query with a single variable that does not appear in m → every
    # sensitivity coefficient is zero → ArgumentError.
    @test_throws ArgumentError budget_allocation(m, [z], [σz], 1.0)
end
