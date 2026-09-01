@testitem "expanded_uncertainty: small ν (<30) emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = SymbolicMeasurement(x, σx, Symbolics.Num(10))   # ν = 10

    # The @warn should reference the §6.3.3 threshold via the
    # words "ν_eff" and "30" in the message.
    @test_logs (:warn, r"ν_eff") expanded_uncertainty(
        m;
        coverage_probability = 0.95,
    )
end

@testitem "expanded_uncertainty: ν<1 raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = SymbolicMeasurement(x, σx, Symbolics.Num(0.5))

    @test_throws ArgumentError expanded_uncertainty(
        m;
        coverage_probability = 0.95,
    )
end
