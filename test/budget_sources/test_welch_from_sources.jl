@testitem "REQ-208: ν_eff derives from the per-source contributions" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa νa b σb νb
    x = SymbolicMeasurement(a, σa, νa)
    y = SymbolicMeasurement(b, σb, νb)
    s = x + y

    # The quantity carries the degrees of freedom of each source, so
    # Welch-Satterthwaite (JCGM 100:2008 §G.4 eq. G.2b) follows from
    # the structure rather than from hand-passed vectors.
    ν = s.dof
    @test ν !== nothing

    dict =
        Dict(a => 1.0, σa => 0.2, νa => 10.0, b => 3.0, σb => 0.4, νb => 20.0)
    expected = (0.2^2 + 0.4^2)^2 / (0.2^4 / 10.0 + 0.4^4 / 20.0)
    @test isapprox(_as_float(ν, dict), expected; atol = 1e-9)
end

@testitem "REQ-208: a single source keeps its own dof" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables a σa ν
    m = SymbolicMeasurement(a, σa, ν)
    @test isequal(m.dof, ν)
    @test SymbolicMeasurement(a, σa).dof === nothing
end
