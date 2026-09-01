@testitem "REQ-238: evaluate substitutes unit-carrying values and derives the result's unit" begin
    using SymbolicUncertainties
    using Symbolics
    using DynamicQuantities
    using Test

    const DQ = DynamicQuantities

    @variables V I σV σI

    r = (V ± σV) / (I ± σI)

    vals = Dict(
        V => 5.0DQ.us"V",
        σV => 0.01DQ.us"V",
        I => 0.5DQ.us"A",
        σI => 0.001DQ.us"A",
    )
    got = evaluate(r, vals)

    # The estimate and its uncertainty both come back as quantities,
    # and the unit is derived from the model rather than asserted by
    # the caller — that is the whole point of the call.
    @test got.val isa DQ.AbstractQuantity
    @test got.err isa DQ.AbstractQuantity
    @test DQ.dimension(DQ.uexpand(got.val)) ==
          DQ.dimension(DQ.uexpand(1.0DQ.us"Ω"))
    @test DQ.dimension(DQ.uexpand(got.err)) ==
          DQ.dimension(DQ.uexpand(1.0DQ.us"Ω"))

    # R = V/I = 10 Ω; u_c = R·sqrt((σV/V)² + (σI/I)²).
    @test DQ.ustrip(DQ.uexpand(got.val)) ≈ 10.0
    @test DQ.ustrip(DQ.uexpand(got.err)) ≈
          10.0 * sqrt((0.01 / 5.0)^2 + (0.001 / 0.5)^2)

    # The uncertainty must carry the dimension of the estimate
    # (JCGM 100:2008 §4.3.1); deriving both independently is what makes
    # that checkable rather than assumed.
    @test DQ.dimension(DQ.uexpand(got.val)) == DQ.dimension(DQ.uexpand(got.err))

    # A dimensionless input may be given as a plain number.
    @variables g σg
    scaled = (V ± σV) * (g ± σg)
    got2 = evaluate(
        scaled,
        Dict(V => 5.0DQ.us"V", σV => 0.01DQ.us"V", g => 2.0, σg => 0.0),
    )
    @test DQ.ustrip(DQ.uexpand(got2.val)) ≈ 10.0
    @test DQ.dimension(DQ.uexpand(got2.val)) ==
          DQ.dimension(DQ.uexpand(1.0DQ.us"V"))

    # A model carrying numeric literals is the case that matters most.
    # The dimensional walk lets a literal through as its own value, so
    # a naive implementation folds the `2π` of `f0 = 1/(2π*sqrt(LC))`
    # into the "unit" and returns an answer 2π times too small — wrong,
    # and entirely plausible-looking.
    @variables L σL Cc σCc
    f0 = propagate((l, c) -> 1 / (2π * sqrt(l * c)), [L ± σL, Cc ± σCc])
    got3 = evaluate(
        f0,
        Dict(
            L => 10e-3DQ.us"H",
            σL => 50e-6DQ.us"H",
            Cc => 1e-6DQ.us"F",
            σCc => 5e-9DQ.us"F",
        ),
    )
    @test DQ.ustrip(DQ.uexpand(got3.val)) ≈ 1 / (2π * sqrt(10e-3 * 1e-6))
    @test DQ.dimension(DQ.uexpand(got3.val)) ==
          DQ.dimension(DQ.uexpand(1.0DQ.us"Hz"))

    # Leaving a variable unsubstituted is refused: there is no number
    # to attach a unit to, and silently returning a symbolic result
    # would defeat the call.
    @test_throws ArgumentError evaluate(
        r,
        Dict(V => 5.0DQ.us"V", σV => 0.01DQ.us"V"),
    )
end
