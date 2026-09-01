@testitem "JCGM Annex H.4: activity of a radon sample" setup = [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: declare_correlated
    using Symbolics
    using Test

    # JCGM 100:2008 §H.4. The massic activity of an unknown water
    # sample is measured by liquid-scintillation counting against a
    # standard, through
    #
    #   Ax = AS · (mS/mx) · (Rx/RS)
    #
    # where Rx and RS are the background- and decay-corrected counting
    # rates of the sample and of the standard, equations (H.21a) and
    # (H.21b). Both are formed from the SAME six measurement cycles
    # and from the same background counts, so they are correlated:
    # r(Rx, RS) = 0.646, §H.4.2.
    #
    # The Annex analyses the data twice. Approach 1 works from the two
    # arithmetic means and must carry the correlation explicitly
    # (equation (H.22b)); approach 2 averages the per-cycle ratio and
    # avoids it (equation (H.23b)). Both must land on the same answer,
    # and that agreement is the point of the example — it is also a
    # test of the type: one path goes through `declare_correlated`,
    # the other does not, and they must not disagree.
    @variables AS σAS mS σmS mx σmx

    # §H.4.3 input estimates: standard massic activity, standard
    # solution mass, sample aliquot mass.
    inputs = Dict(
        AS => 0.1368,
        σAS => 0.0018,
        mS => 5.0192,
        σmS => 0.0050,
        mx => 5.0571,
        σmx => 0.0010,
    )

    # ---------------- Approach 1, §H.4.3.1 -------------------------
    #
    # Rx and RS are the means of the six cycles; s(Rx) and s(RS) are
    # the experimental standard deviations of those means, Table H.8.
    @variables Rx σRx RS σRS

    rx, rs = declare_correlated(Rx ± σRx, RS ± σRS, 0.646)
    Ax1 = (AS ± σAS) * ((mS ± σmS) / (mx ± σmx)) * (rx / rs)

    vals1 = merge(
        inputs,
        Dict(Rx => 652.60, σRx => 6.42, RS => 206.09, σRS => 3.79),
    )

    @test isapprox(_as_float(Ax1.val, vals1), 0.4300; rtol = 1e-3)
    @test isapprox(_as_float(Ax1.err, vals1), 0.0083; rtol = 2e-2)

    # The relative combined standard uncertainty the Annex reports,
    # 1.93 × 10⁻², is the more precise published figure.
    rel1 = _as_float(Ax1.err, vals1) / _as_float(Ax1.val, vals1)
    @test isapprox(rel1, 1.93e-2; rtol = 1e-2)

    # Equation (H.22b) written out, as a check on the propagation
    # rather than on a transcribed number. The last three terms are
    # the relative variance of Rx/RS, and the cross term is NEGATIVE
    # for a ratio even though r > 0: a positive correlation between
    # numerator and denominator partially cancels.
    expected_rel = sqrt(
        (0.0018 / 0.1368)^2 +
        (0.0050 / 5.0192)^2 +
        (0.0010 / 5.0571)^2 +
        (6.42 / 652.60)^2 +
        (3.79 / 206.09)^2 - 2 * 0.646 * (6.42 / 652.60) * (3.79 / 206.09),
    )
    @test isapprox(rel1, expected_rel; rtol = 1e-9)

    # Ignoring the correlation would OVERSTATE the uncertainty by
    # about a third — §H.4's reason for existing, and the failure mode
    # a user cannot see without the source structure.
    Ax_indep =
        (AS ± σAS) * ((mS ± σmS) / (mx ± σmx)) * ((Rx ± σRx) / (RS ± σRS))
    @test _as_float(Ax1.err, vals1) < _as_float(Ax_indep.err, vals1)

    # ---------------- Approach 2, §H.4.3.2 -------------------------
    #
    # The per-cycle ratio R = Rx/RS is averaged first, so its
    # uncertainty is one experimental standard deviation of a mean and
    # no correlation has to be declared: equation (H.23b).
    @variables R σR

    Ax2 = (AS ± σAS) * ((mS ± σmS) / (mx ± σmx)) * (R ± σR)
    vals2 = merge(inputs, Dict(R => 3.170, σR => 0.046))

    @test isapprox(_as_float(Ax2.val, vals2), 0.4304; rtol = 1e-3)
    @test isapprox(_as_float(Ax2.err, vals2), 0.0084; rtol = 2e-2)

    rel2 = _as_float(Ax2.err, vals2) / _as_float(Ax2.val, vals2)
    @test isapprox(rel2, 1.95e-2; rtol = 1e-2)

    # The two approaches agree to well within their own uncertainty —
    # the property §H.4 is built to demonstrate.
    a1 = _as_float(Ax1.val, vals1)
    a2 = _as_float(Ax2.val, vals2)
    @test abs(a1 - a2) < 0.1 * _as_float(Ax1.err, vals1)

    # The budget derives its five rows from the source structure
    # alone, with no `variables` / `sigmas` list (REQ-206), and ranks
    # the standard's counting rate first: u(RS)/RS = 1.84 × 10⁻² is
    # the largest relative input uncertainty in Table H.8.
    rows1 = uncertainty_budget(Ax1)
    @test length(rows1) == 5
    contributions = [_as_float(r.contribution, vals1) for r in rows1]
    sigmas = [_as_float(r.sigma, vals1) for r in rows1]
    @test sigmas[argmax(contributions)] == 3.79
end
