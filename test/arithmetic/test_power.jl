@testitem "^ propagates power rule per GUM §5.1" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa n

    x = SymbolicMeasurement(a, σa)

    dict = Dict(a => 2.5, σa => 0.1)

    # Case 1: integer exponent 2
    p2 = x^2
    @test p2 isa SymbolicMeasurement
    ref2 = abs(2 * a^(2 - 1)) * σa
    @test isapprox(_as_float(p2.err, dict), _as_float(ref2, dict); atol = 1e-12)

    # Case 2: rational exponent 1//2 (evaluated on a positive estimate)
    p_half = x^(1//2)
    @test p_half isa SymbolicMeasurement
    ref_half = abs((1//2) * a^(1//2 - 1)) * σa
    @test isapprox(
        _as_float(p_half.err, dict),
        _as_float(ref_half, dict);
        atol = 1e-12,
    )

    # Case 3: symbolic exponent n
    pn = x^n
    @test pn isa SymbolicMeasurement
    ref_n = abs(n * a^(n - 1)) * σa
    dict_n = Dict(a => 2.5, σa => 0.1, n => 3.0)
    @test isapprox(
        _as_float(pn.err, dict_n),
        _as_float(ref_n, dict_n);
        atol = 1e-12,
    )
end
