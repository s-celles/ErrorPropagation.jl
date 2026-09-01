@testitem "REQ-203: a shared source induces covariance with no matrix" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The case that actually matters in metrology: two quantities are
    # correlated BECAUSE they derive from a common upstream
    # measurement. That is exactly the case where the user cannot
    # write the covariance matrix by hand — they do not know it.
    @variables V σV R σR
    v = V ± σV
    r = R ± σR

    p = v * v / r     # power, shares the voltage source with...
    i = v / r         # ...current

    dict = Dict(V => 12.0, σV => 0.1, R => 4.0, σR => 0.05)

    # p / i must be exactly V again: the shared voltage source cancels
    # in the ratio, and R cancels completely. Any path that treated p
    # and i as independent would report spurious uncertainty here.
    ratio = p / i
    @test isapprox(_as_float(ratio.val, dict), 12.0; atol = 1e-10)
    @test isapprox(_as_float(ratio.err, dict), 0.1; atol = 1e-10)
end
