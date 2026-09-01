@testitem "JCGM Annex H.1: end-gauge calibration" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # JCGM 100:2008 §H.1. The length of an end gauge is determined by
    # comparison with a reference standard of known length:
    #
    #   l = ls + d − ls(δα·θ + αs·δθ)
    #
    # Where §H.2 exercises correlation, this one exercises the
    # BUDGET: six input quantities of different natures, two of them
    # carrying finite degrees of freedom, so it validates the
    # source-derived budget, Welch-Satterthwaite and the coverage
    # factor in one model.
    #
    # Lengths in nanometres, temperatures in degrees Celsius.
    @variables ls σls d σd αs σαs θ σθ δα σδα δθ σδθ

    # ν = ∞ for the type-B evaluations; a large finite value keeps the
    # Welch-Satterthwaite expression free of Inf arithmetic.
    big = Symbolics.Num(1.0e12)

    m_ls = SymbolicMeasurement(ls, σls, Symbolics.Num(18.0))
    m_d = SymbolicMeasurement(d, σd, Symbolics.Num(25.6))
    m_αs = SymbolicMeasurement(αs, σαs, big)
    m_θ = SymbolicMeasurement(θ, σθ, big)
    m_δα = SymbolicMeasurement(δα, σδα, big)
    m_δθ = SymbolicMeasurement(δθ, σδθ, Symbolics.Num(2.0))

    l = m_ls + m_d - m_ls * (m_δα * m_θ + m_αs * m_δθ)

    vals = Dict(
        ls => 50.000623e6,
        σls => 25.0,
        d => 215.0,
        σd => 9.7,
        αs => 11.5e-6,
        σαs => 1.2e-6,
        θ => -0.1,
        σθ => 0.41,
        δα => 0.0,
        σδα => 0.58e-6,
        δθ => 0.0,
        σδθ => 0.029,
    )

    # Estimate: 50.000838 mm.
    @test isapprox(_as_float(l.val, vals) / 1e6, 50.000838; rtol = 1e-9)

    # Combined standard uncertainty: 32 nm.
    @test isapprox(_as_float(l.err, vals), 32.0; rtol = 2e-2)

    # Effective degrees of freedom: 16. The reference truncates
    # downwards, which is the conservative convention of §G.4.1.
    @test isapprox(_as_float(l.dof, vals), 16.0; rtol = 5e-2)

    # Coverage factor 2.13 and expanded uncertainty 68 nm at 95 %.
    U = expanded_uncertainty(l; coverage_probability = 0.95)
    @test isapprox(_as_float(U.k, vals), 2.13; rtol = 2e-2)
    @test isapprox(_as_float(U.U, vals), 68.0; rtol = 2e-2)
end

@testitem "JCGM Annex H.1: the budget rows match the contributions" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The two inputs whose sensitivity coefficients vanish at the
    # estimates — αs and θ, since δθ and δα are both zero — must carry
    # no weight, while still appearing as sources of the model. This
    # is §H.1.3's point that a coefficient may nullify a contribution
    # without the quantity being irrelevant to the model.
    @variables ls σls d σd αs σαs θ σθ δα σδα δθ σδθ

    # `ls` appears twice in the model and is ONE measurement of the
    # reference standard, so it must be bound once. Writing `ls ± σls`
    # twice would mint two independent sources — correct behaviour,
    # and the mistake M11 makes visible instead of silently averaging
    # away.
    m_ls = ls ± σls
    l =
        m_ls + (d ± σd) -
        m_ls * ((δα ± σδα) * (θ ± σθ) + (αs ± σαs) * (δθ ± σδθ))

    vals = Dict(
        ls => 50.000623e6,
        σls => 25.0,
        d => 215.0,
        σd => 9.7,
        αs => 11.5e-6,
        σαs => 1.2e-6,
        θ => -0.1,
        σθ => 0.41,
        δα => 0.0,
        σδα => 0.58e-6,
        δθ => 0.0,
        σδθ => 0.029,
    )

    rows = uncertainty_budget(l)
    contributions = sort([_as_float(r.contribution, vals) for r in rows])

    # Two contributions are exactly zero at these estimates.
    @test count(c -> c < 1e-9, contributions) == 2

    # The non-zero ones recombine into u_c.
    quad = sqrt(sum(c^2 for c in contributions))
    @test isapprox(quad, _as_float(l.err, vals); rtol = 1e-9)
end
