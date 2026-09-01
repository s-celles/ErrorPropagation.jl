@testitem "REQ-206: a source of zero uncertainty produces no budget row" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx y σy

    # Every constant operand is wrapped as a measurement of zero
    # standard uncertainty, so a model written with literal
    # coefficients accumulates them. They contribute nothing to the
    # variance — that rule was already applied there — and a row for
    # one is noise: zero contribution, zero variance fraction.
    m = 3.0 * (x ± σx) + 2.5 * (y ± σy) + 7.0

    rows = uncertainty_budget(m)
    @test length(rows) == 2
    @test Set(r.name for r in rows) == Set([:x, :y])
    @test all(!isequal(Symbolics.value(r.sigma), 0) for r in rows)

    # The variance decomposition is unaffected: the fractions still
    # sum to one, because the dropped rows carried none of it.
    vals = Dict(x => 1.0, σx => 0.1, y => 2.0, σy => 0.2)
    @test isapprox(
        sum(_as_float(r.relative, vals) for r in rows),
        1.0;
        rtol = 1e-9,
    )

    # A polynomial in one input is the case that made this visible: a
    # calibration curve `a₁·t + a₂·t²` wraps two coefficients, and the
    # budget showed more empty rows than real ones.
    @variables t σt
    poly = 39.45e-6 * (t ± σt) + 2.36e-8 * (t ± σt) * (t ± σt)
    poly_rows = uncertainty_budget(poly)
    @test all(!isequal(Symbolics.value(r.sigma), 0) for r in poly_rows)
    @test length(poly_rows) <= 3
end
