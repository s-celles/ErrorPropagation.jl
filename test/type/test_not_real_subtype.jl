@testitem "SymbolicMeasurement is not part of the numeric tower" begin
    using SymbolicUncertainties

    @test !(SymbolicMeasurement <: Real)
    @test !(SymbolicMeasurement <: AbstractFloat)
    @test !(SymbolicMeasurement <: Number)

    # Promotion must not conflate SymbolicMeasurement with Float64.
    @test Base.promote_type(SymbolicMeasurement, Float64) !==
          SymbolicMeasurement
end
