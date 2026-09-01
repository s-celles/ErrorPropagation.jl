@testitem "uncertainty_budget: DimensionMismatch on length mismatch" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # 2 variables, 1 sigma — mismatch.
    @test_throws DimensionMismatch uncertainty_budget(m, [a, b], [σa])

    # 1 variable, 2 sigmas — mismatch.
    @test_throws DimensionMismatch uncertainty_budget(m, [a], [σa, σb])
end

@testitem "uncertainty_budget: empty inputs returns empty table" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa
    m = a ± σa

    budget = uncertainty_budget(m, Symbolics.Num[], Symbolics.Num[])
    @test length(budget) == 0
end
