@testitem "Gallery: interferometric displacement — the air, not the laser" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # A displacement interferometer counts fringes: d = N·λ/(2n),
    # where λ is the vacuum wavelength of a stabilised laser and n the
    # refractive index of the air the beam travels through.
    #
    # The tutorial's point is the one that decides where the money
    # goes in dimensional metrology: the laser is not the problem. A
    # stabilised HeNe is good to 1e-8 relative or better, while the
    # refractive index of air moves by about 1e-6 per °C and per
    # 300 Pa. The air beats the laser by four orders of magnitude, and
    # a budget says so before anyone buys a better laser.
    #
    # n is taken from the simplified Edlén form
    # (n − 1) = 2.8793e-9·P/(1 + 0.003661·T), P in Pa, T in °C.
    @variables N σN λ σλ T σT P σP

    Nm = SymbolicMeasurement(N, σN)
    λm = SymbolicMeasurement(λ, σλ)
    Tm = SymbolicMeasurement(T, σT)
    Pm = SymbolicMeasurement(P, σP)

    n = 1 + 2.8793e-9 * Pm / (1 + 0.003661 * Tm)
    d = Logging.with_logger(Logging.NullLogger()) do
        Nm * λm / (2 * n)
    end

    # One metre of travel: N ≈ 3.164e6 fringes at 632.991 nm, air at
    # 20 °C and 101325 Pa. Laser stabilised to 1e-8 relative, air
    # temperature to 0.1 °C, pressure to 50 Pa, fringe interpolation
    # to 0.01 fringe.
    λ0 = 632.99139e-9
    n0 = 1 + 2.8793e-9 * 101325 / (1 + 0.003661 * 20.0)
    N0 = 2 * n0 * 1.0 / λ0

    vals = Dict(
        N => N0,
        σN => 0.01,
        λ => λ0,
        σλ => λ0 * 1e-8,
        T => 20.0,
        σT => 0.1,
        P => 101325.0,
        σP => 50.0,
    )

    @test isapprox(_as_float(d.val, vals), 1.0; rtol = 1e-9)
    @test isapprox(n0, 1.000271; rtol = 1e-4)

    contribs = Dict(
        r.name => _as_float(r.contribution, vals) for
        r in uncertainty_budget(d)
    )

    # Air temperature: relative sensitivity is
    # (n−1)·0.003661/(1 + 0.003661·T) ≈ 9.3e-7 per °C, so 0.1 °C is
    # worth about 93 nm over a metre.
    @test isapprox(contribs[:T], 9.27e-8; rtol = 5e-2)

    # Air pressure: (n−1)/P ≈ 2.68e-9 per Pa, so 50 Pa is ~134 nm.
    @test isapprox(contribs[:P], 1.34e-7; rtol = 5e-2)

    # The laser: 1e-8 relative over a metre is 10 nm.
    @test isapprox(contribs[:λ], 1.0e-8; rtol = 1e-2)

    # So the air beats the laser by an order of magnitude even at
    # 0.1 °C and 50 Pa — and by four if the environment is merely
    # "room conditions", 1 °C and 300 Pa.
    @test contribs[:T] > 5 * contribs[:λ]
    @test contribs[:P] > 10 * contribs[:λ]

    loose = merge(vals, Dict(σT => 1.0, σP => 300.0))
    @test _as_float(d.err, loose) > 5 * _as_float(d.err, vals)

    # A ten-times better laser changes nothing measurable.
    better_laser = merge(vals, Dict(σλ => λ0 * 1e-9))
    @test _as_float(d.err, better_laser) > 0.995 * _as_float(d.err, vals)
end
