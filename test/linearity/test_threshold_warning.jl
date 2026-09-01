@testitem "check_linearity: |η| > 0.1 emits REQ-181 @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    # exp(x) at x=1, σx=0.5 gives |η| = 0.25 > 0.1 → warning expected.
    @test_logs (:warn, r"REQ-181") check_linearity(
        a -> exp(a),
        [x ± σx];
        values = Dict(x => 1.0, σx => 0.5),
    )
end
