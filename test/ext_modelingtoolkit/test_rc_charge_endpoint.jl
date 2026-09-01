@testitem "SymbolicUncertaintiesModelingToolkitExt: RC-charge endpoint SC-003" begin
    using ModelingToolkit
    using ModelingToolkit: t_nounits as t, D_nounits as D, System
    using OrdinaryDiffEq
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
    compiled = mtkcompile(augmented)

    sens_states = setdiff(unknowns(augmented), unknowns(sys))
    u0 = Dict(u => 0.0, (s => 0.0 for s in sens_states)...)
    p = Dict(R => 1.0, C => 1e-3, Vin => 5.0)
    prob = ODEProblem(compiled, merge(u0, p), (0.0, 50e-3))
    sol = solve(prob, Tsit5(); abstol = 1e-10, reltol = 1e-10)

    # SC-003 exit gate: u(50τ) ≈ Vin within rtol = 1e-6
    @test isapprox(sol[u, end], 5.0; rtol = 1e-6)
end
