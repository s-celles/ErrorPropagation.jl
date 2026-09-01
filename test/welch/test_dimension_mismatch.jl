@testitem "welch_satterthwaite: DimensionMismatch on length mismatch" begin
    using SymbolicUncertainties
    using Symbolics

    @variables u1 u2 ν1
    @test_throws DimensionMismatch welch_satterthwaite([u1, u2], [ν1])
    @test_throws DimensionMismatch welch_satterthwaite([u1], [ν1, u2])
end
