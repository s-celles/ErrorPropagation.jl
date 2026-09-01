@testitem "dominant_source: numeric path picks the larger contribution" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # σb = 10·σa, so b should dominate.
    dom = dominant_source(
        m,
        [a, b],
        [σa, σb];
        values = Dict(a => 1.0, b => 1.0, σa => 0.01, σb => 0.1),
    )
    @test dom.index == 2
    @test Symbolics.isequal(dom.variable, b)
    @test dom.ranked_by == :numeric
end

@testitem "dominant_source: numeric path reverses with substitution" begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    m = propagate((x, y) -> x + y, [a ± σa, b ± σb])

    # σa = 10·σb, so a should dominate.
    dom = dominant_source(
        m,
        [a, b],
        [σa, σb];
        values = Dict(a => 1.0, b => 1.0, σa => 0.1, σb => 0.01),
    )
    @test dom.index == 1
    @test Symbolics.isequal(dom.variable, a)
end

@testitem "dominant_source: voltage divider numeric dominance" begin
    using SymbolicUncertainties
    using Symbolics

    @variables Vin σVin R1 σR1 R2 σR2
    m = propagate(
        (vin, r1, r2) -> vin * r2 / (r1 + r2),
        [Vin ± σVin, R1 ± σR1, R2 ± σR2],
    )

    # With these values the individual contributions are:
    # u_Vin = (R2/(R1+R2))·σVin = 0.75·0.01 = 0.0075 V
    # u_R1  = Vin·R2/(R1+R2)²·σR1 = 15000/16e6·10 = 0.009375 V
    # u_R2  = Vin·R1/(R1+R2)²·σR2 = 5000/16e6·10 = 0.003125 V
    # So R1 (index 2) is dominant.
    dom = dominant_source(
        m,
        [Vin, R1, R2],
        [σVin, σR1, σR2];
        values = Dict(
            Vin => 5.0,
            R1 => 1_000.0,
            R2 => 3_000.0,
            σVin => 0.01,
            σR1 => 10.0,
            σR2 => 10.0,
        ),
    )
    @test dom.ranked_by == :numeric
    @test dom.index == 2
    @test Symbolics.isequal(dom.variable, R1)
end
