@testitem "REQ-209: uncertainty_budget returns an UncertaintyBudget" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables V σV I σI

    m = (V ± σV) / (I ± σI)
    b = uncertainty_budget(m)

    # A budget is a value with a type, not a bag of tuples: it knows
    # the measurand it decomposes and the `u_c` its rows sum to.
    @test b isa UncertaintyBudget
    @test isequal(b.measurand, m.val)
    @test isequal(b.uc, m.err)
    @test !b.correlated

    # It is still a vector of rows, so every M3-era consumer that
    # iterates, indexes or measures it keeps working.
    @test b isa AbstractVector
    @test length(b) == 2
    @test all(r -> r isa BudgetRow, b)
    @test b[1].sigma isa Symbolics.Num

    vals = Dict(V => 5.0, σV => 0.01, I => 0.1, σI => 0.001)

    # EA-4/02 §7.3 percentage-of-variance column: for independent
    # sources the fractions decompose the variance exactly (REQ-045).
    @test isapprox(
        sum(_as_float(r.relative, vals) for r in b),
        1.0;
        rtol = 1e-9,
    )

    # And the contributions recombine into u_c, which is the property
    # that makes the table a budget rather than a list.
    total = sqrt(sum(_as_float(r.contribution, vals)^2 for r in b))
    @test isapprox(total, _as_float(m.err, vals); rtol = 1e-9)
end

@testitem "REQ-209: a budget reports whether correlation is in play" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa b σb

    x, y = declare_correlated(a ± σa, b ± σb, 0.5)
    correlated = uncertainty_budget(x * y)

    # Under a declared correlation the per-source variance fractions
    # are no longer a decomposition — the cross term is missing from
    # every numerator — so the budget says so rather than letting a
    # reader assume the column still sums to 1 (REQ-042).
    @test correlated.correlated
    @test occursin("correlated", lowercase(sprint(show, correlated)))
end

@testitem "REQ-209: budget display carries the measurand and u_c" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables V σV I σI
    b = uncertainty_budget((V ± σV) * (I ± σI))
    s = sprint(show, MIME("text/plain"), b)

    @test occursin("uncertainty budget", lowercase(s))
    @test occursin("u_c", s)
    # One line per source, plus a header and the u_c line.
    @test count(==('\n'), s) >= 3
end
