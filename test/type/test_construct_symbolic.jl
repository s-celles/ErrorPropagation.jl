@testitem "SymbolicMeasurement construction from Num operands" begin
    using SymbolicUncertainties
    using Symbolics

    @variables V σV
    m = SymbolicMeasurement(V, σV)

    @test m isa SymbolicMeasurement
    @test Symbolics.isequal(m.val, V)
    @test Symbolics.isequal(m.err, σV)
    @test m.dof === nothing
end
