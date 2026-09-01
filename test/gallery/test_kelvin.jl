@testitem "Gallery: four-wire Kelvin measurement of a low-value resistor" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # Measuring a milliohm resistor two-wire fails: the lead
    # resistance is comparable to the resistand itself. Four-wire
    # separates current injection from voltage sensing, so what is
    # left is R = V/I with V measured across the resistor alone.
    #
    # The tutorial's point is the comparison between the two models:
    # the systematic error a two-wire measurement carries is not an
    # uncertainty at all, and no uncertainty budget will reveal it.
    @variables V σV I σI Rl σRl

    v = SymbolicMeasurement(V, σV)
    i = SymbolicMeasurement(I, σI)
    lead = SymbolicMeasurement(Rl, σRl)

    four_wire = Logging.with_logger(Logging.NullLogger()) do
        v / i
    end
    two_wire = Logging.with_logger(Logging.NullLogger()) do
        (v / i) - lead
    end

    # A 10 mΩ shunt at 1 A: V = 10 mV with u = 2 µV, I = 1.000 A with
    # u = 0.0005 A. Lead resistance 5 mΩ, known to 0.2 mΩ.
    vals = Dict(
        V => 10.0e-3,
        σV => 2.0e-6,
        I => 1.000,
        σI => 0.0005,
        Rl => 5.0e-3,
        σRl => 0.2e-3,
    )

    @test isapprox(_as_float(four_wire.val, vals), 10.0e-3; rtol = 1e-12)

    # Four-wire: the two contributions are the voltmeter and the
    # current, in quadrature.
    expected = 10.0e-3 * sqrt((2.0e-6 / 10.0e-3)^2 + (0.0005 / 1.000)^2)
    @test isapprox(_as_float(four_wire.err, vals), expected; rtol = 1e-9)

    # Correcting a two-wire reading for a *known* lead resistance
    # leaves that correction's own uncertainty in the budget, and it
    # dominates by two orders of magnitude: 0.2 mΩ against ~5 µΩ.
    @test _as_float(two_wire.err, vals) > 30 * _as_float(four_wire.err, vals)

    rows = uncertainty_budget(two_wire)
    contributions =
        Dict(r.name => _as_float(r.contribution, vals) for r in rows)
    @test contributions[:Rl] > 20 * contributions[:V]
    @test contributions[:Rl] > 20 * contributions[:I]

    # And the four-wire measurement carries no lead source at all —
    # not a small one. That is a structural difference between the two
    # measurement models, which the budget shows by the absence of a
    # row rather than by a small number.
    @test length(uncertainty_budget(four_wire)) == 2
    @test length(rows) == 3
    @test !(:Rl in Set(r.name for r in uncertainty_budget(four_wire)))
end
