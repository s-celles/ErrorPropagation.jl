@testitem "uncertainty_budget: row schema" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    budget = uncertainty_budget(m, [a, b], [σa, σb])

    @test length(budget) == 2
    # Rows are `BudgetRow` values since M11's budget type (REQ-209);
    # the EA-4/02 §7.3 column names are unchanged.
    @test hasproperty(budget[1], :variable)
    @test hasproperty(budget[1], :sigma)
    @test hasproperty(budget[1], :sensitivity)
    @test hasproperty(budget[1], :contribution)
    @test hasproperty(budget[1], :relative)

    # First row matches variable `a`, second matches `b`.
    @test Symbolics.isequal(budget[1].variable, a)
    @test Symbolics.isequal(budget[1].sigma, σa)
    @test Symbolics.isequal(budget[2].variable, b)
    @test Symbolics.isequal(budget[2].sigma, σb)
end
