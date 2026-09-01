@testitem "Gallery: torque transducer calibration, M = F·L" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # A torque transducer is calibrated by hanging a known mass on a
    # lever arm: M = F·L, with F = m·g the force at the end of an arm
    # of length L. Two inputs, one product — the simplest complete
    # calibration there is, and the one where the relative form of
    # JCGM 100:2008 §5.1.6 equation (12) is exact rather than an
    # approximation.
    @variables F σF L σL

    M = SymbolicMeasurement(F, σF) * SymbolicMeasurement(L, σL)

    # For a product the relative uncertainties add in quadrature:
    # u(M)/M = √((u(F)/F)² + (u(L)/L)²), JCGM 100:2008 §5.1.6
    # equation (12). The identity holds for positive F and L, and is
    # asserted numerically rather than symbolically: proving
    # √(L²σF² + F²σL²) = |FL|·√((σF/F)² + (σL/L)²) needs to know the
    # signs, and `Symbolics` has no way to be told (upstream-bugs.md
    # UB-003). This is the same gap that keeps `sqrt(σ²)` from
    # reducing to σ.
    relative = sqrt((σF / F)^2 + (σL / L)^2)

    # A 10 kg mass on a 0.5 m arm: F = 98.0665 N with u = 0.0015 N
    # (mass and g), L = 0.500 m with u = 0.00005 m.
    vals = Dict(F => 98.0665, σF => 0.0015, L => 0.500, σL => 0.00005)

    @test isapprox(_as_float(M.val, vals), 49.03325; rtol = 1e-9)

    expected = 49.03325 * sqrt((0.0015 / 98.0665)^2 + (0.00005 / 0.500)^2)
    @test isapprox(_as_float(M.err, vals), expected; rtol = 1e-9)

    # The relative form agrees at several operating points, which is
    # what "identity" means here in the absence of a symbolic proof.
    for (f, l) in [(98.0665, 0.5), (10.0, 2.0), (250.0, 0.125)]
        pt = Dict(F => f, σF => 0.0015, L => l, σL => 0.00005)
        @test isapprox(
            _as_float(M.err, pt),
            abs(f * l) * _as_float(relative, pt);
            rtol = 1e-12,
        )
    end

    # The lever arm dominates: its relative uncertainty is 1e-4
    # against 1.5e-5 for the force. A budget says which to improve,
    # and this is the whole point of computing one.
    rows = uncertainty_budget(M)
    contributions =
        Dict(r.name => _as_float(r.contribution, vals) for r in rows)
    @test contributions[:L] > 5 * contributions[:F]

    # Halving the arm's uncertainty nearly halves u_c; halving the
    # force's barely moves it. The symbolic form answers that without
    # re-running anything.
    better_arm = Dict(vals..., σL => 0.000025)
    better_force = Dict(vals..., σF => 0.00075)
    @test _as_float(M.err, better_arm) < 0.6 * _as_float(M.err, vals)
    @test _as_float(M.err, better_force) > 0.99 * _as_float(M.err, vals)
end
