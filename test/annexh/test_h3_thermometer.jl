@testitem "JCGM Annex H.3: thermometer calibration by linear fit" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # JCGM 100:2008 §H.3. A thermometer's correction is fitted as
    #
    #   b(t) = y₁ + y₂·(t − t₀),   t₀ = 20 °C
    #
    # The two fitted parameters are strongly anticorrelated,
    # r(y₁, y₂) = −0.930, because they come from the same
    # least-squares fit. This is the regime neither H.1 nor H.2
    # covers: correlation arising from an ADJUSTMENT rather than from
    # shared inputs or a declared physical link.
    @variables y1 σy1 y2 σy2

    c1, c2 = declare_correlated(y1 ± σy1, y2 ± σy2, -0.930)
    t0 = 20.0
    b(t) = c1 + c2 * ((t ± 0.0) - (t0 ± 0.0))

    vals = Dict(y1 => -0.1712, σy1 => 0.0029, y2 => 0.00218, σy2 => 0.000067)

    # Predicted corrections, §H.3.3.
    @test isapprox(_as_float(b(20.0).val, vals), -0.1712; rtol = 1e-6)
    @test isapprox(_as_float(b(30.0).val, vals), -0.1494; rtol = 1e-4)

    # At the reference temperature the second term vanishes, so the
    # prediction's uncertainty is exactly u(y₁). An exact property of
    # the model, independent of any transcribed figure.
    @test isapprox(_as_float(b(t0).err, vals), 0.0029; rtol = 1e-9)

    # Away from t₀ the anticorrelation REDUCES the uncertainty below
    # what independent parameters would give. That is the whole point
    # of §H.3, and ignoring the covariance would overstate it.
    u_correlated = _as_float(b(30.0).err, vals)
    u_independent = _as_float(
        ((y1 ± σy1) + (y2 ± σy2) * ((30.0 ± 0.0) - (t0 ± 0.0))).err,
        vals,
    )
    @test u_correlated < u_independent

    # Equation (13) written out for this model, as a check on the
    # propagation rather than on a published number:
    #   u² = u(y₁)² + (t−t₀)²u(y₂)² + 2(t−t₀)·r·u(y₁)u(y₂)
    Δ = 30.0 - t0
    expected =
        sqrt(0.0029^2 + Δ^2 * 0.000067^2 + 2 * Δ * (-0.930) * 0.0029 * 0.000067)
    @test isapprox(u_correlated, expected; rtol = 1e-9)
end
