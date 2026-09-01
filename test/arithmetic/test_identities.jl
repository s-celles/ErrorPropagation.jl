@testitem "arithmetic identities hold after simplify" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    x = SymbolicMeasurement(a, σa)
    y = SymbolicMeasurement(b, σb)

    # Commutativity of addition on the estimate
    @test Symbolics.isequal(Symbolics.simplify((x + y).val - (y + x).val), 0)

    # Commutativity of multiplication on the estimate
    @test Symbolics.isequal(Symbolics.simplify((x * y).val - (y * x).val), 0)

    # Commutativity of addition on the propagated uncertainty — sums
    # are symmetric in σa and σb, so the err expressions must be
    # equivalent when evaluated numerically.
    dict = Dict(a => 1.0, σa => 0.2, b => 3.0, σb => 0.4)
    lhs = _as_float((x + y).err, dict)
    rhs = _as_float((y + x).err, dict)
    @test isapprox(lhs, rhs; atol = 1e-12)
end
