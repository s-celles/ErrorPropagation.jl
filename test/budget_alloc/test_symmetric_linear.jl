@testitem "budget_allocation: symmetric linear sum gives B/3 (SC-005)" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb c σc
    m = propagate((x, y, z) -> x + y + z, [a ± σa, b ± σb, c ± σc])

    B = 1.0
    alloc = budget_allocation(m, [a, b, c], [σa, σb, σc], B)

    # Numeric round-trip — symbolic simplify does not reduce
    # B·(1/1²)/(3·1/1²) − B/3 to zero structurally; evaluate and
    # compare.
    σa_val = Float64(eval(Symbolics.toexpr(alloc[σa])))
    σb_val = Float64(eval(Symbolics.toexpr(alloc[σb])))
    σc_val = Float64(eval(Symbolics.toexpr(alloc[σc])))
    @test isapprox(σa_val, B / 3; atol = 1e-12)
    @test isapprox(σb_val, B / 3; atol = 1e-12)
    @test isapprox(σc_val, B / 3; atol = 1e-12)

    # Budget-sum invariant.
    @test isapprox(σa_val + σb_val + σc_val, B; atol = 1e-12)
end
