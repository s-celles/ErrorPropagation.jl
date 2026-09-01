@testitem "M14 exit: JCGM Annex H.1 propagated both ways" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    # §H.1, the end-gauge comparison. Six inputs of different natures,
    # a mildly nonlinear model, all Type A and Type B evaluations
    # treated as normal — the regime the GUM framework is built for.
    # The two methods must agree under §8.2, and this is the check
    # that does not come from the first-order framework itself.
    @variables ls σls d σd αs σαs θ σθ δα σδα δθ σδθ

    m_ls = SymbolicMeasurement(ls, σls)
    m_d = SymbolicMeasurement(d, σd)
    m_αs = SymbolicMeasurement(αs, σαs)
    m_θ = SymbolicMeasurement(θ, σθ)
    m_δα = SymbolicMeasurement(δα, σδα)
    m_δθ = SymbolicMeasurement(δθ, σδθ)

    l = m_ls + m_d - m_ls * (m_δα * m_θ + m_αs * m_δθ)

    Random.seed!(20260902)
    c = monte_carlo(
        l,
        Dict(
            ls => Normal(50.000623e6, 25.0),
            d => Normal(215.0, 9.7),
            αs => Normal(11.5e-6, 1.2e-6),
            θ => Normal(-0.1, 0.41),
            δα => Normal(0.0, 0.58e-6),
            δθ => Normal(0.0, 0.029),
        );
        n = 400_000,
    )

    # The published figures: 50.000838 mm, u_c = 32 nm.
    @test isapprox(c.estimate_gum / 1e6, 50.000838; rtol = 1e-9)
    @test isapprox(c.u_gum, 32.0; rtol = 2e-2)
    @test isapprox(c.estimate_mc, c.estimate_gum; rtol = 1e-9)

    # And it is NOT validated — which is the finding, not a defect.
    #
    # The model carries the product `ls·δα·θ`, and §H.1 estimates
    # δα = 0. The first-order sensitivity to θ is therefore
    # −ls·δα = 0: the GUM framework assigns θ no contribution at all.
    # Sampling multiplies a non-zero δα by a non-zero θ and recovers a
    # variance the linearisation cannot see, of size ls·u(δα)·u(θ).
    #
    # This is a second-order term in the strict sense — a product of
    # two inputs whose estimates are zero — and it is the caveat of
    # JCGM 100:2008 §5.1.2 note 1. The GUM's own worked example does
    # not pass its own supplement's validation test, which is worth
    # knowing and is exactly what a cross-check that does not come
    # from the first-order framework is for.
    @test !c.validated

    missed = 50.000623e6 * 0.58e-6 * 0.41
    @test isapprox(sqrt(c.u_gum^2 + missed^2), c.u_mc; rtol = 3e-2)
end

@testitem "M14 exit: JCGM Annex H.4 with its declared correlation" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    # §H.4, radon massic activity. The sample and standard counting
    # rates come from the same six cycles, r(Rx, RS) = 0.646, and
    # because they enter as a ratio the cross term REDUCES u_c.
    # Sampling them independently would inflate the sampled
    # uncertainty and the comparison would fail — this is the case
    # that exercises the joint-sampling path on published numbers.
    @variables AS σAS mS σmS mx σmx Rx σRx RS σRS

    rx, rs = declare_correlated(
        SymbolicMeasurement(Rx, σRx),
        SymbolicMeasurement(RS, σRS),
        0.646,
    )
    Ax =
        SymbolicMeasurement(AS, σAS) *
        (SymbolicMeasurement(mS, σmS) / SymbolicMeasurement(mx, σmx)) *
        (rx / rs)

    Random.seed!(20260902)
    c = monte_carlo(
        Ax,
        Dict(
            AS => Normal(0.1368, 0.0018),
            mS => Normal(5.0192, 0.0050),
            mx => Normal(5.0571, 0.0010),
            Rx => Normal(652.60, 6.42),
            RS => Normal(206.09, 3.79),
        );
        n = 400_000,
    )

    # The published figures: 0.4300 Bq/g, u_c = 0.0083 Bq/g.
    @test isapprox(c.estimate_gum, 0.4300; rtol = 1e-3)
    @test isapprox(c.u_gum, 0.0083; rtol = 2e-2)

    # The sampled uncertainty must land on the correlated value. The
    # uncorrelated one is about a third larger, so an independent
    # draw would be unmistakable here.
    @test isapprox(c.u_mc, c.u_gum; rtol = 5e-2)
    uncorrelated =
        0.4300 * sqrt(
            (0.0018 / 0.1368)^2 +
            (0.0050 / 5.0192)^2 +
            (0.0010 / 5.0571)^2 +
            (6.42 / 652.60)^2 +
            (3.79 / 206.09)^2,
        )
    @test c.u_mc < 0.8 * uncorrelated
