@testitem "SymbolicMeasurement construction promotes numeric literals" begin
    using SymbolicUncertainties
    using Symbolics

    m = SymbolicMeasurement(1.5, 0.1)

    @test m isa SymbolicMeasurement
    @test m.val isa Symbolics.Num
    @test m.err isa Symbolics.Num
    @test m.dof === nothing

    # Substituting nothing into constant expressions must return the
    # original numeric literals.
    @test Symbolics.value(m.val) == 1.5
    @test Symbolics.value(m.err) == 0.1
end
