@testitem "SymbolicUncertaintiesMeasurementsExt: rejects symbolic" begin
    using SymbolicUncertainties
    using Symbolics
    using Measurements
    using SymbolicUncertainties: ±

    @variables x σx
    m = x ± σx   # still symbolic

    @test_throws ArgumentError Measurements.Measurement(m)
end
