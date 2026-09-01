@testitem "build_evaluator: unsupported target raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    # A bogus target (a Symbol, not one of the dispatched types)
    # should raise ArgumentError listing supported targets.
    @test_throws ArgumentError build_evaluator(m, [x, σx]; target = :bogus)
end

@testitem "build_evaluator: error message mentions supported targets" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    try
        build_evaluator(m, [x, σx]; target = :not_a_target)
        @test false  # should not reach
    catch err
        @test err isa ArgumentError
        msg = err.msg
        @test occursin("JuliaTarget", msg)
        @test occursin("CTarget", msg)
        # FortranTarget deferral note.
        @test occursin("FortranTarget", msg)
    end
end
