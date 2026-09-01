@testitem "infer_precision: linear sum (numeric)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # u_target = sqrt(σa² + σb²). Solve for σa given target_uc, with σb
    # substituted to a concrete value.
    σa_star = infer_precision(m, σa, 0.05)

    # Numeric check: at σb = 0.03, target_uc = 0.05,
    # σa* = sqrt(0.05² - 0.03²) = sqrt(0.0025 - 0.0009) = sqrt(0.0016) = 0.04
    σa_val = Float64(
        eval(Symbolics.toexpr(Symbolics.substitute(σa_star, Dict(σb => 0.03)))),
    )
    @test isapprox(σa_val, 0.04; atol = 1e-10)
end
