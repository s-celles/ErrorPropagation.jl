@testitem "to_expr: returns Tuple{Num, Num} of (val, err)" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    result = to_expr(m)
    @test result isa Tuple
    @test length(result) == 2
    @test result[1] isa Symbolics.Num
    @test result[2] isa Symbolics.Num
    @test Symbolics.isequal(result[1], m.val)
    @test Symbolics.isequal(result[2], m.err)
end

@testitem "to_expr: destructures cleanly" begin
    using SymbolicUncertainties
    using Symbolics

    m = 5.0 ± 0.1
    v, e = to_expr(m)
    @test Symbolics.isequal(v, m.val)
    @test Symbolics.isequal(e, m.err)
end

@testitem "to_expr: does not include dof" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx ν
    m = SymbolicMeasurement(x, σx, ν)
    result = to_expr(m)
    @test length(result) == 2
    # dof is not in the tuple.
    @test Symbolics.isequal(result[1], x)
    @test Symbolics.isequal(result[2], σx)
end
