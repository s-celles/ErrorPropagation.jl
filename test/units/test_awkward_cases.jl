@testitem "M12 case 1: affine temperatures are not additive" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: Affine
    using Symbolics
    using DynamicQuantities
    using Test

    @variables T1 T2

    # 20 °C + 20 °C is not 40 °C. Absolute affine temperatures do not
    # add; only their DIFFERENCES are proper kelvin intervals. A plain
    # dimension check passes this happily — both sides are Θ — which
    # is exactly why it needs its own rule.
    celsius = Affine(DynamicQuantities.u"K", :celsius, 273.15)
    units = Dict(T1 => celsius, T2 => celsius)

    sum_rep = check_units(T1 + T2, units)
    @test !SymbolicUncertainties.is_consistent(sum_rep)
    @test occursin("affine", lowercase(first(sum_rep.findings).why))

    # The difference is fine, and is a kelvin interval.
    diff_rep = check_units(T1 - T2, units)
    @test SymbolicUncertainties.is_consistent(diff_rep)

    # An uncertainty stated in °C is a kelvin interval, never an
    # absolute temperature (JCGM 100:2008 §4.3.1 — u is a dispersion).
    @test SymbolicUncertainties.interval_unit(celsius) == DynamicQuantities.u"K"
end

@testitem "M12 case 2: dimensionless is not interchangeable" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: Scaled
    using Symbolics
    using DynamicQuantities
    using Test

    @variables a b

    # %, ppm and dB are all dimensionless. None is interchangeable
    # with another, and dB is logarithmic so it does not even add
    # like the other two. Dimension equality cannot see any of this.
    pct = Scaled(:percent, 1e-2)
    ppm = Scaled(:ppm, 1e-6)

    mixed = check_units(a + b, Dict(a => pct, b => ppm))
    @test !SymbolicUncertainties.is_consistent(mixed)
    @test occursin("scale", lowercase(first(mixed.findings).why))

    same = check_units(a + b, Dict(a => pct, b => pct))
    @test SymbolicUncertainties.is_consistent(same)

    # dB is logarithmic: adding it to a linear ratio is meaningless
    # even though both are dimensionless.
    db = Scaled(:dB, nothing; logarithmic = true)
    log_mix = check_units(a + b, Dict(a => db, b => pct))
    @test !SymbolicUncertainties.is_consistent(log_mix)
    @test occursin("logarithmic", lowercase(first(log_mix.findings).why))
end

@testitem "M12 case 3: same dimension, different quantity" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: Kind
    using Symbolics
    using DynamicQuantities
    using Test

    @variables M E f A

    # Torque and energy are both N·m; activity and frequency are both
    # s⁻¹. They must not silently unify — adding a torque to an energy
    # is a modelling error that dimensional analysis alone declares
    # valid. VIM §1.1: a quantity is not defined by its dimension.
    torque = Kind(DynamicQuantities.u"N*m", :torque)
    energy = Kind(DynamicQuantities.u"N*m", :energy)

    bad = check_units(M + E, Dict(M => torque, E => energy))
    @test !SymbolicUncertainties.is_consistent(bad)
    @test occursin("kind", lowercase(first(bad.findings).why))

    @test SymbolicUncertainties.is_consistent(
        check_units(M + M, Dict(M => torque)),
    )

    # Activity (Bq) versus frequency (Hz) — the same trap in
    # radiological metrology.
    activity = Kind(DynamicQuantities.u"s^-1", :activity)
    frequency = Kind(DynamicQuantities.u"s^-1", :frequency)
    @test !SymbolicUncertainties.is_consistent(
        check_units(f + A, Dict(f => frequency, A => activity)),
    )
end
