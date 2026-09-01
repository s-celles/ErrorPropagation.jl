@testitem "REQ-204: independent sources reproduce JCGM eq. (10)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb
    x = a ± σa
    y = b ± σb
    dict = Dict(a => 3.0, σa => 0.2, b => 5.0, σb => 0.4)

    # Equation (10): u_c² = Σ (∂f/∂xᵢ)² u²(xᵢ). Each closed form below
    # is that sum written out for the operator in question.
    @test isapprox(
        _as_float((x + y).err, dict),
        sqrt(0.2^2 + 0.4^2);
        atol = 1e-12,
    )
    @test isapprox(
        _as_float((x - y).err, dict),
        sqrt(0.2^2 + 0.4^2);
        atol = 1e-12,
    )
    @test isapprox(
        _as_float((x * y).err, dict),
        sqrt((5.0 * 0.2)^2 + (3.0 * 0.4)^2);
        atol = 1e-12,
    )
    @test isapprox(
        _as_float((x / y).err, dict),
        sqrt((0.2 / 5.0)^2 + (3.0 * 0.4 / 5.0^2)^2);
        atol = 1e-12,
    )
    @test isapprox(
        _as_float((x^3).err, dict),
        abs(3 * 3.0^2) * 0.2;
        atol = 1e-12,
    )

    # Commutativity is now exact, not merely numerically equal: the
    # linear form is keyed by source, so operand order cannot change
    # the emitted expression.
    @test isequal((x + y).err, (y + x).err)
end
