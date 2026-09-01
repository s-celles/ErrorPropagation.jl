@testitem "check_linearity: |η| < 0.1 emits no warning" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables x σx
    # exp(x) at x=1, σx=0.1 gives |η| = 0.05 < 0.1 → no warning.
    @test_logs min_level = Logging.Warn check_linearity(
        a -> exp(a),
        [x ± σx];
        values = Dict(x => 1.0, σx => 0.1),
    )
end

@testitem "check_linearity: linear function never warns" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables x σx
    # Linear f → η = 0 → no warning regardless of values.
    @test_logs min_level = Logging.Warn check_linearity(
        a -> 2a + 3,
        [x ± σx];
        values = Dict(x => 1.0, σx => 1.0),
    )
end

@testitem "check_linearity: no `values` → no warning even on nonlinear" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables x σx
    # Without `values`, no numeric evaluation → no threshold
    # check → no warning regardless of how nonlinear f is.
    @test_logs min_level = Logging.Warn check_linearity(a -> exp(a), [x ± σx])
end
