@testitem "propagate: two-input addition" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    a_m = a ± σa
    b_m = b ± σb

    result = propagate((x, y) -> x + y, [a_m, b_m])

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - (a + b)), 0)

    reference_err = sqrt(σa^2 + σb^2)
    dict = Dict(a => 12.0, σa => 0.1, b => 5.0, σb => 0.05)
    symbolic_ok =
        Symbolics.isequal(Symbolics.simplify(result.err - reference_err), 0)
    numeric_ok = isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
    @test symbolic_ok || numeric_ok
end

@testitem "propagate: three-input product" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb c σc
    a_m = a ± σa
    b_m = b ± σb
    c_m = c ± σc

    result = propagate((x, y, z) -> x * y * z, [a_m, b_m, c_m])

    @test result isa SymbolicMeasurement
    @test Symbolics.isequal(Symbolics.simplify(result.val - (a * b * c)), 0)

    reference_err = sqrt((b * c * σa)^2 + (a * c * σb)^2 + (a * b * σc)^2)
    dict =
        Dict(a => 2.0, σa => 0.01, b => 3.0, σb => 0.02, c => 4.0, σc => 0.03)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end

@testitem "propagate: nonlinear exp·sin" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx y σy
    x_m = x ± σx
    y_m = y ± σy

    result = propagate((u, v) -> exp(u) * sin(v), [x_m, y_m])

    @test result isa SymbolicMeasurement

    # Reference sensitivity coefficients: ∂f/∂u = exp(u)·sin(v),
    # ∂f/∂v = exp(u)·cos(v)
    reference_err = sqrt((exp(x) * sin(y) * σx)^2 + (exp(x) * cos(y) * σy)^2)
    dict = Dict(x => 0.5, σx => 0.01, y => 0.3, σy => 0.005)
    @test isapprox(
        _as_float(result.err, dict),
        _as_float(reference_err, dict);
        atol = 1e-12,
    )
end
