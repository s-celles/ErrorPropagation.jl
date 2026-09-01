@testitem "SymbolicUncertaintiesModelingToolkitExt: propagate_ode signature and return shape" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using Symbolics
    using SymbolicUncertainties
    using SymbolicUncertainties: ±

    @variables u(t)
    @parameters R
    eqs = [D(u) ~ -u / R]
    @named sys = System(eqs, t)

    R_m = R ± 0.01R
    result = propagate_ode(sys, [R_m])

    @test result isa Vector{SymbolicMeasurement}
    @test length(result) == length(unknowns(sys))
    @test length(result) == 1
    # val field is the state variable
    @test isequal(Symbolics.value(result[1].val), Symbolics.value(u))
end
