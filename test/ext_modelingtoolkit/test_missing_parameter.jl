@testitem "SymbolicUncertaintiesModelingToolkitExt: missing parameter raises ArgumentError" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using Symbolics
    using SymbolicUncertainties
    using SymbolicUncertainties: ±

    @variables u(t)
    @parameters R
    eqs = [D(u) ~ -u / R]
    @named sys = System(eqs, t)

    # `Rogue` is not a parameter of `sys`
    @parameters Rogue
    bad_m = Rogue ± 0.01Rogue

    @test_throws ArgumentError propagate_ode(sys, [bad_m])
    @test_throws ArgumentError uncertainty_ode(sys, [bad_m])
end
