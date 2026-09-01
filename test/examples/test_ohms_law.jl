@testitem "Ohm's law exit gate (M1 SC-004)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables V σV I σI
    V_m = V ± σV
    I_m = I ± σI

    R_m = V_m / I_m

    @test R_m isa SymbolicMeasurement

    # The GUM §5.1 reference form for the Ohm's-law uncertainty:
    #   u_R = (V/I) * sqrt((σV/V)^2 + (σI/I)^2)
    reference_err = (V / I) * sqrt((σV / V)^2 + (σI / I)^2)

    # Research R7 two-check strategy:
    # 1. Symbolic simplification attempt
    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(R_m.err - reference_err), 0)

    # 2. Numeric substitution fallback with fixed positive values
    dict = Dict(V => 12.0, σV => 0.1, I => 0.5, σI => 0.005)
    numeric_ok = isapprox(
        _as_float(R_m.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )

    # Either branch is sufficient; both being false fails the exit gate.
    @test symbolic_ok || numeric_ok
end
