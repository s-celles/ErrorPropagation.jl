@testitem "REQ-202: binary operators cancel a shared source" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx
    dict = Dict(x => 8.4, σx => 0.7)

    # THE acceptance test of M11: this must hold through the plain
    # binary operators, with no user awareness that a trap ever
    # existed. Before M11 these returned σ√2 and 2σ/x respectively.
    @test isapprox(_as_float((m - m).err, dict), 0.0; atol = 1e-12)
    @test isapprox(_as_float((m / m).err, dict), 0.0; atol = 1e-12)

    # A source cancelling in a longer expression cancels just as well.
    @test isapprox(_as_float((m + m - m - m).err, dict), 0.0; atol = 1e-12)

    # And m + m is 2x with uncertainty 2σ — NOT σ√2, which is what
    # treating the two operands as independent would give.
    @test isapprox(_as_float((m + m).err, dict), 2 * 0.7; atol = 1e-12)
end

@testitem "REQ-202: distinct sources do not cancel" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Same symbols, two independent measurements: two resistors of
    # equal nominal tolerance are not the same resistor, and their
    # difference must NOT come out exact.
    @variables x σx
    m1 = x ± σx
    m2 = x ± σx
    dict = Dict(x => 8.4, σx => 0.7)

    @test isapprox(_as_float((m1 - m2).err, dict), 0.7 * sqrt(2); atol = 1e-12)
end

@testitem "REQ-202: cancellation survives floating-point round-off" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # With numeric estimates the two opposite sensitivities of `x / x`
    # are computed as 1/x and x/x², which are not always the same
    # Float64: for x = 0.1, 1/0.1 is exactly 10.0 but 0.1/0.01 is
    # 9.999999999999998, because 0.01 is not representable. The
    # difference is a round-off residue, not uncertainty, and must not
    # be reported as one.
    for v in (0.1, 0.3, 1.0e-3, 7.7, 1.0 / 3.0)
        m = v ± 0.1
        @test isequal(Symbolics.value((m / m).err), 0)
        @test isequal(Symbolics.value((m - m).err), 0)
    end

    # A genuinely tiny but real uncertainty must still be reported —
    # the guard keys on cancellation, not on smallness.
    tiny = 1.0 ± 1.0e-30
    @test !isequal(Symbolics.value(tiny.err), 0)
end
