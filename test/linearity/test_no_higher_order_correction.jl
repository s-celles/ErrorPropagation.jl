@testitem "check_linearity: no correction applied to propagate output (REQ-182)" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables x σx
    f = a -> exp(a)

    # Propagate once, capture the result.
    y1 = propagate(f, [x ± σx])

    # Run check_linearity with and without values — must not
    # modify any subsequent propagate output.
    _ = Logging.with_logger(Logging.NullLogger()) do
        check_linearity(f, [x ± σx])
    end
    _ = Logging.with_logger(Logging.NullLogger()) do
        check_linearity(f, [x ± σx]; values = Dict(x => 1.0, σx => 0.5))
    end

    # Propagate again; result must be symbolically identical.
    y2 = propagate(f, [x ± σx])

    @test Symbolics.isequal(y1.val, y2.val)
    @test Symbolics.isequal(y1.err, y2.err)
end
