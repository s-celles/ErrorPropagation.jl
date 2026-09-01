@testitem "unary minus negates a measurement and keeps its source" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx

    # `-m` is the natural way to negate a quantity. Before this it
    # raised a MethodError while `0 - m` and `-1 * m` — the same
    # operation written differently — both worked.
    n = -m
    @test n isa SymbolicMeasurement
    @test isequal(Symbolics.simplify(n.val + x), 0)

    # A sign change cannot change a dispersion (JCGM 100:2008 §4.3.1:
    # `u` is a dispersion, and a dispersion has no origin).
    @test isequal(n.err, σx)

    # The source survives negation, so it still cancels — this is the
    # M11 invariant, and it is what distinguishes `-m` built through
    # the chain rule from one rebuilt out of `.err`.
    @test isequal(Symbolics.simplify((m + n).err), 0)
    @test isequal(Symbolics.simplify((m - n).err - 2σx), 0)

    # Double negation returns the original quantity, uncertainty
    # included.
    @test isequal(Symbolics.simplify((-n).val - x), 0)
    @test isequal((-n).err, σx)

    # Unary plus is the identity.
    p = +m
    @test isequal(p.val, m.val)
    @test isequal(p.err, m.err)
end

@testitem "apply and propagate accept unary minus" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx

    # `apply(f, m)` delegates to `propagate`, which applies `f` to the
    # measurement itself (M11 phase 3). With `-` unoverloaded this
    # raised REQ-021's "no closed-form derivative", blaming the
    # derivative for what was a missing method.
    a = apply(z -> -z, m)
    @test isequal(Symbolics.simplify(a.val + x), 0)
    @test isequal(a.err, σx)

    p = propagate(z -> -z, [m])
    @test isequal(Symbolics.simplify(p.val + x), 0)
    @test isequal(p.err, σx)
end

@testitem "REQ-021: the error names the operation, not the derivative" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx
    m = x ± σx

    # `sign` is deliberately not overloaded: its derivative is zero
    # almost everywhere and undefined at zero, so propagating through
    # it would report a zero uncertainty for a discontinuity.
    err = try
        propagate(z -> sign(z), [m])
        nothing
    catch e
        e
    end
    @test err isa ArgumentError

    msg = sprint(showerror, err)
    # The message must name the operation that failed to dispatch.
    # Saying "cannot compute closed-form derivative" sends the reader
    # to look at differentiability, which is not the problem.
    @test occursin("sign", msg)
    @test occursin("apply", msg)
end
