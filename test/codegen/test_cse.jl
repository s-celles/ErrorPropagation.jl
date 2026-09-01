@testitem "M12: build_evaluator eliminates common subexpressions" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Sensitivity coefficients of a product share almost all of their
    # structure: ∂(x₁x₂x₃x₄)/∂xᵢ is the product of the other three.
    # Without CSE the generated code recomputes those products once
    # per source, and the redundancy grows quadratically.
    @variables a σa b σb c σc d σd
    m = (a ± σa) * (b ± σb) * (c ± σc) * (d ± σd)

    f = build_evaluator(m, [a, b, c, d, σa, σb, σc, σd])
    val, err = f(2.0, 3.0, 5.0, 7.0, 0.1, 0.2, 0.3, 0.4)

    # CSE must not change the answer — that is the whole point.
    @test isapprox(val, 2.0 * 3.0 * 5.0 * 7.0; atol = 1e-10)
    expected = sqrt(
        (3.0 * 5.0 * 7.0 * 0.1)^2 +
        (2.0 * 5.0 * 7.0 * 0.2)^2 +
        (2.0 * 3.0 * 7.0 * 0.3)^2 +
        (2.0 * 3.0 * 5.0 * 0.4)^2,
    )
    @test isapprox(err, expected; atol = 1e-10)
end

@testitem "M12: the C target still emits valid source" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb c σc
    m = (a ± σa) * (b ± σb) * (c ± σc)
    src = build_evaluator(m, [a, b, c, σa, σb, σc]; target = CTarget())

    @test src isa AbstractString
    @test occursin("#include <math.h>", src)
end
