@testitem "infer_precision: transcendental measurand raises REQ-091" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Build a measurement whose err is NOT quadratic in σ — so the
    # algebraic split `err² = cᵢ²·σᵢ² + others` fails. A
    # transcendental `sin(σ)` term does the job.
    @variables σ x
    m = SymbolicMeasurement(x, sin(σ) + cos(σ) * x)

    @test_throws (ArgumentError) infer_precision(m, σ, 0.1)
end
