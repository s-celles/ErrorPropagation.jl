@testitem "M12 exit criterion: u_c does not blow up with many sources" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The failure mode of a purely symbolic GUM library is an
    # expression no CAS can simplify and no user can read. The guard
    # is structural: `u_c` is built as sqrt(Σ cᵢ²uᵢ²) and the square
    # of the sum is never expanded, so growth is quadratic in the
    # number of sources (the sensitivity coefficient of a product
    # carries n−1 factors) rather than exponential.
    #
    # No test measured any output size before M13, which is how a
    # 285 000-character `expanded_uncertainty` shipped and was found
    # by rendering the documentation instead. These bounds are loose
    # by design: they catch a blow-up, not a refactor.
    function product_of(n)
        vars = [Symbolics.variable(Symbol("x", i)) for i in 1:n]
        sigmas = [Symbolics.variable(Symbol("s", i)) for i in 1:n]
        m = vars[1] ± sigmas[1]
        for i in 2:n
            m = m * (vars[i] ± sigmas[i])
        end
        return m
    end

    sizes = [length(string(product_of(n).err)) for n in (3, 6, 9, 12)]

    # Monotone and bounded: 12 independent sources must stay in the
    # thousands of characters, not the hundreds of thousands.
    @test issorted(sizes)
    @test last(sizes) < 20_000

    # Second differences stay bounded — quadratic growth, not
    # exponential. An exponential curve fails this by orders of
    # magnitude long before the absolute bound above trips.
    @test sizes[4] < 4 * sizes[2]

    # The budget and the C evaluator both build at 12 sources.
    m12 = product_of(12)
    @test length(uncertainty_budget(m12)) == 12
    @test build_evaluator(
        m12,
        [Symbolics.variable(Symbol("x", i)) for i in 1:12];
        target = CTarget(),
    ) isa String
end

@testitem "M13 regression: expanded_uncertainty stays readable with symbolic ν" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # `k` carries (1/ν)³ from the Cornish-Fisher expansion, so
    # simplifying the product k·u_c against a Welch-Satterthwaite
    # fraction inflated a three-source voltage divider to 285 816
    # characters — `abs(R2/(R1+R2))^24` among them. The product is
    # left factored, which is also the readable form.
    @variables Vin σVin R1 σR1 R2 σR2 ν

    v = SymbolicMeasurement(Vin, σVin, ν)
    r1 = SymbolicMeasurement(R1, σR1, ν)
    r2 = SymbolicMeasurement(R2, σR2, ν)
    vout = v * r2 / (r1 + r2)

    U = Logging.with_logger(Logging.NullLogger()) do
        expanded_uncertainty(vout; coverage_probability = 0.95)
    end

    @test length(string(U.U)) < 5_000
end
