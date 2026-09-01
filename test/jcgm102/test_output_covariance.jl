@testitem "JCGM 102: covariance between two measurands" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # JCGM 102:2011 §6 asks for the covariance MATRIX of a
    # vector-valued measurand, not just its marginal uncertainties.
    # Since M11 that is derivable: two quantities sharing sources have
    # a covariance fixed by their linear forms.
    @variables a σa b σb
    x = a ± σa
    y = b ± σb

    # A quantity with itself: covariance is the variance.
    vals = Dict(a => 2.0, σa => 0.1, b => 3.0, σb => 0.2)
    @test isapprox(
        _as_float(covariance(x, x), vals),
        _as_float(x.err, vals)^2;
        rtol = 1e-9,
    )
    @test isapprox(_as_float(correlation(x, x), vals), 1.0; rtol = 1e-9)

    # Independent quantities: zero covariance, and no correlation.
    @test isapprox(_as_float(covariance(x, y), vals), 0.0; atol = 1e-15)
    @test isapprox(_as_float(correlation(x, y), vals), 0.0; atol = 1e-15)

    # Sharing a source induces covariance without anything declared.
    s = x + y
    d = x - y
    # cov(x+y, x−y) = u(x)² − u(y)² = 0.01 − 0.04 = −0.03
    @test isapprox(_as_float(covariance(s, d), vals), -0.03; rtol = 1e-9)

    # Perfect correlation when one is a multiple of the other.
    @test isapprox(_as_float(correlation(x, 2 * x), vals), 1.0; rtol = 1e-9)
    @test isapprox(_as_float(correlation(x, -3 * x), vals), -1.0; rtol = 1e-9)
end

@testitem "JCGM 102: Annex H.2 output correlations" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # §H.2 stresses that its three outputs are mutually correlated
    # even when the inputs are taken as independent, because they
    # descend from the same measurements. That correlation is what a
    # downstream user needs in order to combine them further.
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

    # Z and R share V and I entirely, so they are strongly correlated.
    r_RZ = _as_float(correlation(R, Z), vals)
    r_XZ = _as_float(correlation(X, Z), vals)
    @test -1.0 <= r_RZ <= 1.0
    @test -1.0 <= r_XZ <= 1.0
    @test r_RZ > 0.5

    # An exact identity: Z·cos(φ) is R, so cov(R, Z) must equal
    # cov(Z·cos(φ), Z) computed independently.
    @test isapprox(
        _as_float(covariance(R, Z), vals),
        _as_float(covariance(Z * cos(p), Z), vals);
        rtol = 1e-9,
    )
end
