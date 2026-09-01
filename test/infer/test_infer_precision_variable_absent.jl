@testitem "infer_precision: σᵢ not in m.err raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa z σz
    m = a ± σa   # measurand does not depend on σz

    @test_throws ArgumentError infer_precision(m, σz, 0.01)
end
