@testitem "M3 exit-gate: voltage-divider budget (EA-4/02 §7.3)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2

    Vout = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )

    budget = uncertainty_budget(Vout, [Vin, R1, R2], [σVin, σR1, σR2])

    @test length(budget) == 3

    # Sensitivity coefficients match the closed-form voltage-divider
    # reference.
    @test Symbolics.isequal(
        Symbolics.simplify(budget[1].sensitivity - R2 / (R1 + R2)),
        0,
    )
    @test Symbolics.isequal(
        Symbolics.simplify(budget[2].sensitivity + Vin * R2 / (R1 + R2)^2),
        0,
    )
    @test Symbolics.isequal(
        Symbolics.simplify(budget[3].sensitivity - Vin * R1 / (R1 + R2)^2),
        0,
    )

    # Variance-decomposition invariant (SC-002, REQ-045 / REQ-152):
    # the relative sensitivities sum to 1.
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
