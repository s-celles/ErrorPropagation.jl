@testitem "variance decomposition: linear combination (symbolic)" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> 2x + 3y, [a ± σa, b ± σb])
    budget = uncertainty_budget(m, [a, b], [σa, σb])

    total = Symbolics.simplify(sum(row.relative for row in budget))
    @test Symbolics.isequal(total, 1)
end

@testitem "variance decomposition: product (numeric)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x * y, [a ± σa, b ± σb])
    budget = uncertainty_budget(m, [a, b], [σa, σb])

    dict = Dict(a => 2.0, b => 3.0, σa => 0.1, σb => 0.2)
    total = sum(_as_float(row.relative, dict) for row in budget)
    @test isapprox(total, 1.0; atol = 1e-10)
end

@testitem "variance decomposition: voltage divider (numeric)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2
    m = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )
    budget = uncertainty_budget(m, [Vin, R1, R2], [σVin, σR1, σR2])

    dict = Dict(
        Vin => 5.0,
        R1 => 1_000.0,
        R2 => 3_000.0,
        σVin => 0.01,
        σR1 => 1.0,
        σR2 => 1.0,
    )
    total = sum(_as_float(row.relative, dict) for row in budget)
    @test isapprox(total, 1.0; atol = 1e-10)
end
