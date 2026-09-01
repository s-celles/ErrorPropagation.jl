@testitem "expanded_uncertainty: negative numeric k raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    @test_throws ArgumentError expanded_uncertainty(m, -1)
    @test_throws ArgumentError expanded_uncertainty(m, -0.5)
end

@testitem "expanded_uncertainty: k=0 returns zero uncertainty" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    U = expanded_uncertainty(m, 0)
    @test Symbolics.isequal(Symbolics.simplify(U.U), 0)
    @test Symbolics.isequal(U.val, x)
end