end

@testitem "M14 exit: a disagreement that linearisation_bound predicts" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test
    using Logging

    @variables x σx

    # A milestone that can only demonstrate agreement demonstrates
    # nothing. `exp` at a large input uncertainty is where the
    # first-order law genuinely breaks: the estimate itself is wrong,
    # since E[exp(X)] = exp(μ)·exp(σ²/2) ≠ exp(μ).
    m = exp(SymbolicMeasurement(x, σx))

    Random.seed!(20260902)
    c = monte_carlo(m, Dict(x => Normal(0.0, 0.8)); n = 400_000)

    @test !c.validated

    # The sampled mean exceeds the first-order estimate by the factor
    # exp(σ²/2) — the second-order term the GUM framework drops.
    @test isapprox(c.estimate_mc / c.estimate_gum, exp(0.8^2 / 2); rtol = 5e-2)

    # And the package's own diagnostics predict it beforehand, from
    # the symbolic Hessian alone, without sampling anything.
    bound = Logging.with_logger(Logging.NullLogger()) do
        linearisation_bound(
            z -> exp(z),
            [SymbolicMeasurement(x, σx)];
            values = Dict(x => 0.0, σx => 0.8),
        )
    end
    @test bound > 0.1 * c.u_gum

    correction =
        second_order_correction(z -> exp(z), [SymbolicMeasurement(x, σx)])
    corrected = Symbolics.substitute(correction, Dict(x => 0.0, σx => 0.8))
    # `substitute` does not itself evaluate (upstream-bugs.md UB-001),
    # so go through `toexpr` as the rest of the suite does.
    @test eval(Symbolics.toexpr(Symbolics.value(corrected))) > 0
end

@testitem "M14 exit: JCGM Annex H.2 with three mutually correlated inputs" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    # §H.2.3. Voltage, current and phase come from the same five
    # observation series, so all three are mutually correlated:
    # r(V,I) = −0.36, r(V,φ) = 0.86, r(I,φ) = −0.65. This is the case
    # that exercises the joint sampling on a 3×3 covariance rather
    # than a pair, and the published correlations are consistent — the
    # matrix is positive definite, which the Cholesky path requires.
    @variables V σV I σI φ σφ

    v0 = SymbolicMeasurement(V, σV)
    i0 = SymbolicMeasurement(I, σI)
    p0 = SymbolicMeasurement(φ, σφ)

    v1, i1 = declare_correlated(v0, i0, -0.36)
    i2, p1 = declare_correlated(i1, p0, -0.65)
    v2, p2 = declare_correlated(v1, p1, 0.86)

    R = (v2 / i2) * cos(p2)

    spec = Dict(
        V => Normal(4.999, 0.0032),
        I => Normal(19.661e-3, 0.0095e-3),
        φ => Normal(1.04446, 0.00075),
    )

    Random.seed!(20260903)
    c = monte_carlo(R, spec; n = 400_000)

    # The published figure of §H.2.3: u(R) = 0.071 Ω.
    @test isapprox(c.estimate_gum, 127.732; rtol = 1e-4)
    @test isapprox(c.u_gum, 0.071; rtol = 2e-2)

    # Ignoring the correlations gives 0.203 Ω — nearly three times as
    # much. Sampling the inputs independently would land there, so
    # this assertion is what proves the joint draw is real.
    @test isapprox(c.u_mc, c.u_gum; rtol = 5e-2)
    @test c.u_mc < 0.15

    # Relative input uncertainties are below 0.1 %, so the model is
    # effectively linear over the coverage region and the framework
    # holds.
    @test c.validated
end

