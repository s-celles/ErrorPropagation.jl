@testitem "Gallery: thermocouple with cold-junction compensation" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # A thermocouple measures a DIFFERENCE of temperatures. The
    # voltmeter sees the emf between the hot junction and whatever
    # temperature the terminals happen to be at, so the reading has to
    # be referred back to 0 °C before the ITS-90 relation can be
    # inverted:
    #
    #   E(T) = E_measured + E(T_cj)
    #
    # The tutorial's point is what that costs. The cold junction's
    # temperature uncertainty enters through the Seebeck coefficient
    # at the cold junction, and since that coefficient is comparable
    # to the one at the hot junction, a cold junction known to 0.5 °C
    # puts roughly 0.5 °C into the measurand — usually more than the
    # voltmeter does.
    #
    # The polynomial below has the ITS-90 form truncated to two terms.
    # It is illustrative of a type-K response, not the standard's full
    # coefficient set: the point being made is about the structure of
    # the model, and a truncated polynomial inverts in closed form.
    @variables E σE Tcj σTcj

    a1 = 39.45e-6      # V/°C
    a2 = 2.36e-8       # V/°C²

    Em = SymbolicMeasurement(E, σE)
    cj = SymbolicMeasurement(Tcj, σTcj)

    # emf of the cold junction relative to 0 °C, and the total
    E_cj = a1 * cj + a2 * cj * cj
    total = Em + E_cj

    # Invert E = a1·T + a2·T² for T ≥ 0.
    T = Logging.with_logger(Logging.NullLogger()) do
        (-a1 + sqrt(a1^2 + 4 * a2 * total)) / (2 * a2)
    end

    # A hot junction near 300 °C read on terminals at 25 °C.
    E_true(x) = a1 * x + a2 * x^2
    vals = Dict(
        E => E_true(300.0) - E_true(25.0),
        σE => 2.0e-6,          # 2 µV voltmeter
        Tcj => 25.0,
        σTcj => 0.5,           # 0.5 °C cold-junction sensor
    )

    @test isapprox(_as_float(T.val, vals), 300.0; rtol = 1e-6)

    contribs = Dict(
        r.name => _as_float(r.contribution, vals) for
        r in uncertainty_budget(T)
    )

    # The cold junction contributes about its own uncertainty scaled
    # by the ratio of Seebeck coefficients, S(T_cj)/S(T) — here
    # (a1 + 2a2·25)/(a1 + 2a2·300) ≈ 0.94, so ~0.47 °C.
    ratio = (a1 + 2 * a2 * 25.0) / (a1 + 2 * a2 * 300.0)
    @test isapprox(contribs[:Tcj], 0.5 * ratio; rtol = 1e-3)

    # The voltmeter's 2 µV is worth about 2e-6/S(300) ≈ 0.038 °C.
    @test isapprox(contribs[:E], 2.0e-6 / (a1 + 2 * a2 * 300.0); rtol = 1e-3)

    # So the cold junction dominates by an order of magnitude. Buying
    # a better voltmeter would be wasted money, and the budget is what
    # says so — before the money is spent.
    @test contribs[:Tcj] > 10 * contribs[:E]

    # Ten times better cold-junction sensing nearly divides u_c by
    # ten; ten times better voltage resolution barely moves it.
    better_cj = merge(vals, Dict(σTcj => 0.05))
    better_v = merge(vals, Dict(σE => 0.2e-6))
    @test _as_float(T.err, better_cj) < 0.2 * _as_float(T.err, vals)
    @test _as_float(T.err, better_v) > 0.99 * _as_float(T.err, vals)
end
