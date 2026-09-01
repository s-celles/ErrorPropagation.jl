@testitem "JCGM Annex H.2: simultaneous resistance, reactance, impedance" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # JCGM 100:2008 §H.2. A component carrying alternating current is
    # characterised by three output quantities derived from the same
    # three inputs — voltage amplitude V, current amplitude I and
    # phase φ:
    #
    #   R = (V/I)·cos φ      X = (V/I)·sin φ      Z = V/I
    #
    # This is the example that forces correlation into the type. The
    # three outputs are correlated because they descend from common
    # measurements, and R and X are correlated even when V, I and φ
    # are taken as independent.
    @variables V σV I σI φ σφ

    v = V ± σV
    i = I ± σI
    p = φ ± σφ

    R = (v / i) * cos(p)
    X = (v / i) * sin(p)
    Z = v / i

    # Input estimates and standard uncertainties of §H.2 (means of
    # five independent observation series).
    vals = Dict(
        V => 4.999,
        σV => 0.0032,
        I => 19.661e-3,
        σI => 0.0095e-3,
        φ => 1.04446,
        σφ => 0.00075,
    )

    @test isapprox(_as_float(R.val, vals), 127.732; rtol = 1e-4)
    @test isapprox(_as_float(X.val, vals), 219.847; rtol = 1e-4)
    @test isapprox(_as_float(Z.val, vals), 254.260; rtol = 1e-4)

    # An exact algebraic invariant of the model, independent of any
    # published figure: R² + X² = Z². It checks the propagation path
    # itself rather than a transcribed number.
    @test isapprox(
        _as_float(R.val, vals)^2 + _as_float(X.val, vals)^2,
        _as_float(Z.val, vals)^2;
        rtol = 1e-9,
    )

    # Inputs taken as independent. §H.2 reports its headline figures
    # for the CORRELATED case (asserted in the next testitem); these
    # are what the same model gives without the covariances.
    @test isapprox(_as_float(R.err, vals), 0.1941; atol = 5e-4)
    @test isapprox(_as_float(X.err, vals), 0.2007; atol = 5e-4)
    @test isapprox(_as_float(Z.err, vals), 0.2039; atol = 5e-4)
end

@testitem "JCGM Annex H.2: declared correlations reproduce the reference" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # §H.2.3: the three inputs are correlated, with r(V,I) = −0.36,
    # r(V,φ) = 0.86 and r(I,φ) = −0.65 estimated from the observation
    # series. This is the case the example exists for, and the one
    # that requires chaining three declarations over three quantities.
    @variables V σV I σI φ σφ
    v0 = V ± σV
    i0 = I ± σI
    p0 = φ ± σφ

    v1, i1 = declare_correlated(v0, i0, -0.36)
    i2, p1 = declare_correlated(i1, p0, -0.65)
    v2, p2 = declare_correlated(v1, p1, 0.86)

    R = (v2 / i2) * cos(p2)
    X = (v2 / i2) * sin(p2)
    Z = v2 / i2

    vals = Dict(
        V => 4.999,
        σV => 0.0032,
        I => 19.661e-3,
        σI => 0.0095e-3,
        φ => 1.04446,
        σφ => 0.00075,
    )

    # The reference figures of §H.2.3. Tolerance is 2 % relative:
    # published uncertainties carry two significant figures, and the
    # input estimates are themselves rounded, so demanding more than
    # that would be testing the rounding rather than the propagation.
    @test isapprox(_as_float(R.err, vals), 0.071; rtol = 2e-2)
    @test isapprox(_as_float(X.err, vals), 0.295; rtol = 2e-2)
    @test isapprox(_as_float(Z.err, vals), 0.236; rtol = 2e-2)

    # All three covariances must survive the intermediate steps: the
    # division `v/i` drops φ before `cos(φ)` reintroduces it, and
    # pruning them there silently returned u(R) = 0.203.
    @test length(SymbolicUncertainties.cov_of(R)) == 3
end

@testitem "JCGM Annex H.2: shared sources correlate the outputs" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # The property the example exists to demonstrate, and the one M11
    # provides without a covariance matrix: R, X and Z descend from
    # the same V, I and φ, so combining them must account for it.
    @variables V σV I σI φ σφ
    v = V ± σV
    i = I ± σI
    p = φ ± σφ

    R = (v / i) * cos(p)
    X = (v / i) * sin(p)
    Z = v / i

    vals = Dict(
        V => 4.999,
        σV => 0.0032,
        I => 19.661e-3,
        σI => 0.0095e-3,
        φ => 1.04446,
        σφ => 0.00075,
    )

    # Z is exactly V/I, so Z·cos(φ) is exactly R: every source cancels
    # or reproduces itself. Treating Z and φ as independent would
    # inflate this, which is precisely the pre-M11 defect.
    reconstructed = Z * cos(p)
    @test isapprox(
        _as_float(reconstructed.err, vals),
        _as_float(R.err, vals);
        rtol = 1e-9,
    )

    # R/Z is cos φ: V and I cancel entirely, leaving only the phase
    # source. |−sin φ|·u(φ) = 0.00065.
    ratio = R / Z
    @test isapprox(
        _as_float(ratio.err, vals),
        abs(sin(1.04446)) * 0.00075;
        rtol = 1e-6,
    )
end
