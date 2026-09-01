@testitem "SymbolicUncertaintiesLatexifyExt: basic rendering" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify

    @variables x σx
    m = x ± σx
    s = latex(m)

    @test s isa AbstractString
    @test occursin("\\pm", s)
end
