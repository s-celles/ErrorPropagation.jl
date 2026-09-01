@testitem "M12: check_units reports, it does not throw" begin
    using SymbolicUncertainties
    using Symbolics
    using DynamicQuantities
    using Test

    @variables V I R

    # A dimensionally sound model produces an empty report.
    ok = check_units(
        V / I,
        Dict(V => DynamicQuantities.u"V", I => DynamicQuantities.u"A"),
    )
    @test ok isa UnitReport
    @test isempty(ok.findings)
    @test SymbolicUncertainties.is_consistent(ok)

    # A wrong one produces findings — and still RETURNS. A user
    # exploring a model must not be halted mid-derivation by a unit
    # typo; that is the whole point of an opt-in checker.
    bad = check_units(
        V + I,
        Dict(V => DynamicQuantities.u"V", I => DynamicQuantities.u"A"),
    )
    @test bad isa UnitReport
    @test !isempty(bad.findings)
    @test !SymbolicUncertainties.is_consistent(bad)

    # The finding says what was added to what.
    f = first(bad.findings)
    @test occursin("+", f.what)
end

@testitem "M12: dimensions propagate through the expression" begin
    using SymbolicUncertainties
    using Symbolics
    using DynamicQuantities
    using Test

    @variables V I t

    units = Dict(
        V => DynamicQuantities.u"V",
        I => DynamicQuantities.u"A",
        t => DynamicQuantities.u"s",
    )

    # Products and quotients combine dimensions; a sum of like
    # dimensions is fine; transcendental functions demand a
    # dimensionless argument.
    @test SymbolicUncertainties.is_consistent(check_units(V * I, units))
    @test SymbolicUncertainties.is_consistent(check_units(V / I, units))
    @test SymbolicUncertainties.is_consistent(check_units(V * I * t, units))
    @test !SymbolicUncertainties.is_consistent(check_units(exp(t), units))
    @test SymbolicUncertainties.is_consistent(check_units(exp(t / t), units))
end

@testitem "M12: a measurement is checked through its estimate" begin
    using SymbolicUncertainties
    using Symbolics
    using DynamicQuantities
    using Test

    @variables V σV I σI
    m = (V ± σV) / (I ± σI)

    rep = check_units(
        m,
        Dict(
            V => DynamicQuantities.u"V",
            σV => DynamicQuantities.u"V",
            I => DynamicQuantities.u"A",
            σI => DynamicQuantities.u"A",
        ),
    )
    @test SymbolicUncertainties.is_consistent(rep)

    # An uncertainty whose dimension differs from its estimate is the
    # single most common unit error in a budget, and it is caught.
    bad = check_units(
        m,
        Dict(
            V => DynamicQuantities.u"V",
            σV => DynamicQuantities.u"A",
            I => DynamicQuantities.u"A",
            σI => DynamicQuantities.u"A",
        ),
    )
    @test !SymbolicUncertainties.is_consistent(bad)
end
