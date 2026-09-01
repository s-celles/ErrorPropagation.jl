@testitem "substitute: extra keys silently ignored (REQ-122)" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx γ z
    m = x ± σx
    # γ and z are not in the measurand; dict keys for them are ignored.
    result = substitute(m, Dict(x => 5.0, σx => 0.1, γ => 99.0, z => -7.0))

    @test Symbolics.value(result.val) == 5.0
    @test Symbolics.value(result.err) == 0.1
end
