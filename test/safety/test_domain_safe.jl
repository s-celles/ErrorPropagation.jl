@testitem "safety: _warn_domain emits no warn on positive concrete val" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # Direct helper call: purely-numeric val passes the provable-
    # value + strictly-positive test, so no warning is emitted.
    # The concrete-val `sqrt(m)` does not round-trip through
    # `_propagate_unary` here — that is an M2 derivative pathway
    # separately tested in test/math/. M4 only owns the warning.
    m = SymbolicMeasurement(Symbolics.Num(4.0), Symbolics.Num(0.1))
    @test_logs min_level = Logging.Warn SymbolicUncertainties._warn_domain(
        :sqrt,
        m,
    )
    @test_logs min_level = Logging.Warn SymbolicUncertainties._warn_domain(
        :log,
        m,
    )
    @test_logs min_level = Logging.Warn SymbolicUncertainties._warn_domain(
        :log2,
        m,
    )
    @test_logs min_level = Logging.Warn SymbolicUncertainties._warn_domain(
        :log10,
        m,
    )
end
