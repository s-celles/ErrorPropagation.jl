@testitem "build_evaluator: empty variables on fully numeric measurement" begin
    using SymbolicUncertainties
    using Symbolics

    m = 5.0 ± 0.1
    g = build_evaluator(m, Symbolics.Num[])
    @test g isa Function

    result = g()
    @test result isa Tuple
    @test isapprox(result[1], 5.0; atol = 1e-12)
    @test isapprox(result[2], 0.1; atol = 1e-12)
end
