@testitem "SymbolicUncertaintiesLatexifyExt: numeric measurement" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify

    m = 5.0 ± 0.1
    s = latex(m)

    @test s isa AbstractString
    @test occursin("\\pm", s)
    @test occursin("5", s)
    @test occursin("0.1", s)
end
