@testitem "REQ-230: monte_carlo needs the extension" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables V σV
    # Without MonteCarloMeasurements loaded the name still exists, and
    # says which package to load rather than raising UndefVarError on
    # a name the documentation mentions.
    @test isdefined(SymbolicUncertainties, :monte_carlo)
    @test MonteCarloComparison isa Type
end

@testitem "REQ-233: the §8.2 test passes where the GUM framework holds" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables V σV I σI

    # `Distributions` exports `±` as well (through `IntervalSets`), so
    # loading it alongside this package makes the operator ambiguous.
    # A Monte Carlo cross-check needs `Distributions` by construction,
    # so these tests use the constructor — which is what a user in the
    # same session has to do.
    S = SymbolicMeasurement(V, σV) + SymbolicMeasurement(I, σI)

    # An exactly linear model with normal inputs: the output really is
    # normal, so the first-order coverage interval is the right one and
    # JCGM 101:2008 §8.2 says so.
    c = monte_carlo(
        S,
        Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.002));
        n = 200_000,
    )
    @test c isa MonteCarloComparison
    @test isapprox(c.u_gum, sqrt(0.01^2 + 0.002^2); rtol = 1e-9)
    @test isapprox(c.u_mc, c.u_gum; rtol = 1e-2)
    @test c.validated
end

@testitem "REQ-233: §8.2 judges the output's shape, not the model's linearity" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables V σV I σI
    S = SymbolicMeasurement(V, σV) + SymbolicMeasurement(I, σI)

    # The same exactly linear model, with rectangular inputs. The
    # linearisation is perfect — a sum has no higher-order terms at
    # all — yet the test fails, because the sum of two uniforms is
    # trapezoidal and `y ± 1.96·u_c` is then the wrong interval.
    #
    # This is the distinction the milestone exists to make: §8.2 tests
    # whether the output may be treated as normal, not whether the
    # model is linear. "GUM validated" and "model is linear" are not
    # the same statement.
    c = monte_carlo(
        S,
        Dict(V => Uniform(4.98, 5.02), I => Uniform(0.096, 0.104));
        n = 200_000,
    )
    @test isapprox(c.u_mc, c.u_gum; rtol = 1e-2)   # the u_c agree…
    @test !c.validated                              # …the intervals do not
end

@testitem "REQ-233: a ratio at 1 % input uncertainty is not validated" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)

    # Ohm's law, the package's own canonical example. A quotient of
    # normals is skewed with heavier tails, so at 1 % relative input
    # uncertainty the sampled interval is both wider and shifted, by
    # far more than the §8.2 tolerance — while `u_c` agrees to four
    # digits. Comparing only `u_c` would have called this validated.
    c = monte_carlo(
        R,
        Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001));
        n = 200_000,
    )
    @test isapprox(
        c.u_gum,
        50 * sqrt((0.01 / 5)^2 + (0.001 / 0.1)^2);
        rtol = 1e-9,
    )
    @test isapprox(c.u_mc, c.u_gum; rtol = 1e-2)
    @test !c.validated

    # Ten times smaller inputs, and the discrepancy collapses with
    # them: the framework's adequacy is a property of the operating
    # point, not of the formula.
    #
    # Asserted on the discrepancy rather than on the verdict. A pass
    # at that operating point sits within a factor of two of the §8.2
    # boundary — the zone where `monte_carlo` itself warns — so
    # `@test fine.validated` would flip between runs for reasons that
    # have nothing to do with the package. Two earlier versions of
    # this test did exactly that.
    Random.seed!(20260902)
    fine = monte_carlo(
        R,
        Dict(V => Normal(5.0, 0.001), I => Normal(0.1, 0.0001));
        n = 400_000,
    )
    d_coarse = max(
        abs(c.interval_gum[1] - c.interval_mc[1]),
        abs(c.interval_gum[2] - c.interval_mc[2]),
    )
    d_fine = max(
        abs(fine.interval_gum[1] - fine.interval_mc[1]),
        abs(fine.interval_gum[2] - fine.interval_mc[2]),
    )
    @test d_fine < 0.2 * d_coarse
end

