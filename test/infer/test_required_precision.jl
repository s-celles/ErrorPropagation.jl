@testitem "required_precision: delegates to infer_precision" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    a_via_req = required_precision(m, σa, 0.05)
    a_via_inf = infer_precision(m, σa, 0.05)
    # The two must be symbolically identical.
    @test Symbolics.isequal(Symbolics.simplify(a_via_req - a_via_inf), 0)
end

@testitem "required_precision: returns Num" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    result = required_precision(m, σa, 0.05)
    @test result isa Symbolics.Num
end
