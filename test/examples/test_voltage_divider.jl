@testitem "voltage divider exit gate (M2 SC-003)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2

    Vin_m = Vin ± σVin
    R1_m = R1 ± σR1
    R2_m = R2 ± σR2

    Vout = propagate((Vin, R1, R2) -> Vin * R2 / (R1 + R2), [Vin_m, R1_m, R2_m])

    @test Vout isa SymbolicMeasurement

    # Closed-form sensitivity coefficients
    c_Vin = R2 / (R1 + R2)
    c_R1 = -Vin * R2 / (R1 + R2)^2
    c_R2 = Vin * R1 / (R1 + R2)^2

    reference_err = sqrt((c_Vin * σVin)^2 + (c_R1 * σR1)^2 + (c_R2 * σR2)^2)

    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(Vout.err - reference_err), 0)

    dict = Dict(
        Vin => 12.0,
        σVin => 0.05,
        R1 => 1.0e3,
        σR1 => 1.0,
        R2 => 2.0e3,
        σR2 => 2.0,
    )
    numeric_ok = isapprox(
        _as_float(Vout.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-9,
    )

    @test symbolic_ok || numeric_ok
end
