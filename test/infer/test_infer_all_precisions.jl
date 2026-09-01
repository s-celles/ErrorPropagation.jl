@testitem "infer_all_precisions: row count matches sigmas" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    table = infer_all_precisions(m, [a, b], [σa, σb], 0.01)
    @test length(table) == 2
    @test haskey(table, σa)
    @test haskey(table, σb)
end

@testitem "infer_all_precisions: Ohm's law numeric" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables V I σV σI
    R_m = Logging.with_logger(Logging.NullLogger()) do
        propagate((v, i) -> v / i, [V ± σV, I ± σI])
    end

    table = infer_all_precisions(R_m, [V, I], [σV, σI], 0.01)

    # σV* = 0.01 / |1/I|. Substituting I = 0.5 gives σV* = 0.005.
    σV_sub =
        Symbolics.substitute(table[σV], Dict(V => 5.0, I => 0.5, σI => 0.001))
    @test isapprox(Float64(eval(Symbolics.toexpr(σV_sub))), 0.005; atol = 1e-12)

    # σI* = 0.01 / |V/I²|. With V=5, I=0.5: |5/0.25|=20, so σI*=0.01/20=0.0005.
    σI_sub =
        Symbolics.substitute(table[σI], Dict(V => 5.0, I => 0.5, σI => 0.001))
    @test isapprox(
        Float64(eval(Symbolics.toexpr(σI_sub))),
        0.0005;
        atol = 1e-12,
    )
end

@testitem "infer_all_precisions: DimensionMismatch on length mismatch" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws DimensionMismatch infer_all_precisions(m, [a, b], [σa], 0.01)
end

@testitem "infer_all_precisions: negative target raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    @test_throws ArgumentError infer_all_precisions(m, [a, b], [σa, σb], -0.01)
end
