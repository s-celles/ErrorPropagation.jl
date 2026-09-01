@testitem "SymbolicUncertaintiesMeasurementsExt: convert after substitute" begin
    using SymbolicUncertainties
    using Symbolics
    using Measurements
    using Logging
    using SymbolicUncertainties: ±

    @variables V I σV σI
    R_m = Logging.with_logger(Logging.NullLogger()) do
        (V ± σV) / (I ± σI)
    end
    subbed = Symbolics.substitute(
        R_m,
        Dict(V => 5.0, I => 0.5, σV => 0.01, σI => 0.001),
    )

    meas = Measurements.Measurement(subbed)
    @test meas isa Measurements.Measurement
    @test isapprox(Measurements.value(meas), 10.0; atol = 1e-12)
    # err = sqrt((0.01/0.5)² + (5·0.001/0.25)²) = sqrt(2)·0.02 ≈ 0.02828…
    @test isapprox(Measurements.uncertainty(meas), sqrt(2) * 0.02; atol = 1e-12)
end
