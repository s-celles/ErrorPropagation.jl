@testitem "Gallery: pressure transducer, two-point calibration" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test
    using Logging

    # A transducer is calibrated at two points — zero and span — and
    # every later reading is converted through that straight line:
    #
    #   p(r) = (r − r₀) · P / (r₁ − r₀)
    #
    # where r₀ and r₁ are the readings at zero and at the reference
    # pressure P.
    #
    # The tutorial's point: the uncertainty budget is not a property
    # of the instrument. It changes along the range, because the zero
    # and span calibration points do not contribute equally
    # everywhere.
    @variables r σr r0 σr0 r1 σr1 P σP

    reading = SymbolicMeasurement(r, σr)
    zero = SymbolicMeasurement(r0, σr0)
    span = SymbolicMeasurement(r1, σr1)
    reference = SymbolicMeasurement(P, σP)

    p = Logging.with_logger(Logging.NullLogger()) do
        (reading - zero) * reference / (span - zero)
    end

    # A 4–20 mA transmitter over 0–10 bar. Readings carry 4 µA of
    # noise; the reference standard is good to 0.002 bar.
    base = Dict(
        σr => 4.0e-6,
        r0 => 4.0e-3,
        σr0 => 4.0e-6,
        r1 => 20.0e-3,
        σr1 => 4.0e-6,
        P => 10.0,
        σP => 0.002,
    )

    low = merge(base, Dict(r => 5.0e-3))     # ~0.6 bar
    mid = merge(base, Dict(r => 12.0e-3))    # 5 bar
    high = merge(base, Dict(r => 19.0e-3))   # ~9.4 bar

    @test isapprox(_as_float(p.val, mid), 5.0; rtol = 1e-12)
    @test isapprox(_as_float(p.val, high), 9.375; rtol = 1e-12)

    contribs(vals) = Dict(
        r.name => _as_float(r.contribution, vals) for
        r in uncertainty_budget(p)
    )

    c_low, c_high = contribs(low), contribs(high)

    # Near the bottom of the range the zero point dominates the two
    # calibration constants; near the top the span reading does. Same
    # instrument, same formula, different budget.
    @test c_low[:r0] > c_low[:r1]
    @test c_high[:r1] > c_high[:r0]

    # The reference standard scales with the reading, so it is
    # negligible at the bottom and dominant at the top — a 0.02 %
    # relative contribution either way, but 0.0002 bar against
    # 0.0019 bar in absolute terms, which is what a certificate
    # states.
    @test c_high[:P] > 5 * c_low[:P]

    # And the relative uncertainty is worst at the bottom of the
    # range: dividing a fixed reading noise by a small span is the
    # reason transducers are specified over a stated turndown.
    rel(vals) = _as_float(p.err, vals) / _as_float(p.val, vals)
    @test rel(low) > 5 * rel(high)
end
