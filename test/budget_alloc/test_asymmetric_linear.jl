@testitem "budget_allocation: asymmetric linear stationarity" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    # m = 2a + 3b → cₐ=2, c_b=3. Stationarity:
    # cₐ²·σₐ = c_b²·σ_b ⇒ 4·σₐ = 9·σ_b.
    m = propagate((x, y) -> 2x + 3y, [a ± σa, b ± σb])

    B = 1.0
    alloc = budget_allocation(m, [a, b], [σa, σb], B)

    ratio_a = Float64(eval(Symbolics.toexpr(alloc[σa])))
    ratio_b = Float64(eval(Symbolics.toexpr(alloc[σb])))

    # Check stationarity: 4·σa = 9·σb.
    @test isapprox(4 * ratio_a, 9 * ratio_b; atol = 1e-10)
    # Check budget constraint: σa + σb = B.
    @test isapprox(ratio_a + ratio_b, B; atol = 1e-10)
end
