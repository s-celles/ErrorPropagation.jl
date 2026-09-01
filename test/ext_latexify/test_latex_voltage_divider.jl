@testitem "SymbolicUncertaintiesLatexifyExt: voltage divider" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify
    using Logging

    @variables V σV R1 σR1 R2 σR2
    Vout = Logging.with_logger(Logging.NullLogger()) do
        propagate((v, r1, r2) -> v * r2 / (r1 + r2), [V ± σV, R1 ± σR1, R2 ± σR2])
    end
    s = latex(Vout)

    @test s isa AbstractString
    @test !isempty(s)
    @test occursin("\\pm", s)
end
