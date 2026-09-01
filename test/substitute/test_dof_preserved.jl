@testitem "substitute: dof=nothing preserved as nothing" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx   # dof is nothing
    result = substitute(m, Dict(x => 5.0, σx => 0.1))
    @test result.dof === nothing
end

@testitem "substitute: symbolic dof is substituted" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx ν
    m = SymbolicMeasurement(x, σx, ν)
    result = substitute(m, Dict(x => 5.0, σx => 0.1, ν => 25.0))

    @test result.dof !== nothing
    @test Symbolics.value(result.dof) == 25.0
end

@testitem "substitute: symbolic dof left symbolic when not in dict" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx ν
    m = SymbolicMeasurement(x, σx, ν)
    # Do not substitute ν — it should stay symbolic.
    result = substitute(m, Dict(x => 5.0, σx => 0.1))

    @test result.dof !== nothing
    @test Symbolics.isequal(result.dof, ν)
end
