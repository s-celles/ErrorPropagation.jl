@testitem "Gallery: Pt100 linearisation, Callendar–van Dusen" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # A platinum resistance thermometer is defined the wrong way round
    # for a user: the standard gives resistance as a function of
    # temperature, R(t) = R₀(1 + A·t + B·t²) for t ≥ 0 (IEC 60751),
    # while the measurand is the temperature. The model is therefore
    # the INVERSE, and its sensitivity coefficient is the reciprocal
    # of the direct relation's slope:
    #
    #   ∂t/∂R = 1 / (R₀·(A + 2B·t))
    #
    # Because B is negative, that slope falls as the temperature
    # rises: the same resistance uncertainty buys a worse temperature
    # at 600 °C than at 0 °C. A budget computed once at one point does
    # not describe the instrument.
    @variables R σR R0 σR0

    A = 3.9083e-3
    B = -5.775e-7

    Rm = SymbolicMeasurement(R, σR)
    R0m = SymbolicMeasurement(R0, σR0)

    t = Logging.with_logger(Logging.NullLogger()) do
        (-A + sqrt(A^2 - 4B * (1 - Rm / R0m))) / (2B)
    end

    # Sanity: R = R₀ must give exactly 0 °C, and the IEC 60751 table
    # value at 100 °C is 138.5055 Ω.
    at0 = Dict(R => 100.0, σR => 0.01, R0 => 100.0, σR0 => 0.01)
    @test isapprox(_as_float(t.val, at0), 0.0; atol = 1e-9)

    R_100 = 100.0 * (1 + A * 100 - 5.775e-7 * 100^2)
    @test isapprox(R_100, 138.5055; rtol = 1e-6)
    at100 = Dict(R => R_100, σR => 0.01, R0 => 100.0, σR0 => 0.01)
    @test isapprox(_as_float(t.val, at100), 100.0; rtol = 1e-6)

    R_600 = 100.0 * (1 + A * 600 - 5.775e-7 * 600^2)
    at600 = Dict(R => R_600, σR => 0.01, R0 => 100.0, σR0 => 0.01)
    @test isapprox(_as_float(t.val, at600), 600.0; rtol = 1e-6)

    # 10 mΩ of resistance uncertainty is worth about 26 m°C at 0 °C
    # and appreciably more at 600 °C, because dR/dt has fallen from
    # 0.391 Ω/°C to 0.322 Ω/°C.
    u0 = _as_float(t.err, at0)
    u600 = _as_float(t.err, at600)

    # At t = 0 the sensitivities to R and to R₀ are equal and
    # opposite — the model depends on the ratio R/R₀ — so the two
    # 10 mΩ contributions combine to √2 times either one. Asserting
    # only R's would state half the model.
    single = 0.01 / (100.0 * A)
    @test isapprox(u0, sqrt(2) * single; rtol = 5e-2)
    @test u600 > 1.1 * u0

    # And the sensitivity coefficient is the reciprocal slope, which
    # the package derives rather than being told.
    c = sensitivity_coefficient(t, R)
    @test isapprox(
        _as_float(c, at600),
        1 / (100.0 * (A + 2B * 600));
        rtol = 1e-6,
    )

    # R₀ matters as much as R at low temperature — the two enter the
    # ratio R/R₀ — but its influence grows differently with t, so the
    # budget's ranking is not fixed either.
    rows0 = Dict(
        r.name => _as_float(r.contribution, at0) for r in uncertainty_budget(t)
    )
    @test isapprox(rows0[:R], rows0[:R0]; rtol = 1e-6)
end
