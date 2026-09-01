@testitem "Gallery: Wheatstone bridge with matched ratio arms" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # At balance a Wheatstone bridge gives Rx = R3·(R1/R2), where R1
    # and R2 are the ratio arms and R3 the standard.
    #
    # The tutorial's point is a result that surprises people: a
    # MATCHED PAIR of ratio arms is far better than two independent
    # resistors of the same tolerance, and the budget only says so if
    # the correlation is declared. R1 and R2 enter as a ratio, so a
    # positive correlation between them cancels — the same mechanism
    # as JCGM 100:2008 §H.4, where correlated counting rates reduce
    # the combined uncertainty.
    @variables R1 σR1 R2 σR2 R3 σR3

    independent = Logging.with_logger(Logging.NullLogger()) do
        SymbolicMeasurement(R3, σR3) *
        (SymbolicMeasurement(R1, σR1) / SymbolicMeasurement(R2, σR2))
    end

    a, b = declare_correlated(
        SymbolicMeasurement(R1, σR1),
        SymbolicMeasurement(R2, σR2),
        0.9,
    )
    matched = Logging.with_logger(Logging.NullLogger()) do
        SymbolicMeasurement(R3, σR3) * (a / b)
    end

    # Two 1 kΩ arms at 0.1 % and a 100 Ω standard at 0.01 %.
    vals = Dict(
        R1 => 1000.0,
        σR1 => 1.0,
        R2 => 1000.0,
        σR2 => 1.0,
        R3 => 100.0,
        σR3 => 0.01,
    )

    @test isapprox(_as_float(independent.val, vals), 100.0; rtol = 1e-12)
    @test isapprox(_as_float(matched.val, vals), 100.0; rtol = 1e-12)

    u_ind = _as_float(independent.err, vals)
    u_mat = _as_float(matched.err, vals)

    # Independent arms: the two 0.1 % arm tolerances add in
    # quadrature with the standard's 0.01 %, which is small but not
    # absent — writing √2·0.1 % here would be asserting the model I
    # meant rather than the one I built.
    @test isapprox(
        u_ind,
        100.0 * sqrt((1.0 / 1000)^2 + (1.0 / 1000)^2 + (0.01 / 100)^2);
        rtol = 1e-9,
    )

    # Matched at ρ = 0.9: √(2 − 2ρ) = 0.447, so the ratio's
    # contribution falls by more than half.
    @test u_mat < 0.5 * u_ind

    # Perfectly matched arms of equal relative tolerance contribute
    # NOTHING: the ratio is exactly one whatever the common error.
    # Only the standard is left, which is the reason bridges are built
    # this way.
    c, d = declare_correlated(
        SymbolicMeasurement(R1, σR1),
        SymbolicMeasurement(R2, σR2),
        1.0,
    )
    perfect = Logging.with_logger(Logging.NullLogger()) do
        SymbolicMeasurement(R3, σR3) * (c / d)
    end
    @test isapprox(_as_float(perfect.err, vals), 100.0 * 1.0e-4; rtol = 1e-6)

    # Which is exactly the standard's own relative uncertainty carried
    # through — nothing else survives.
    @test isapprox(
        _as_float(perfect.err, vals) / 100.0,
        0.01 / 100.0;
        rtol = 1e-9,
    )
end
