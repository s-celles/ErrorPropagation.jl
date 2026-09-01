@testitem "SymbolicUncertaintiesModelingToolkitExt: empty uncertain_params gives err = 0" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using Symbolics
    using SymbolicUncertainties

    @variables u(t)
    @parameters R
    eqs = [D(u) ~ -u / R]
    @named sys = System(eqs, t)

    result = propagate_ode(sys, SymbolicMeasurement[])

    @test length(result) == 1
    @test isequal(Symbolics.value(result[1].err), 0)
end
