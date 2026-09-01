@testitem "REQ-200: repeating `±` declares independent sources" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables Vin σVin R1 σR1 R2 σR2

    # Identity comes from the measurement object, never from the
    # symbol name (REQ-200). Writing `R2 ± σR2` twice therefore
    # declares two independent resistors sharing a tolerance symbol,
    # not one resistor used twice.
    #
    # This is documented behaviour, not a defect — two nominally
    # identical instruments look exactly like this — but it is easy to
    # write by accident, so the difference is pinned here rather than
    # left to be rediscovered.
    wrong = Logging.with_logger(Logging.NullLogger()) do
        (Vin ± σVin) * (R2 ± σR2) / ((R1 ± σR1) + (R2 ± σR2))
    end
    v, r1, r2 = Vin ± σVin, R1 ± σR1, R2 ± σR2
    right = Logging.with_logger(Logging.NullLogger()) do
        v * r2 / (r1 + r2)
    end

    # Four sources against three inputs is the visible symptom.
    @test length(uncertainty_budget(wrong)) == 4
    @test length(uncertainty_budget(right)) == 3

    vals = Dict(
        Vin => 5.0,
        σVin => 0.01,
        R1 => 1000.0,
        σR1 => 10.0,
        R2 => 3000.0,
        σR2 => 20.0,
    )

    # The invisible symptom is the number. Reference computed by hand
    # from JCGM 100:2008 eq. (10) with
    # c_Vin = R2/(R1+R2), c_R1 = -R2·Vin/(R1+R2)², c_R2 = R1·Vin/(R1+R2)².
    c_vin = 3000 / 4000
    c_r1 = -3000 * 5 / 4000^2
    c_r2 = 5 * 1000 / 4000^2
    reference = sqrt((c_vin * 0.01)^2 + (c_r1 * 10)^2 + (c_r2 * 20)^2)

    @test isapprox(_as_float(right.err, vals), reference; rtol = 1e-12)

    # The duplicated form does not merely look different: it reports a
    # materially larger uncertainty, because R2's two sensitivities
    # are added in quadrature instead of being combined first.
    @test _as_float(wrong.err, vals) > 2 * reference
end
