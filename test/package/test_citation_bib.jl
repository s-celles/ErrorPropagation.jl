@testitem "REQ-177: CITATION.bib present and structured" begin
    # M10 smoke test: the repository ships a citation bundle
    # containing at least the package (`@software`) and JCGM 100:2008
    # (`@techreport`). Further normative references — the 2026
    # nonlinearity amendment, GUM-6:2020 — are additions, not
    # replacements, so this checks presence rather than a count. See
    # `specs/012-stable-release/contracts/citation_bib.md`.

    using SymbolicUncertainties
    repo = pkgdir(SymbolicUncertainties)
    path = joinpath(repo, "CITATION.bib")

    @test isfile(path)

    content = read(path, String)
    @test !isempty(content)

    # Package entry
    @test occursin(r"@software\{\s*SymbolicUncertaintiesjl\b"i, content)

    # JCGM 100:2008 entry
    @test occursin(r"@techreport\{\s*JCGM100-?2008\b"i, content)

    # JCGM document number verbatim
    @test occursin("JCGM 100:2008", content)

    # Version field matches live Project.toml
    proj = read(joinpath(repo, "Project.toml"), String)
    m = match(r"^version\s*=\s*\"([^\"]+)\""m, proj)
    @test m !== nothing
    live_version = m.captures[1]
    @test occursin(Regex("version\\s*=\\s*\\{$(live_version)\\}"), content)
end

@testitem "CITATION.cff present and consistent with the licence" begin
    # GitHub's "Cite this repository" button reads CITATION.cff. It is
    # the only mechanism that asks for citation, since no OSI-approved
    # licence can require it — see the BSD-3-Clause decision.
    using SymbolicUncertainties
    repo = pkgdir(SymbolicUncertainties)
    path = joinpath(repo, "CITATION.cff")

    @test isfile(path)
    content = read(path, String)

    @test occursin("cff-version:", content)
    @test occursin("SymbolicUncertainties.jl", content)
    @test occursin("license: BSD-3-Clause", content)

    # The licence named in the citation file must match the one the
    # repository actually ships.
    licence = read(joinpath(repo, "LICENSE.md"), String)
    @test occursin("BSD 3-Clause License", licence)
    # Not `occursin("MIT", ...)`: "LIMITED" contains those letters, as
    # in "INCLUDING, BUT NOT LIMITED TO".
    @test !occursin(r"MIT Licen[cs]e"i, licence)
end
