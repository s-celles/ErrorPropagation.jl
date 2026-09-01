@testitem "uncertainty_budget: missing variable yields zero row (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa z σz
    m = a ± σa   # measurand does not depend on z

    budget = uncertainty_budget(m, [a, z], [σa, σz])

    @test length(budget) == 2

    dict = Dict(a => 2.0, σa => 0.1, z => 5.0, σz => 0.3)
    # Second row (variable z) has sensitivity 0 and contribution 0.
    @test isapprox(_as_float(budget[2].sensitivity, dict), 0.0; atol = 1e-12)
    @test isapprox(_as_float(budget[2].contribution, dict), 0.0; atol = 1e-12)
    @test isapprox(_as_float(budget[2].relative, dict), 0.0; atol = 1e-12)
end
