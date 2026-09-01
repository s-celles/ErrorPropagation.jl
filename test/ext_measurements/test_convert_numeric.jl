@testitem "SymbolicUncertaintiesMeasurementsExt: numeric conversion" begin
    using SymbolicUncertainties
    using Symbolics
    using Measurements
    using SymbolicUncertainties: ±

    m = 5.0 ± 0.1
    meas = Measurements.Measurement(m)

    @test meas isa Measurements.Measurement
    @test isapprox(Measurements.value(meas), 5.0; atol = 1e-12)
    @test isapprox(Measurements.uncertainty(meas), 0.1; atol = 1e-12)
end
