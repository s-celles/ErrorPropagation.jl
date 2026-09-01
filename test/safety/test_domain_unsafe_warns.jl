@testitem "safety: sqrt on plain symbolic emits REQ-141 @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx
    @test_logs (:warn, r"REQ-141") sqrt(m)
end

@testitem "safety: log/log2/log10 on plain symbolic emit REQ-141 @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx
    @test_logs (:warn, r"REQ-141") log(m)
    @test_logs (:warn, r"REQ-141") log2(m)
    @test_logs (:warn, r"REQ-141") log10(m)
end

@testitem "safety: _warn_domain on concrete non-positive val emits @warn" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # Direct helper call: purely-numeric val, non-positive. The
    # safety warning fires without engaging M2's derivative
    # pathway (which can't differentiate w.r.t. a literal).
    m_neg = SymbolicMeasurement(Symbolics.Num(-1.0), Symbolics.Num(0.1))
    @test_logs (:warn, r"REQ-141") SymbolicUncertainties._warn_domain(
        :sqrt,
        m_neg,
    )
    @test_logs (:warn, r"REQ-141") SymbolicUncertainties._warn_domain(
        :log,
        m_neg,
    )

    m_zero = SymbolicMeasurement(Symbolics.Num(0.0), Symbolics.Num(0.1))
    @test_logs (:warn, r"REQ-141") SymbolicUncertainties._warn_domain(
        :sqrt,
        m_zero,
    )
    @test_logs (:warn, r"REQ-141") SymbolicUncertainties._warn_domain(
        :log,
        m_zero,
    )
end
