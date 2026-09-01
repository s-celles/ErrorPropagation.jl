@testitem "UB-007: a wrong simplified zero must not delete an uncertainty source" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    # `Symbolics.simplify` returns a numerically wrong result — zero
    # among them — for expressions whose coefficients are small in
    # absolute terms (`upstream-bugs.md` UB-007). `_chain` used to
    # honour that zero and delete the source, silently understating
    # `u_c`. It must now re-check before deleting.
    #
    # The shape below is the one that exposed it: a type-K
    # thermocouple read against a measured cold junction, inverted for
    # the hot-junction temperature. The `sqrt` step is where the
    # cold-junction source disappeared.
    @variables E σE Tcj σTcj

    a1 = 39.45e-6      # V/K, first-order Seebeck coefficient
    a2 = 2.36e-8       # V/K², second-order term

    # Each input is bound once: repeating `±` would declare three
    # independent cold junctions, which is a different model.
    emf = E ± σE
    cj = Tcj ± σTcj

    total = emf + (a1 * cj + a2 * cj * cj)
    T = (-a1 + sqrt(a1^2 + 4 * a2 * total)) / (2 * a2)

    names = Set(s.name for s in values(SymbolicUncertainties.sources_of(T)))
    @test :E in names
    @test :Tcj in names          # the regression: this was missing

    # The cold junction must also carry a non-zero share of the
    # variance — surviving as a zero-weighted term would be the same
    # defect wearing a different mask.
    rows = uncertainty_budget(T)
    @test Set(r.name for r in rows) == Set([:E, :Tcj])
    vals = Dict(E => 4.096e-3, σE => 2.0e-6, Tcj => 22.5, σTcj => 0.15)
    cj = only(r for r in rows if r.name === :Tcj)
    @test _as_float(cj.relative, vals) > 0.0

    # A genuine cancellation must still be removed, or the guard would
    # have been bought by making every budget wrong in the other
    # direction.
    x = 8.4 ± 0.7
    @test isempty(SymbolicUncertainties.terms_of(x - x))
    @test isequal(Symbolics.value((x - x).err), 0)
end
