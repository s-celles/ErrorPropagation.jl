@testitem "substitute: partial substitution leaves remaining symbols" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # Only substitute a and σa; b and σb stay symbolic.
    result = substitute(m, Dict(a => 2.0, σa => 0.1))

    @test result isa SymbolicMeasurement
    # result.val still depends on b
    vars_val = Symbolics.get_variables(result.val)
    @test any(v -> Symbolics.isequal(Symbolics.Num(v), b), vars_val)
    # result.err still depends on σb
    vars_err = Symbolics.get_variables(result.err)
    @test any(v -> Symbolics.isequal(Symbolics.Num(v), σb), vars_err)
end

@testitem "substitute: empty dict is a no-op" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    result = substitute(m, Dict{Symbolics.Num,Float64}())

    @test Symbolics.isequal(result.val, x)
    @test Symbolics.isequal(result.err, σx)
end
