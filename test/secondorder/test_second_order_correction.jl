@testitem "Amd.1:2026 §4.1.4 NOTE 1: a linear model needs no correction" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa
    m = a ± σa
    δ = second_order_correction(x -> 2x + 3, [m])
    @test isequal(Symbolics.value(Symbolics.simplify(δ)), 0)
end

@testitem "Amd.1:2026 §4.1.4 NOTE 1: the correction is ½Σ∂²f/∂xᵢ²·u²(xᵢ)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa
    m = a ± σa
    vals = Dict(a => 3.0, σa => 0.1)

    # f = x²: ∂²f/∂x² = 2, so the correction is ½·2·u² = u².
    # It is also exactly right: E[X²] = μ² + σ².
    δ = second_order_correction(x -> x^2, [m])
    @test isapprox(_as_float(δ, vals), 0.1^2; rtol = 1e-9)

    # f = exp(x): ½·exp(μ)·σ².
    δe = second_order_correction(exp, [m])
    @test isapprox(_as_float(δe, vals), 0.5 * exp(3.0) * 0.01; rtol = 1e-9)
end

@testitem "Amd.1:2026: independent inputs ignore mixed partials" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # NOTE 1 sums only the ∂²f/∂xᵢ² terms. A product of INDEPENDENT
    # inputs has a zero Hessian diagonal, so its estimate needs no
    # correction — E[AB] = E[A]E[B] when A and B are independent.
    @variables a σa b σb
    δ = second_order_correction(*, [a ± σa, b ± σb])
    @test isequal(Symbolics.value(Symbolics.simplify(δ)), 0)
end

@testitem "Amd.1:2026 (H.10): correlated inputs bring the mixed term back" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # Equation (H.10) generalises NOTE 1 to non-independent inputs:
    #   δy = ½ ΣᵢΣⱼ (∂²f/∂xᵢ∂xⱼ)·u(xᵢ,xⱼ)
    # For a product, ∂²f/∂a∂b = 1 and the double sum counts the pair
    # twice, so δ = cov(a,b) — which is exactly E[AB] − E[A]E[B].
    @variables a σa b σb ρ
    ma, mb = declare_correlated(a ± σa, b ± σb, ρ)
    δ = second_order_correction(*, [ma, mb])

    vals = Dict(a => 2.0, σa => 0.1, b => 3.0, σb => 0.2, ρ => 0.5)
    @test isapprox(_as_float(δ, vals), 0.5 * 0.1 * 0.2; rtol = 1e-9)
end

@testitem "Amd.1:2026 §H.1.7: the end-gauge estimate is unaffected" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The amendment states of §H.1 that "the first expression given in
    # note 1 to 4.1.4 is equal to zero, so that the estimate l is
    # unaffected by higher-order terms". An external check of the
    # implementation against the amendment's own claim.
    @variables ls σls d σd αs σαs θ σθ δα σδα δθ σδθ

    f = (l_s, dd, a_s, tt, da, dt) -> l_s + dd - l_s * (da * tt + a_s * dt)
    ms = [ls ± σls, d ± σd, αs ± σαs, θ ± σθ, δα ± σδα, δθ ± σδθ]

    vals = Dict(
        ls => 50.000623e6,
        σls => 25.0,
        d => 215.0,
        σd => 9.7,
        αs => 11.5e-6,
        σαs => 1.2e-6,
        θ => -0.1,
        σθ => 0.41,
        δα => 0.0,
        σδα => 0.58e-6,
        δθ => 0.0,
        σδθ => 0.029,
    )

    δ = second_order_correction(f, ms)
    @test isapprox(_as_float(δ, vals), 0.0; atol = 1e-12)
end
