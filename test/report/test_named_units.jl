@testitem "REQ-240: a derived unit is reported by its conventional name" begin
    using SymbolicUncertainties
    using Symbolics
    using DynamicQuantities
    using Test

    const DQ = DynamicQuantities

    @variables V I σV σI
    R = (V ± σV) / (I ± σI)
    P = (V ± σV) * (I ± σI)

    readings = Dict(
        V => 10.000DQ.us"V",
        σV => 1e-3DQ.us"V",
        I => 0.10002DQ.us"A",
        σI => 1e-5DQ.us"A",
    )

    # The walk composes units, so a resistance arrives as `A⁻¹ V`.
    # That is correct and is not what a certificate says.
    @test report(R, readings; symbol = "R").unit == "Ω"
    @test report(P, readings; symbol = "P").unit == "W"

    # A frequency, from the RLC model, where the naming has to survive
    # a square root.
    @variables L σL C σC
    f₀ = propagate((l, c) -> 1 / (2π * sqrt(l * c)), [L ± σL, C ± σC])
    rf = report(
        f₀,
        Dict(
            L => 10e-3DQ.us"H",
            σL => 50e-6DQ.us"H",
            C => 1e-6DQ.us"F",
            σC => 5e-9DQ.us"F",
        );
        symbol = "f0",
    )
    @test rf.unit == "Hz"
    @test rf.value ≈ 1591.5 atol = 0.5

    # A prefixed unit must NOT be renamed. `1 kΩ` expands to 1000 base
    # units, so calling the result "Ω" while the number is in kΩ would
    # be wrong by a factor of a thousand — the naming has to check the
    # scale, not just the dimension.
    kilo = Dict(
        V => 10.000DQ.us"V",
        σV => 1e-3DQ.us"V",
        I => 0.10002DQ.us"mA",
        σI => 1e-5DQ.us"mA",
    )
    rk = report(R, kilo; symbol = "R")
    @test rk.unit != "Ω"
    @test rk.value ≈ 99.98 atol = 0.01   # the number is in kΩ, unchanged

    # A dimensionless result gets no unit at all.
    @variables g σg
    ratio = (V ± σV) / (V ± σV)
    @test report(ratio, Dict(V => 10.0DQ.us"V", σV => 1e-3DQ.us"V")).unit == ""

    # VIM §1.1: a dimension does not determine the kind of quantity.
    # Torque and energy share `m² kg s⁻²`, so the table names it `J`
    # and a torque must say otherwise. The escape hatch is the point
    # being tested.
    @variables F σF d σd
    torque = (F ± σF) * (d ± σd)
    vals = Dict(
        F => 12.0DQ.us"N",
        σF => 0.1DQ.us"N",
        d => 0.25DQ.us"m",
        σd => 0.001DQ.us"m",
    )
    @test report(torque, vals; symbol = "M").unit == "J"
    @test report(torque, vals; symbol = "M", unit = "N m").unit == "N m"
end
