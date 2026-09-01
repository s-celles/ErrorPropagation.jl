@testitem "REQ-235: a source records the input variable it perturbs" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: sources_of, terms_of
    using Symbolics
    using Test

    @variables V σV I σI

    # `V ± σV` says that V is measured with standard uncertainty σV.
    # The quantity kept σV and lost V, so nothing downstream could
    # name the input a contribution came from — every budget row was
    # labelled `:opaque` — and a Monte Carlo cross-check could not
    # perturb the model's inputs, only its linear form, which would
    # have compared the linearisation against itself.
    m = V ± σV
    src = only(values(sources_of(m)))
    @test isequal(src.variable, V)
    @test src.name === :V
    @test isequal(src.u, σV)

    # A measurand keeps one source per input, each naming its own.
    r = (V ± σV) / (I ± σI)
    named = Dict(s.name => s.variable for s in values(sources_of(r)))
    @test Set(keys(named)) == Set([:V, :I])
    @test isequal(named[:V], V)
    @test isequal(named[:I], I)
end

@testitem "REQ-235: only a bare input variable is recorded" begin
    using SymbolicUncertainties
    using SymbolicUncertainties: sources_of
    using Symbolics
    using Test

    @variables V σV

    # A numeric estimate has no input variable to name.
    numeric = only(values(sources_of(5.0 ± 0.1)))
    @test numeric.variable === nothing
    @test numeric.name === :opaque

    # Neither does a derived expression: `V + 1` is not an input of
    # the measurement model, it is already a function of one. Naming
    # it would invent an input that the model does not have.
    derived = only(values(sources_of((V + 1) ± σV)))
    @test derived.variable === nothing
    @test derived.name === :opaque
end

@testitem "REQ-235: substitution keeps the provenance label" setup = [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties: sources_of
    using Symbolics
    using Test

    @variables V σV

    # Substituting numbers must not erase where a contribution came
    # from: the label is provenance, not a value.
    m = Symbolics.substitute(V ± σV, Dict(V => 5.0, σV => 0.01))
    src = only(values(sources_of(m)))
    @test isequal(src.variable, V)
    @test src.name === :V
    @test isequal(src.u, Symbolics.Num(0.01))
end

@testitem "REQ-235: the budget names its rows" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables V σV I σI

    rows = uncertainty_budget((V ± σV) * (I ± σI))
    @test Set(r.name for r in rows) == Set([:V, :I])

    # And the row still knows the variable itself, not only its name,
    # so a caller can substitute or differentiate with it.
    byname = Dict(r.name => r for r in rows)
    @test isequal(byname[:V].variable, V)
end
