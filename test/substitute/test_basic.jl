@testitem "substitute: basic val+err substitution" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = substitute(m, Dict(x => 5.0, σx => 0.1))

    @test result isa SymbolicMeasurement
    @test Symbolics.value(result.val) == 5.0
    @test Symbolics.value(result.err) == 0.1
    @test result.dof === nothing
end

@testitem "substitute: propagate result fully substituted" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])
    result = substitute(m, Dict(a => 2.0, b => 3.0, σa => 0.1, σb => 0.2))

    # Symbolics.substitute does not numerically evaluate sqrt(...) —
    # force evaluation via the AsFloat helper (same pattern as M2/M3).
    @test isapprox(
        Float64(eval(Symbolics.toexpr(result.val))),
        5.0;
        atol = 1e-12,
    )
    # err = sqrt(σa² + σb²) = sqrt(0.01 + 0.04) = sqrt(0.05) ≈ 0.2236...
    @test isapprox(
        Float64(eval(Symbolics.toexpr(result.err))),
        sqrt(0.05);
        atol = 1e-12,
    )
end
