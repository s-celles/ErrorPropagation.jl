@testitem "welch_satterthwaite: three-contribution identity (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables u1 u2 u3 ν1 ν2 ν3
    ν_eff = welch_satterthwaite([u1, u2, u3], [ν1, ν2, ν3])

    dict =
        Dict(u1 => 0.1, u2 => 0.2, u3 => 0.3, ν1 => 10.0, ν2 => 5.0, ν3 => 20.0)
    # Numerator: (u1² + u2² + u3²)² = (0.01 + 0.04 + 0.09)² = 0.14² = 0.0196
    # Denom: u1⁴/ν1 + u2⁴/ν2 + u3⁴/ν3
    #      = 0.0001/10 + 0.0016/5 + 0.0081/20
    #      = 0.00001 + 0.00032 + 0.000405 = 0.000735
    # ν_eff = 0.0196 / 0.000735 ≈ 26.66666...
    @test isapprox(_as_float(ν_eff, dict), 26.66666666666667; atol = 1e-10)
end
