@testitem "check_linearity: multi-input returns one entry per σ" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables V σV R σR
    η = Logging.with_logger(Logging.NullLogger()) do
        check_linearity((v, r) -> v^2 / r, [V ± σV, R ± σR])
    end

    @test length(η) == 2
    @test haskey(η, σV)
    @test haskey(η, σR)
end
