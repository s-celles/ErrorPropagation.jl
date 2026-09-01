@testitem "relative_sensitivity: fractions sum to 1 on sum" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    ra = relative_sensitivity(m, a, σa)
    rb = relative_sensitivity(m, b, σb)

    # For a pure sum, m.err² = σa² + σb²; each relative = σᵢ²/(σa²+σb²).
    total = Symbolics.simplify(ra + rb)
    @test Symbolics.isequal(total, 1)
end

@testitem "relative_sensitivity: voltage divider invariant (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2
    m = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )

    r_Vin = relative_sensitivity(m, Vin, σVin)
    r_R1 = relative_sensitivity(m, R1, σR1)
    r_R2 = relative_sensitivity(m, R2, σR2)

    dict = Dict(
        Vin => 5.0,
        R1 => 1_000.0,
        R2 => 3_000.0,
        σVin => 0.01,
        σR1 => 1.0,
        σR2 => 1.0,
    )

    total =
        _as_float(r_Vin, dict) + _as_float(r_R1, dict) + _as_float(r_R2, dict)
    @test isapprox(total, 1.0; atol = 1e-10)
end
