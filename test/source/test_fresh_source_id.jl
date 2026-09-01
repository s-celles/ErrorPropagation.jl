@testitem "REQ-200: ± mints a unique independent source" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: SourceId, sources_of, terms_of
    using Symbolics
    using Test

    @variables x σx

    m1 = x ± σx
    m2 = x ± σx

    # Each ± call mints exactly one source...
    @test length(terms_of(m1)) == 1
    @test length(sources_of(m1)) == 1

    # ...with sensitivity 1 (∂val/∂source = 1 for a raw measurement).
    @test isequal(Symbolics.value(first(values(terms_of(m1)))), 1)

    # ...and the identifier is fresh: two syntactically identical
    # constructions are two independent measurements, which is the
    # whole point — the same σ symbol may describe two different
    # resistors of equal tolerance.
    id1 = only(keys(terms_of(m1)))
    id2 = only(keys(terms_of(m2)))
    @test id1 isa SourceId
    @test id1 != id2

    # The source carries the standard uncertainty it was built from.
    @test isequal(sources_of(m1)[id1].u, σx)
end
