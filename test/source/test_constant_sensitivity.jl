@testitem "a constant sensitivity does not leave sqrt(c^2 u^2) behind" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx

    # The M11 short-circuit covered a sensitivity of exactly 1, so any
    # negation reported `sqrt(σx^2)` where the answer is `σx`.
    # Symbolics cannot reduce that itself without a positivity
    # assumption (upstream-bugs.md UB-003), but `u` is non-negative by
    # construction (REQ-005), so the package can.
    @test isequal((0 - m).err, σx)
    @test isequal((-1 * m).err, σx)

    # An exact integer square factors out exactly, with no float
    # contamination: |c|·u, not sqrt(4u²).
    @test isequal((2 * m).err, 2σx)
    @test isequal((-3 * m).err, 3σx)

    # A non-constant sensitivity keeps the general form — there is
    # nothing to factor out, and inventing an `abs` here would need
    # the sign of `y`.
    @variables y
    q = y * m
    @test occursin("sqrt", string(q.err))

    # Whatever the form, the value is unchanged.
    dict = Dict(x => 2.0, σx => 0.1, y => -4.0)
    @test isapprox(_as_float(q.err, dict), 0.4; atol = 1e-12)
    @test isapprox(_as_float((-3 * m).err, dict), 0.3; atol = 1e-12)
end

@testitem "abs: a sign-branch sensitivity squares to one" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx

    # ∂|x|/∂x is ±1, which Symbolics represents as
    # `ifelse(signbit(x), -1, 1)`. Squared it is identically 1, but
    # nothing folds it, so the uncertainty of `abs(m)` carried a
    # branch test where the answer is just `σx`.
    a = abs(m)
    @test isequal(a.err, σx)
    @test !occursin("ifelse", string(a.err))

    # The estimate keeps its branch, which is correct: |x| genuinely
    # depends on the sign of x.
    @test occursin("abs", string(a.val))

    dict = Dict(x => -2.0, σx => 0.25)
    @test isapprox(_as_float(a.val, dict), 2.0; atol = 1e-12)
    @test isapprox(_as_float(a.err, dict), 0.25; atol = 1e-12)
end
