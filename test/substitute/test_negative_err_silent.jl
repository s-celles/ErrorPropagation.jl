@testitem "substitute: negative substituted err is silent (Clarifications Q3)" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # Contrive a case where the substituted err becomes negative.
    # Build a measurement by hand whose err field is the symbolic
    # expression `s`. Then substitute s => -0.3 and verify no error
    # and no warning.
    @variables x s
    m = SymbolicMeasurement(x, s)

    # No error should be thrown, no warning should be emitted.
    result = @test_logs min_level = Logging.Warn substitute(
        m,
        Dict(x => 5.0, s => -0.3),
    )
    @test Symbolics.value(result.err) == -0.3
end
