@testitem "M12: k is a closed form in ν, not a normal placeholder" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables y u ν

    m = SymbolicMeasurement(y, u, ν)
    e = expanded_uncertainty(m; coverage_probability = 0.95)

    # Before M12 a symbolic ν fell back to the normal quantile, so k
    # was the constant 1.96 and the degrees of freedom were silently
    # discarded. k must now depend on ν.
    @test !isempty(Symbolics.get_variables(e.k))
    @test any(isequal(Symbolics.value(ν)), Symbolics.get_variables(e.k))
end

@testitem "M12: the closed form matches Student's t" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables y u ν
    m = SymbolicMeasurement(y, u, ν)
    e = expanded_uncertainty(m; coverage_probability = 0.95)

    # JCGM 100:2008 Table G.2, two-sided 95 %.
    for (dof, reference) in ((10.0, 2.228), (20.0, 2.086), (30.0, 2.042))
        got = _as_float(e.k, Dict(ν => dof))
        @test isapprox(got, reference; atol = 5e-3)
    end
end

@testitem "M12: k tends to the normal quantile as ν grows" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables y u ν
    m = SymbolicMeasurement(y, u, ν)
    e = expanded_uncertainty(m; coverage_probability = 0.95)

    # The series is an expansion in 1/ν, so infinite degrees of
    # freedom must recover the normal coverage factor exactly. The
    # package's Table G.2 entry is 1.96, not the unrounded 1.959964.
    # The 1/ν term still contributes ≈2.4e-9 at ν = 1e9, so the
    # tolerance has to sit above the series' own convergence rate.
    @test isapprox(
        _as_float(e.k, Dict(ν => 1.0e9)),
        SymbolicUncertainties._NORMAL_QUANTILE[0.95];
        atol = 1e-8,
    )
end