@testitem "REQ-231: a missing density is refused, never defaulted" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)

    # Defaulting the unnamed input to normal would make the validation
    # circular: a run that assumes normality cannot detect that
    # normality was the wrong assumption.
    err = try
        monte_carlo(R, Dict(V => Normal(5.0, 0.01)); n = 1000)
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    msg = sprint(showerror, err)
    @test occursin("I", msg)
    @test occursin("JCGM 101", msg)
end

@testitem "REQ-234: a Monte Carlo run does not touch the symbolic result" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)

    before_val, before_err = R.val, R.err
    monte_carlo(
        R,
        Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001));
        n = 5_000,
    )

    # It is a check on the framework, not a correction to it.
    @test isequal(R.val, before_val)
    @test isequal(R.err, before_err)
end

@testitem "REQ-232: correlated sources are sampled jointly" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    @variables x σx y σy

    # A difference of two strongly positively correlated inputs: the
    # cross term of JCGM 100:2008 eq. (13) cancels most of the
    # variance, so u_c is far below the uncorrelated value.
    #
    # This is the test that catches the failure mode the milestone was
    # written around. Sampling the two inputs independently would
    # reproduce the uncorrelated answer, and — since the first-order
    # side does honour the correlation — the comparison would report a
    # disagreement, or worse, agree for the wrong reason if the
    # correlation were dropped on both sides.
    a, b = declare_correlated(
        SymbolicMeasurement(x, σx),
        SymbolicMeasurement(y, σy),
        0.9,
    )
    d = a - b

    Random.seed!(20260902)
    c = monte_carlo(
        d,
        Dict(x => Normal(10.0, 0.5), y => Normal(4.0, 0.5));
        n = 400_000,
    )

    # u_c = sqrt(σx² + σy² − 2ρσxσy) = 0.5·sqrt(2 − 2·0.9) ≈ 0.2236,
    # against 0.7071 if the correlation were ignored.
    uncorrelated = sqrt(0.5^2 + 0.5^2)
    @test isapprox(c.u_gum, 0.5 * sqrt(2 - 2 * 0.9); rtol = 1e-9)
    @test c.u_gum < 0.4 * uncorrelated

    # The sampled uncertainty must land on the correlated value, not
    # the uncorrelated one. Independent sampling would give 0.707.
    @test isapprox(c.u_mc, c.u_gum; rtol = 5e-2)
    @test c.u_mc < 0.5 * uncorrelated
    @test c.validated
end

@testitem "REQ-232: an impossible correlation is refused" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables x σx y σy z σz

    # ρ(x,y) = ρ(x,z) = 0.9 with ρ(y,z) = −0.9 has no joint
    # distribution: y and z cannot both track x closely while opposing
    # each other. Pairwise coefficients assigned by hand produce this
    # easily, and the Cholesky factorisation is where it surfaces.
    mx = SymbolicMeasurement(x, σx)
    my = SymbolicMeasurement(y, σy)
    mz = SymbolicMeasurement(z, σz)
    mx, my = declare_correlated(mx, my, 0.9)
    mx, mz = declare_correlated(mx, mz, 0.9)
    my, mz = declare_correlated(my, mz, -0.9)
    m = mx + my + mz

    err = try
        monte_carlo(
            m,
            Dict(
                x => Normal(1.0, 0.1),
                y => Normal(1.0, 0.1),
                z => Normal(1.0, 0.1),
            );
            n = 10_000,
        )
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("positive semi-definite", sprint(showerror, err))
end

@testitem "REQ-232: a non-normal marginal on a correlated input is refused" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables x σx y σy

    # The Cholesky construction preserves the marginals only because
    # they are normal (JCGM 101:2008 §6.4.8). Imposing it on a
    # rectangular marginal would silently change the density the
    # caller stated, so it is refused rather than transformed.
    a, b = declare_correlated(
        SymbolicMeasurement(x, σx),
        SymbolicMeasurement(y, σy),
        0.5,
    )

    err = try
        monte_carlo(
            a - b,
            Dict(x => Normal(10.0, 0.5), y => Uniform(3.0, 5.0));
            n = 10_000,
        )
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    msg = sprint(showerror, err)
    @test occursin("multivariate normal", msg)
    @test occursin("§6.4.8", msg)
end
