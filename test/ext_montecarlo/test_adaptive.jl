@testitem "REQ-237: the adaptive procedure stabilises the verdict" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)
    spec = Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001))

    # JCGM 101:2008 §7.9 draws blocks of M trials until the results of
    # interest have stabilised in a statistical sense: twice the
    # standard deviation of the block means, for the estimate, u(y)
    # and both interval endpoints, must fall below the numerical
    # tolerance δ. Without it the verdict is only as trustworthy as
    # whatever `n` the caller happened to pass.
    Random.seed!(20260903)
    c = monte_carlo(spec === nothing ? R : R, spec; adaptive = true, n = 20_000)

    @test c isa MonteCarloComparison
    @test c.blocks >= 2
    @test c.converged
    @test c.n == c.blocks * 20_000

    # The stabilised result must agree with a single large run to
    # within the tolerance it just certified.
    Random.seed!(20260903)
    plain = monte_carlo(R, spec; n = 200_000)
    @test isapprox(c.u_mc, plain.u_mc; rtol = 5e-2)
    @test c.validated == plain.validated
end

@testitem "REQ-237: not converging is reported, not hidden" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test
    using Logging

    @variables V σV I σI
    R = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)

    # Capped at two blocks of a thousand trials, the procedure cannot
    # stabilise. It must say so rather than return the last block as
    # though it had converged — an unstabilised result read as a
    # metrological finding is the failure §7.9 exists to prevent.
    Random.seed!(20260903)
    c = Logging.with_logger(Logging.NullLogger()) do
        monte_carlo(
            R,
            Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001));
            adaptive = true,
            n = 1_000,
            max_blocks = 2,
        )
    end
    @test !c.converged
    @test c.blocks == 2

    @test_logs (:warn,) match_mode = :any monte_carlo(
        R,
        Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001));
        adaptive = true,
        n = 1_000,
        max_blocks = 2,
    )
end

@testitem "REQ-237: the plain path is unchanged and says so" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Random
    using Test

    @variables V σV I σI
    S = SymbolicMeasurement(V, σV) + SymbolicMeasurement(I, σI)

    # A single run reports one block and makes no claim of
    # stabilisation: `converged` is false because nothing checked it,
    # which is different from "checked and failed".
    Random.seed!(20260903)
    c = monte_carlo(
        S,
        Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.002));
        n = 50_000,
    )
    @test c.blocks == 1
    @test !c.converged
    @test c.n == 50_000
end

@testitem "REQ-237: adaptive is refused for a vector of measurands" begin
    using SymbolicUncertainties
    using Symbolics
    using MonteCarloMeasurements
    using Distributions
    using Test

    @variables V σV I σI
    a = SymbolicMeasurement(V, σV) / SymbolicMeasurement(I, σI)
    b = a * 2.0

    # §7.9's stopping rule is stated for the four scalar results of a
    # single measurand. Extending it to a vector means deciding what
    # "stabilised" means for a correlation matrix, which the standard
    # does not say — so it is refused rather than guessed at.
    err = try
        monte_carlo(
            [a, b],
            Dict(V => Normal(5.0, 0.01), I => Normal(0.1, 0.001));
            adaptive = true,
            n = 1_000,
        )
        nothing
    catch e
        e
    end
    @test err isa ArgumentError
    @test occursin("§7.9", sprint(showerror, err))
end
