@testitem "generated code uses hypot for the sum of squares" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx y σy
    m = (x ± σx) + (y ± σy)

    # `sqrt(a² + b²)` is exact in algebra and fragile in floating
    # point: it overflows for a > 1e154 and underflows to zero for
    # a < 1e-150, where `hypot` returns the right answer. The symbolic
    # form stays `sqrt(σx² + σy²)` — it is the readable one — and only
    # the emitted code switches.
    @test occursin("sqrt", string(m.err))

    c = build_evaluator(m, [x, y, σx, σy]; target = CTarget())
    @test occursin("hypot", c)
    @test !occursin("sqrt", c)

    f = build_evaluator(m, [x, y, σx, σy])
    out = f(1.0, 1.0, 1e200, 1.0)
    @test isfinite(out[2])
    @test isapprox(out[2], 1e200; rtol = 1e-12)

    tiny = f(1.0, 1.0, 1e-200, 1e-200)
    @test tiny[2] > 0
    @test isapprox(tiny[2], hypot(1e-200, 1e-200); rtol = 1e-12)
end

@testitem "a correlated budget keeps sqrt: hypot cannot carry a cross term" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx y σy

    # Under a declared correlation the variance carries
    # `2·c₁·c₂·cov` (JCGM 100:2008 eq. 13), which is not a square and
    # may be negative. `hypot` has nowhere to put it, so the emitter
    # must fall back to `sqrt` rather than silently drop the term.
    a, b = declare_correlated(x ± σx, y ± σy, 0.5)
    m = a + b

    c = build_evaluator(m, [x, y, σx, σy]; target = CTarget())
    @test occursin("sqrt", c)
    @test !occursin("hypot", c)
end
