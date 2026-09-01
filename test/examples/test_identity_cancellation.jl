@testitem "propagate fixes M1 identity-tracking (UB-002)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    # Three expressions that the M1 binary-operator path mishandles.
    # All three MUST return zero uncertainty under propagate.
    minus = propagate(y -> y - y, [m])
    quotient = propagate(y -> y / y, [m])
    cubic = propagate(y -> y * y * y - y^3, [m])

    @test minus isa SymbolicMeasurement
    @test quotient isa SymbolicMeasurement
    @test cubic isa SymbolicMeasurement

    dict = Dict(x => 8.4, σx => 0.7)

    # Each .err must evaluate to 0 numerically. This is the M2 fix
    # for upstream-bugs.md UB-002.
    @test isapprox(_as_float(minus.err, dict), 0.0; atol = 1e-12)
    @test isapprox(_as_float(quotient.err, dict), 0.0; atol = 1e-12)
    @test isapprox(_as_float(cubic.err, dict), 0.0; atol = 1e-12)
end
