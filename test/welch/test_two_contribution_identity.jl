@testitem "welch_satterthwaite: two-contribution identity (symbolic)" begin
    using SymbolicUncertainties
    using Symbolics

    @variables u1 u2 ν1 ν2
    ν_eff = welch_satterthwaite([u1, u2], [ν1, ν2])

    # Expected: (u1² + u2²)² / (u1⁴/ν1 + u2⁴/ν2)  — GUM §G.4 eq (G.2b)
    expected = (u1^2 + u2^2)^2 / (u1^4 / ν1 + u2^4 / ν2)
    @test Symbolics.isequal(Symbolics.simplify(ν_eff - expected), 0)
end

@testitem "welch_satterthwaite: two-contribution identity (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables u1 u2 ν1 ν2
    ν_eff = welch_satterthwaite([u1, u2], [ν1, ν2])

    dict = Dict(u1 => 0.1, u2 => 0.2, ν1 => 10.0, ν2 => 5.0)
    # (0.01 + 0.04)^2 / (0.0001/10 + 0.0016/5)
    # = 0.0025 / (0.00001 + 0.00032) = 0.0025 / 0.00033 ≈ 7.575757...
    @test isapprox(_as_float(ν_eff, dict), 7.575757575757575; atol = 1e-10)
end
