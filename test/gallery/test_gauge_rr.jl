@testitem "Gallery: gauge R&R meets the GUM — where ISO 5725 stops" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # A gauge R&R study decomposes the OBSERVED scatter of a
    # measurement process into repeatability (the equipment) and
    # reproducibility (the operators), by analysis of variance. It is
    # the ISO 5725 / MSA answer to "is this process capable?".
    #
    # The tutorial's point is where that answer stops. R&R yields
    # Type A components only — what the experiment happened to show.
    # A GUM budget must still carry the Type B terms that no repeat
    # measurement can reveal, because they do not vary between
    # repeats: the calibration of the reference, the instrument's
    # finite resolution, a systematic temperature offset. A process
    # judged acceptable on %R&R alone can be inadequate against a
    # tolerance once those are added.
    @variables sr σsr so σso scal σscal sres σsres

    # ν: 10 parts × 3 operators × 2 trials. Repeatability has
    # 30 degrees of freedom, reproducibility only 2 — three operators.
    repeat_ = SymbolicMeasurement(sr, σsr, Symbolics.Num(30.0))
    operator = SymbolicMeasurement(so, σso, Symbolics.Num(2.0))
    calibration = SymbolicMeasurement(scal, σscal, Symbolics.Num(1.0e12))
    resolution = SymbolicMeasurement(sres, σsres, Symbolics.Num(1.0e12))

    # The measurand is a deviation, so the components combine as a sum
    # of zero-mean corrections: the estimate is zero and every source
    # enters with unit sensitivity.
    combined = repeat_ + operator + calibration + resolution

    # Figures in micrometres. A 0.5 µm resolution enters as a
    # rectangular half-width, u = a/√3 (JCGM 100:2008 §4.3.7).
    vals = Dict(
        sr => 0.0,
        σsr => 0.8,
        so => 0.0,
        σso => 0.6,
        scal => 0.0,
        σscal => 0.35,
        sres => 0.0,
        σsres => 0.25 / sqrt(3),
    )

    rr_only = sqrt(0.8^2 + 0.6^2)                    # what R&R reports
    u_c = _as_float(combined.err, vals)

    @test isapprox(rr_only, 1.0; rtol = 1e-9)
    @test isapprox(
        u_c,
        sqrt(0.8^2 + 0.6^2 + 0.35^2 + (0.25 / sqrt(3))^2);
        rtol = 1e-9,
    )

    # The Type B terms add about 7 % here — modest, but they are
    # invisible to the study that produced the 1.0 µm figure, and a
    # conformity decision made on that figure is made on the wrong
    # number.
    @test u_c > rr_only
    @test u_c < 1.2 * rr_only

    # The sharper consequence is the coverage factor. Reproducibility
    # carries two degrees of freedom, and Welch-Satterthwaite lets
    # that dominate: ν_eff falls far below the naive 30, so k is
    # noticeably larger than 2 (JCGM 100:2008 §G.4).
    # ν_eff = u_c⁴ / Σ(uᵢ⁴/νᵢ) = 1.307 / 0.0785 ≈ 16.7: well below
    # the repeatability term's own 30, pulled down by the operator
    # term's two, and far above that two because the operator term is
    # not the largest contribution. Asserted against the formula
    # rather than a threshold picked by eye.
    ν_eff = _as_float(combined.dof, vals)
    expected_ν =
        (0.8^2 + 0.6^2 + 0.35^2 + (0.25 / sqrt(3))^2)^2 /
        (0.8^4 / 30 + 0.6^4 / 2)
    @test isapprox(ν_eff, expected_ν; rtol = 1e-6)
    @test ν_eff < 20.0
    @test ν_eff > 2.0

    U = Logging.with_logger(Logging.NullLogger()) do
        expanded_uncertainty(combined; coverage_probability = 0.95)
    end
    k = _as_float(U.k, vals)
    @test k > 2.1

    # Three operators is what makes k large. Ten would not change u_c
    # much, and would change the interval a lot — which is an
    # experiment-design conclusion the budget hands you for free.
    more_operators = SymbolicMeasurement(so, σso, Symbolics.Num(9.0))
    with_more = repeat_ + more_operators + calibration + resolution
    @test _as_float(with_more.dof, vals) > 1.5 * ν_eff
    U2 = Logging.with_logger(Logging.NullLogger()) do
        expanded_uncertainty(with_more; coverage_probability = 0.95)
    end
    @test _as_float(U2.k, vals) < k
end
