@testitem "build_evaluator: Ohm's-law Julia callable (SC-002)" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables V I σV σI
    R_m = Logging.with_logger(Logging.NullLogger()) do
        (V ± σV) / (I ± σI)
    end

    g = build_evaluator(R_m, [V, I, σV, σI])
    @test g isa Function

    result = g(5.0, 0.5, 0.01, 0.001)
    @test result isa Tuple
    @test length(result) == 2

    val, err = result
    @test isapprox(val, 10.0; atol = 1e-12)
    # err = sqrt((σV/I)² + (V·σI/I²)²)
    #     = sqrt((0.01/0.5)² + (5·0.001/0.25)²)
    #     = sqrt(0.02² + 0.02²) = sqrt(2)·0.02 ≈ 0.028284271247461903
    @test isapprox(err, sqrt(2) * 0.02; atol = 1e-12)
end

@testitem "build_evaluator: two-input linear sum" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])
    g = build_evaluator(m, [a, b, σa, σb])

    val, err = g(2.0, 3.0, 0.1, 0.2)
    @test isapprox(val, 5.0; atol = 1e-12)
    @test isapprox(err, sqrt(0.01 + 0.04); atol = 1e-12)
end
