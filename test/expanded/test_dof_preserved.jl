@testitem "expanded_uncertainty: dof field preserved" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx ν
    m = SymbolicMeasurement(x, σx, ν)

    U = expanded_uncertainty(m, 2)
    @test U.dof !== nothing
    @test Symbolics.isequal(U.dof, ν)
end

@testitem "expanded_uncertainty: dof=nothing preserved as nothing" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx   # dof is nothing

    U = expanded_uncertainty(m, 2)
    @test U.dof === nothing
end
