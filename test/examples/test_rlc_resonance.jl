@testitem "M5 exit-gate: RLC resonance infer_precision (SC-004)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables L C σL σC
    # propagate emits REQ-140 / REQ-141 warnings (division + sqrt of
    # symbolic argument). Silence via NullLogger — the warnings are
    # tested separately in test/safety/.
    f0 = Logging.with_logger(Logging.NullLogger()) do
        propagate((l, c) -> 1 / (2π * sqrt(l * c)), [L ± σL, C ± σC])
    end

    ε = 0.001
    # σL* such that f0.err == ε·f0.val.
    σL_star = infer_precision(f0, σL, ε * f0.val)

    # Two-pass substitution: σL → σL_star first (σL_star depends on
    # L, C, σC), then substitute concrete numerics for the rest.
    numeric = Dict(L => 1e-3, C => 1e-6, σC => 1e-7)
    err_step1 = Symbolics.substitute(f0.err, Dict(σL => σL_star))
    err_step2 = Symbolics.substitute(err_step1, numeric)
    val_step = Symbolics.substitute(f0.val, numeric)
    err_val = Float64(eval(Symbolics.toexpr(err_step2)))
    val_val = Float64(eval(Symbolics.toexpr(val_step)))
    @test isapprox(err_val, ε * val_val; atol = 1e-10, rtol = 1e-10)
end
