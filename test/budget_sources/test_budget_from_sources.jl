@testitem "REQ-206: budget derives its rows from the source structure" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables V σV R1 σR1 R2 σR2
    v = V ± σV
    r1 = R1 ± σR1
    r2 = R2 ± σR2
    vout = v * r2 / (r1 + r2)

    # No `variables`, no `sigmas`: the quantity already knows what it
    # derives from. Requiring the caller to restate it was the M3
    # design, and it asked for information the object holds.
    rows = uncertainty_budget(vout)

    @test length(rows) == 3
    # Rows are `BudgetRow` values since the M11 budget type (REQ-209).
    @test all(hasproperty(r, :source) for r in rows)
    @test all(hasproperty(r, :sensitivity) for r in rows)
    @test all(hasproperty(r, :contribution) for r in rows)

    dict = Dict(
        V => 12.0,
        σV => 0.1,
        R1 => 1000.0,
        σR1 => 10.0,
        R2 => 2000.0,
        σR2 => 20.0,
    )

    # REQ-152 restated on sources: with independent sources the
    # variance fractions sum to exactly 1.
    total = sum(_as_float(r.relative, dict) for r in rows)
    @test isapprox(total, 1.0; atol = 1e-10)

    # And the contributions recombine into the combined uncertainty.
    quad = sqrt(sum(_as_float(r.contribution, dict)^2 for r in rows))
    @test isapprox(quad, _as_float(vout.err, dict); atol = 1e-10)
end

@testitem "REQ-206: a cancelled source leaves no budget row" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # A source that cancels contributes nothing and must not appear as
    # a zero row — the pre-M11 budget listed whatever variables the
    # caller passed, whether or not they mattered.
    @variables x σx y σy
    a = x ± σx
    b = y ± σy

    rows = uncertainty_budget(a + b - a)
    @test length(rows) == 1
end
