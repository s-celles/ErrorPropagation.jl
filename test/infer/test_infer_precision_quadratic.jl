@testitem "infer_precision: Ohm's law quadratic" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables V I σV σI
    # propagate emits REQ-140 warning (symbolic denominator) — silence
    # via NullLogger; the warning is tested separately in test/safety/.
    R_m = Logging.with_logger(Logging.NullLogger()) do
        propagate((v, i) -> v / i, [V ± σV, I ± σI])
    end

    σV_star = infer_precision(R_m, σV, 0.01)

    # Round-trip numeric check: substitute σV -> σV*, then V, I, σI.
    # Two passes — σV_star contains V, I, σI and a single-pass
    # `Symbolics.substitute` does not re-substitute values
    # introduced by the σV → σV_star rewrite.
    step1 = Symbolics.substitute(R_m.err, Dict(σV => σV_star))
    step2 = Symbolics.substitute(step1, Dict(V => 5.0, I => 0.5, σI => 0.001))
    err_val = Float64(eval(Symbolics.toexpr(step2)))
    @test isapprox(err_val, 0.01; atol = 1e-10)
end
