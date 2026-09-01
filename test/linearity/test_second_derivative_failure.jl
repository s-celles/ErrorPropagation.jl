@testitem "check_linearity: unresolved differential raises ArgumentError" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    # A `@register_symbolic` function has no derivative rule in
    # Symbolics — the first (and hence second) derivative is an
    # unresolved `Differential` wrapper.
    Symbolics.@register_symbolic black_box(x)

    @variables x σx
    @test_throws ArgumentError Logging.with_logger(Logging.NullLogger()) do
        check_linearity(a -> black_box(a), [x ± σx])
    end
end
