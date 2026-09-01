@testitem "binary operators are type stable" begin
    using SymbolicUncertainties
    using Symbolics
    using Test: @inferred

    @variables a σa b σb
    x = SymbolicMeasurement(a, σa)
    y = SymbolicMeasurement(b, σb)

    @test (@inferred x + y) isa SymbolicMeasurement
    @test (@inferred x - y) isa SymbolicMeasurement
    @test (@inferred x * y) isa SymbolicMeasurement
    @test (@inferred x / y) isa SymbolicMeasurement
    @test (@inferred x^2) isa SymbolicMeasurement

    # Mixed-mode: SymbolicMeasurement ∘ Number must also be type stable.
    @test (@inferred x * 2) isa SymbolicMeasurement
end
