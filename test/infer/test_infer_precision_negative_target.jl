@testitem "infer_precision: negative target raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws ArgumentError infer_precision(m, σa, -0.01)
    @test_throws ArgumentError infer_precision(m, σa, -1.0)
end
