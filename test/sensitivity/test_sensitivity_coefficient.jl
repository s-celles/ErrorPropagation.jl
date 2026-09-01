@testitem "sensitivity_coefficient: standard partial on product" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x * y, [a ± σa, b ± σb])

    ca = sensitivity_coefficient(m, a)
    cb = sensitivity_coefficient(m, b)

    @test Symbolics.isequal(Symbolics.simplify(ca - b), 0)
    @test Symbolics.isequal(Symbolics.simplify(cb - a), 0)
end

@testitem "sensitivity_coefficient: variable absent from val returns 0" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa z
    m = a ± σa

    @test Symbolics.isequal(sensitivity_coefficient(m, z), 0)
end

@testitem "sensitivity_coefficient: voltage divider closed form" begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2
    m = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )

    c_Vin = sensitivity_coefficient(m, Vin)
    c_R1 = sensitivity_coefficient(m, R1)
    c_R2 = sensitivity_coefficient(m, R2)

    @test Symbolics.isequal(Symbolics.simplify(c_Vin - R2 / (R1 + R2)), 0)
    @test Symbolics.isequal(
        Symbolics.simplify(c_R1 + Vin * R2 / (R1 + R2)^2),
        0,
    )
    @test Symbolics.isequal(
        Symbolics.simplify(c_R2 - Vin * R1 / (R1 + R2)^2),
        0,
    )
end

@testitem "sensitivity_coefficient: unresolved derivative raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics

    # A @register_symbolic function has no derivative rule in Symbolics;
    # taking a derivative returns an unresolved Differential wrapper.
    # `sensitivity_coefficient` should catch this and raise REQ-021 style.
    Symbolics.@register_symbolic black_box(x)

    @variables x σx
    m = SymbolicMeasurement(black_box(x), σx)

    @test_throws ArgumentError sensitivity_coefficient(m, x)
end
