@testitem "check_linearity: exp(x) at x=1 gives |η| > 0 (REQ-155)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables x σx
    η = Logging.with_logger(Logging.NullLogger()) do
        check_linearity(a -> exp(a), [x ± σx])
    end

    # η = (∂²exp(x)/∂x²)·σx² / (2·∂exp(x)/∂x·σx)
    #   = exp(x)·σx² / (2·exp(x)·σx)
    #   = σx/2.
    # At σx = 0.1, η = 0.05.
    dict = Dict(x => 1.0, σx => 0.1)
    value = _as_float(η[σx], dict)
    @test isapprox(value, 0.05; atol = 1e-10)
    @test abs(value) > 0

    # Verify it's below the 0.1 threshold → no warning in US2.
    @test abs(value) <= 0.1
end

@testitem "check_linearity: exp(x) with larger σ exceeds threshold" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables x σx
    η = Logging.with_logger(Logging.NullLogger()) do
        check_linearity(a -> exp(a), [x ± σx])
    end
    # At σx = 0.5, η = 0.25 > 0.1 (warning-worthy).
    dict = Dict(x => 1.0, σx => 0.5)
    value = _as_float(η[σx], dict)
    @test isapprox(value, 0.25; atol = 1e-10)
    @test abs(value) > 0.1
end
