@testitem "Phase 1: computed err reproduces the stored-field value" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx a σa b σb

    # A raw measurement's err must be the σ itself — NOT sqrt(σ^2),
    # which is what a naive quadratic form would return and which
    # would break every symbolic comparison in the suite.
    m = x ± σx
    @test isequal(m.err, σx)

    # The historical positional constructor keeps working: it mints
    # one opaque source of standard uncertainty `err`.
    legacy = SymbolicMeasurement(a, sqrt(σa^2 + σb^2))
    @test isequal(legacy.err, sqrt(σa^2 + σb^2))
    @test isequal(legacy.val, a)

    # dof survives as a computed property.
    @variables ν
    with_dof = SymbolicMeasurement(a, σa, ν)
    @test isequal(with_dof.dof, ν)
    @test SymbolicMeasurement(a, σa).dof === nothing

    # x - x is exact since phase 2 migrated the operators to the chain
    # rule; the assertion lives in test/chainrule/ (REQ-202).
end

@testitem "Phase 1: substitute stays local (no global registry)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The design decision of phase 0: source uncertainties are carried
    # by the quantity, not held in module state. Substitution must
    # therefore reach them without touching anything global, so a
    # fully-substituted measurement still yields numbers (REQ-120,
    # REQ-123, M4 exit criterion).
    @variables x σx
    m = x ± σx
    s = Symbolics.substitute(m, Dict(x => 5.0, σx => 0.1))

    @test isapprox(_as_float(s.val, Dict()), 5.0; atol = 1e-12)
    @test isapprox(_as_float(s.err, Dict()), 0.1; atol = 1e-12)
end
