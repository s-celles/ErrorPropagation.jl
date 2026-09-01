@testitem "safety: propagate with division by symbolic denominator warns" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb
    @test_logs (:warn, r"REQ-140") propagate((x, y) -> x / y, [a ± σa, b ± σb])
end

@testitem "safety: propagate with division by concrete nonzero does not warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables a σa
    # b as a plain number literal — the division inside f produces
    # `a / 2.0`, whose denominator is a concrete Float64.
    @test_logs min_level = Logging.Warn propagate((x,) -> x / 2.0, [a ± σa])
end
