@testitem "uncertainty_contribution: |c_i|·σ_i on sum (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    ua = uncertainty_contribution(m, a, σa)
    ub = uncertainty_contribution(m, b, σb)

    dict = Dict(a => 2.0, b => 3.0, σa => 0.1, σb => 0.2)
    @test isapprox(_as_float(ua, dict), 0.1; atol = 1e-12)
    @test isapprox(_as_float(ub, dict), 0.2; atol = 1e-12)
end

@testitem "uncertainty_contribution: product rule (numeric)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x * y, [a ± σa, b ± σb])

    ua = uncertainty_contribution(m, a, σa)
    ub = uncertainty_contribution(m, b, σb)

    dict = Dict(a => 2.0, b => 3.0, σa => 0.1, σb => 0.2)
    # For f = a·b: ∂f/∂a = b, so u_a = |b|·σa = 3·0.1 = 0.3.
    # For f = a·b: ∂f/∂b = a, so u_b = |a|·σb = 2·0.2 = 0.4.
    @test isapprox(_as_float(ua, dict), 0.3; atol = 1e-12)
    @test isapprox(_as_float(ub, dict), 0.4; atol = 1e-12)
end

@testitem "uncertainty_contribution: absent variable returns 0 (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa z σz
    m = a ± σa

    u = uncertainty_contribution(m, z, σz)
    dict = Dict(a => 2.0, σa => 0.1, z => 5.0, σz => 0.3)
    @test isapprox(_as_float(u, dict), 0.0; atol = 1e-12)
end
