@testitem "REQ-207: only one public propagation path remains" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The three-argument `propagate(f, ms, Σ)` is gone: correlation is
    # a property of the sources, not an argument the caller supplies.
    @variables x σx y σy
    ms = [x ± σx, y ± σy]
    Σ = [σx^2 0; 0 σy^2]
    @test_throws MethodError propagate((a, b) -> a + b, ms, Σ)

    # `propagate` itself survives as a convenience over the operators,
    # so a model written as a function still works.
    m = propagate((a, b) -> a + b, ms)
    @test m isa SymbolicMeasurement
end
