@testitem "atan(y, x): phase from quadrature components" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables Q σQ I σI

    # Phase is measured as atan(Q, I), not atan(Q/I): the two-argument
    # form is what a lock-in amplifier or a vector analyser computes,
    # and it is the only one that keeps the quadrant. JCGM 100:2008
    # §H.2 takes φ as an input; deriving it from I/Q needs this.
    φ = Logging.with_logger(Logging.NullLogger()) do
        atan(Q ± σQ, I ± σI)
    end
    @test φ isa SymbolicMeasurement
    @test isequal(Symbolics.simplify(φ.val - atan(Q, I)), 0)

    # ∂atan(y,x)/∂y = x/(x²+y²), ∂/∂x = -y/(x²+y²), so
    # u_c² = (x²u_y² + y²u_x²)/(x²+y²)².
    vals = Dict(Q => 3.0, σQ => 0.01, I => 4.0, σI => 0.02)
    d = 3.0^2 + 4.0^2
    expected = sqrt((4.0 * 0.01)^2 + (3.0 * 0.02)^2) / d
    @test isapprox(_as_float(φ.err, vals), expected; rtol = 1e-12)

    # The estimate keeps the quadrant, which is the whole point: the
    # one-argument form cannot tell (-3, -4) from (3, 4).
    q2 = Logging.with_logger(Logging.NullLogger()) do
        atan((-3.0) ± 0.01, (-4.0) ± 0.02)
    end
    @test _as_float(q2.val, Dict()) < 0
    @test isapprox(_as_float(q2.val, Dict()), atan(-3.0, -4.0); rtol = 1e-12)

    # Mixed mode: one component known exactly.
    mixed = Logging.with_logger(Logging.NullLogger()) do
        atan(Q ± σQ, 4.0)
    end
    @test isapprox(
        _as_float(mixed.err, Dict(Q => 3.0, σQ => 0.01)),
        4.0 * 0.01 / d;
        rtol = 1e-12,
    )
end

@testitem "atan(y, x) warns when the origin cannot be excluded" begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    @variables Q σQ I σI

    # At the origin the phase is undefined and its sensitivities blow
    # up. Same posture as the REQ-140 division guard: warn, do not
    # refuse, and let substitution decide.
    @test_logs (:warn,) match_mode = :any atan(Q ± σQ, I ± σI)

    # Concrete non-zero components are provably safe — no warning.
    @test_logs min_level = Logging.Warn atan(3.0 ± 0.01, 4.0 ± 0.02)
end