@testitem "M14 exit: JCGM Annex H.3, correlation from an adjustment" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    # §H.3. A thermometer's correction is fitted as
    # b(t) = y₁ + y₂·(t − t₀), and the two fitted parameters are
    # strongly anticorrelated, r = −0.930, because they come from the
    # same least-squares adjustment rather than from shared inputs.
    #
    # The model is exactly linear in y₁ and y₂ with normal marginals,
    # so the output is exactly normal: this is the case where the §8.2
    # test must pass, and where a failure would indict the sampling
    # rather than the framework.
    @variables y1 σy1 y2 σy2

    c1, c2 = declare_correlated(
        SymbolicMeasurement(y1, σy1),
        SymbolicMeasurement(y2, σy2),
        -0.930,
    )
    b30 = c1 + c2 * (30.0 - 20.0)

    Random.seed!(20260903)
    c = monte_carlo(
        b30,
        Dict(y1 => Normal(-0.1712, 0.0029), y2 => Normal(0.00218, 0.000067));
        n = 400_000,
    )

    # §H.3.3: b(30 °C) = −0.1494 °C. The anticorrelation REDUCES the
    # uncertainty below the independent value, which is the whole
    # point of the example.
    @test isapprox(c.estimate_gum, -0.1494; rtol = 1e-3)
    independent = sqrt(0.0029^2 + (10.0 * 0.000067)^2)
    @test c.u_gum < independent

    @test isapprox(c.u_mc, c.u_gum; rtol = 5e-2)
    @test c.u_mc < independent
    @test c.validated
end

@testitem "M14 exit: JCGM 102 output correlation, both ways" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    # JCGM 102:2011 §6 asks for the covariance matrix of a
    # vector-valued measurand, not only its marginal uncertainties —
    # that matrix is what a downstream user needs to combine the
    # outputs further.
    #
    # It cannot be checked one output at a time: two separate
    # `monte_carlo` calls draw independent inputs and would measure a
    # correlation of zero by construction. The outputs are evaluated
    # on a single draw.
    #
    # §H.2's three outputs descend from the same three measurements,
    # so they are mutually correlated even with independent inputs.
    @variables V σV I σI φ σφ
    v = SymbolicMeasurement(V, σV)
    i = SymbolicMeasurement(I, σI)
    p = SymbolicMeasurement(φ, σφ)

    R = (v / i) * cos(p)
    X = (v / i) * sin(p)
    Z = v / i

    Random.seed!(20260903)
    res = monte_carlo(
        [R, X, Z],
        Dict(
            V => Normal(4.999, 0.0032),
            I => Normal(19.661e-3, 0.0095e-3),
            φ => Normal(1.04446, 0.00075),
        );
        n = 400_000,
    )

    # Each output stands on its own §8.2 comparison.
    @test length(res.per_output) == 3
    @test all(c -> c.validated, res.per_output)
    # Independent inputs here — §H.2.2, not §H.2.3 — because the
    # point of this case is that the OUTPUTS are correlated even when
    # the inputs are not. u(Z) is therefore the uncorrelated value,
    # asserted in closed form rather than transcribed: 0.236 belongs
    # to the correlated regime and is checked in `test/annexh/`.
    Z_est = 4.999 / 19.661e-3
    @test isapprox(
        res.per_output[3].u_gum,
        Z_est * sqrt((0.0032 / 4.999)^2 + (0.0095e-3 / 19.661e-3)^2);
        rtol = 1e-9,
    )

    # And the sampled correlation matrix reproduces the symbolic one,
    # which is the part no scalar comparison reaches.
    for i in 1:3, j in 1:3
        @test isapprox(
            res.correlation_mc[i, j],
            res.correlation_gum[i, j];
            atol = 2e-2,
        )
    end

    # Not a trivial agreement: R and Z share V and I entirely, so the
    # off-diagonal is far from zero, and the matrix is symmetric with
    # a unit diagonal.
    @test res.correlation_gum[1, 3] > 0.5
    @test isapprox(
        res.correlation_mc[1, 3],
        res.correlation_mc[3, 1];
        atol = 1e-12,
    )
    @test all(isapprox(res.correlation_mc[i, i], 1.0) for i in 1:3)
end
