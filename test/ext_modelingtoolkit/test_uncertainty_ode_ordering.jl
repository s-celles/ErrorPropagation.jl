@testitem "SymbolicUncertaintiesModelingToolkitExt: uncertainty_ode preserves original states first" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using Symbolics
    using SymbolicUncertainties
    using SymbolicUncertainties: ±

    @variables u(t)
    @parameters R C Vin
    eqs = [D(u) ~ (Vin - u) / (R * C)]
    @named sys = System(eqs, t)

    augmented = uncertainty_ode(sys, [R ± 0.01R, C ± 0.01C, Vin ± 0.001Vin])

    N = length(unknowns(sys))
    @test isequal(collect(unknowns(augmented))[1:N], collect(unknowns(sys)))

    # Equation preservation: first N equations are the originals
    @test isequal(collect(equations(augmented))[1:N], collect(equations(sys)))
end
