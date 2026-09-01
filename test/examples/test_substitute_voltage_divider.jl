@testitem "M4 exit-gate: substitute voltage-divider to numeric" begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2
    Vout = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )

    result = substitute(
        Vout,
        Dict(
            Vin => 5.0,
            R1 => 1_000.0,
            R2 => 3_000.0,
            σVin => 0.01,
            σR1 => 1.0,
            σR2 => 1.0,
        ),
    )

    # Hand-computed reference:
    # Vout  = 5 * 3000 / 4000 = 3.75 V
    # u_Vin = (R2/(R1+R2))·σVin = 0.75 · 0.01 = 0.0075
    # u_R1  = Vin·R2/(R1+R2)²·σR1 = 15000/16e6 · 1 = 9.375e-4
    # u_R2  = Vin·R1/(R1+R2)²·σR2 = 5000/16e6 · 1 = 3.125e-4
    # u_c² = 0.0075² + 9.375e-4² + 3.125e-4²
    #       = 5.625e-5 + 8.789e-7 + 9.766e-8
    #       ≈ 5.7226e-5
    # u_c ≈ 0.0075648...
    expected_val = 3.75
    expected_err_sq = 0.0075^2 + (15000 / 16e6)^2 + (5000 / 16e6)^2
    expected_err = sqrt(expected_err_sq)

    # Force numeric evaluation of sqrt(...) — Symbolics.substitute leaves
    # it symbolic; we use toexpr+eval (UB-001) to get a concrete Float64.
    @test isapprox(
        Float64(eval(Symbolics.toexpr(result.val))),
        expected_val;
        atol = 1e-12,
    )
    @test isapprox(
        Float64(eval(Symbolics.toexpr(result.err))),
        expected_err;
        atol = 1e-12,
    )
end
