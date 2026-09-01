@testitem "mixed-mode binary operators wrap plain operands" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa I

    x = SymbolicMeasurement(a, σa)

    lhs = 2 * x
    rhs = x * 2
    @test lhs isa SymbolicMeasurement
    @test rhs isa SymbolicMeasurement

    @test (x + 1.5) isa SymbolicMeasurement
    @test (1.5 + x) isa SymbolicMeasurement

    @test (x - π) isa SymbolicMeasurement
    @test (π - x) isa SymbolicMeasurement

    @test (x / I) isa SymbolicMeasurement
    @test (I / x) isa SymbolicMeasurement

    dict = Dict(a => 4.0, σa => 0.1)

    # 2*x: uncertainty should be 2 * σa = 0.2
    @test isapprox(_as_float(lhs.err, dict), 0.2; atol = 1e-12)

    # x + 1.5: uncertainty unchanged (1.5 has zero uncertainty)
    @test isapprox(_as_float((x + 1.5).err, dict), 0.1; atol = 1e-12)
end
