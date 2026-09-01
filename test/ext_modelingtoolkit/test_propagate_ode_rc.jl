@testitem "SymbolicUncertaintiesModelingToolkitExt: RC-charge propagate_ode err has all σs" begin
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

    result = propagate_ode(sys, [R_m, C_m, Vin_m])

    @test length(result) == 1
    err_expr = result[1].err
    @test !isequal(err_expr, Symbolics.Num(0))

    # String representation should mention each uncertain parameter
    err_str = string(err_expr)
    @test occursin("R", err_str)
    @test occursin("C", err_str)
    @test occursin("Vin", err_str)
end
