@testitem "check_linearity: linear measurement yields η = 0" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables x σx
    # f(x) = 2x + 3 → ∂²f/∂x² = 0, so η = 0.
    η = Logging.with_logger(Logging.NullLogger()) do
        check_linearity(a -> 2a + 3, [x ± σx])
    end

    @test haskey(η, σx)
    @test Symbolics.isequal(Symbolics.simplify(η[σx]), 0)
end
