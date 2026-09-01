@testitem "UB-008: a failing simplification must not abort the computation" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Simplification is a presentation step. `Symbolics.simplify`
    # throws on ordinary metrological input — an `Int64` overflow in
    # `DynamicPolynomials` once a degrees-of-freedom count of `1e12` is
    # rationalised (`upstream-bugs.md` UB-008) — and that used to
    # surface as an exception from a plain property access.
    @variables sr σsr so σso sc σsc sres σsres

    # `1e12` is how a Type B component whose own uncertainty is well
    # known gets an effectively infinite ν (JCGM 100:2008 §G.4.2).
    combined =
        SymbolicMeasurement(sr, σsr, Symbolics.Num(30.0)) +
        SymbolicMeasurement(so, σso, Symbolics.Num(2.0)) +
        SymbolicMeasurement(sc, σsc, Symbolics.Num(1.0e12)) +
        SymbolicMeasurement(sres, σsres, Symbolics.Num(1.0e12))

    # Before the guard this line threw an `OverflowError`; that it
    # completes at all is the regression being pinned.
    ν = combined.dof
    @test ν isa Symbolics.Num

    # And the value that comes back is the right one: the two Type B
    # components contribute essentially nothing to the
    # Welch-Satterthwaite denominator, so ν_eff is set by the 30-dof
    # repeatability term and the 2-dof reproducibility term.
    vals = Dict(
        sr => 0.0,
        σsr => 0.8,
        so => 0.0,
        σso => 0.6,
        sc => 0.0,
        σsc => 0.35,
        sres => 0.0,
        σsres => 0.25 / sqrt(3),
    )
    ν_eff = _as_float(ν, vals)
    @test 2.0 < ν_eff < 30.0
end
