@testitem "expanded_uncertainty: default k=2" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    U = expanded_uncertainty(m)
    @test U isa ExpandedUncertainty
    @test Symbolics.isequal(U.val, x)
    @test Symbolics.isequal(Symbolics.simplify(U.U - 2σx), 0)

    U2 = expanded_uncertainty(m, 2)
    @test Symbolics.isequal(Symbolics.simplify(U.U - U2.U), 0)
end

@testitem "expanded_uncertainty: arbitrary numeric k" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    U = expanded_uncertainty(m, 3)
    @test Symbolics.isequal(Symbolics.simplify(U.U - 3σx), 0)
end
