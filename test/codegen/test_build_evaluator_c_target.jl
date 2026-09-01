@testitem "build_evaluator: CTarget emits C source string" begin
    using SymbolicUncertainties
    using Symbolics
    using Logging

    @variables V I σV σI
    R_m = Logging.with_logger(Logging.NullLogger()) do
        (V ± σV) / (I ± σI)
    end

    source = build_evaluator(
        R_m,
        [V, I, σV, σI];
        target = CTarget(),
        fname = :ohms_law_evaluator,
    )

    @test source isa String
    @test occursin("#include <math.h>", source)
    @test occursin("void ohms_law_evaluator(", source)
    # The combined uncertainty reaches the emitted code as
    # `hypot`, which is the overflow-safe spelling of a square root
    # of a sum of squares; a correlated model keeps `sqrt`, and
    # Symbolics may write a power as `pow(x, 0.5)`. Any of the three
    # satisfies the GUM arithmetic shape.
    @test occursin("hypot", source) ||
          occursin("sqrt", source) ||
          occursin("pow(", source)
end

@testitem "build_evaluator: CTarget default fname" begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx
    source = build_evaluator(m, [x, σx]; target = CTarget())

    @test source isa String
    @test occursin("void evaluate_measurement(", source)
end
