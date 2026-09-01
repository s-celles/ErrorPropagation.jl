@testitem "REQ-205: declared correlation reproduces JCGM eq. (13)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    @variables x σx y σy ρ
    a = x ± σx
    b = y ± σy

    # Declaring a correlation returns NEW quantities: a correlation
    # hypothesis is a property of the measurement model, traceable and
    # local, never action at a distance on a shared registry.
    a2, b2 = declare_correlated(a, b, ρ)

    s = a2 + b2
    dict = Dict(x => 12.0, σx => 0.1, y => 5.0, σy => 0.05, ρ => 0.3)

    # Equation (13): u² = σx² + σy² + 2·ρ·σx·σy for f = x + y.
    reference = sqrt(σx^2 + σy^2 + 2 * ρ * σx * σy)
    @test isapprox(
        _as_float(s.err, dict),
        _as_float(reference, dict);
        atol = 1e-12,
    )

    # And the originals are untouched — no mutation.
    @test isapprox(
        _as_float((a + b).err, dict),
        sqrt(0.1^2 + 0.05^2);
        atol = 1e-12,
    )
end

@testitem "REQ-205: zero declared correlation equals the independent case" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # The diagonal-Σ equivalence invariant (FR-010), restated: with
    # ρ = 0 equation (13) must collapse onto equation (10).
    @variables x σx y σy
    a = x ± σx
    b = y ± σy
    a2, b2 = declare_correlated(a, b, Symbolics.Num(0))

    dict = Dict(x => 12.0, σx => 0.1, y => 5.0, σy => 0.05)
    @test isapprox(
        _as_float((a2 + b2).err, dict),
        _as_float((a + b).err, dict);
        atol = 1e-12,
    )
end
