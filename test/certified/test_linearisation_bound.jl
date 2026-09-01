@testitem "M13: a linear model has a zero bound" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa
    m = a ± σa
    b = linearisation_bound(
        x -> 2x + 3,
        [m];
        values = Dict(a => 1.0, σa => 0.1),
    )

    # Every second derivative vanishes, so the first-order GUM result
    # is not an approximation at all — it is exact.
    @test isapprox(b, 0.0; atol = 1e-12)
end

@testitem "M13: the bound contains the true linearisation error" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa
    m = a ± σa
    vals = Dict(a => 1.0, σa => 0.1)

    # exp(x) at x = 1 ± 0.1, coverage factor 2: the Lagrange remainder
    # is ½·f″(ξ)·δ² for some ξ in [0.8, 1.2], so the bound is
    # ½·e^1.2·0.2² = 0.0664.
    b = linearisation_bound(exp, [m]; coverage_factor = 2, values = vals)
    @test isapprox(b, 0.5 * exp(1.2) * 0.2^2; rtol = 1e-6)

    # It must actually contain the worst real error over the interval.
    worst = maximum(
        abs(exp(1.0 + d) - (exp(1.0) + exp(1.0) * d)) for
        d in range(-0.2, 0.2; length = 201)
    )
    @test b >= worst
end

@testitem "M13: mixed partials are not ignored" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb
    ma = a ± σa
    mb = b ± σb
    vals = Dict(a => 2.0, σa => 0.1, b => 3.0, σb => 0.2)

    # A product is NOT linear, yet its Hessian diagonal is zero, so
    # M6's `check_linearity` — diagonal only — reports η = 0 and calls
    # it linear. The whole content of the nonlinearity sits in the
    # mixed partial ∂²(ab)/∂a∂b = 1.
    bound = linearisation_bound(*, [ma, mb]; coverage_factor = 2, values = vals)

    # R = δa·δb exactly, so the bound is (2·0.1)(2·0.2) = 0.08.
    @test isapprox(bound, 0.08; rtol = 1e-6)
    @test bound > 0
end

@testitem "M13: the bound never silently corrects the result" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # REQ-182 stays in force: computing a bound must not change u_c.
    @variables a σa
    m = a ± σa
    before = m.err
    linearisation_bound(exp, [m]; values = Dict(a => 1.0, σa => 0.1))
    @test isequal(m.err, before)
end
