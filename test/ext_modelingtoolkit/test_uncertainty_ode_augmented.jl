@testitem "SymbolicUncertaintiesModelingToolkitExt: uncertainty_ode augmentation shape" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using Symbolics
    using SymbolicUncertainties
    using SymbolicUncertainties: ±

    @variables u(t)
    @parameters R C Vin
    eqs = [D(u) ~ (Vin - u) / (R * C)]
    @named sys = System(eqs, t)

    R_m = R ± 0.01R
    C_m = C ± 0.01C
    Vin_m = Vin ± 0.001Vin

    augmented = uncertainty_ode(sys, [R_m, C_m, Vin_m])

    @test augmented isa System
    @test length(unknowns(augmented)) == 1 + 3 * 1  # N + K·N
    @test length(equations(augmented)) == 1 + 3 * 1
end
