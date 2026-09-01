@testitem "M10 FR-009: precompile workload structural sanity" begin
    # Structural smoke check that the PrecompileTools workload
    # block compiles and that the four canonical call paths
    # remain callable. No wall-clock gate — research R4 keeps
    # the < 1 s first-call target documented-only in
    # `docs/src/limitations.md`.

    using SymbolicUncertainties
    using SymbolicUncertainties: ±
    using Symbolics

    # Workload path 1 — arithmetic (M1)
    @variables V I σV σI
    m1 = (V ± σV) / (I ± σI)
    @test m1 isa SymbolicMeasurement

    # Workload path 2 — math functions (M2)
    @variables a b σa σb
    m2 = sqrt(a ± σa)
    @test m2 isa SymbolicMeasurement
    m3 = exp(a ± σa)
    @test m3 isa SymbolicMeasurement

    # Workload path 3 — multi-variable propagate (M2)
    m4 = propagate((x, y) -> x * y, [a ± σa, b ± σb])
    @test m4 isa SymbolicMeasurement

    # Workload path 4 — uncertainty budget (M3)
    rows = uncertainty_budget(m1, [V, I], [σV, σI])
    @test length(rows) == 2
    @test all(r -> hasproperty(r, :variable), rows)

    # Structural check: PrecompileTools is a direct dependency
    # of the package. Probing via the package's manifest rather
    # than importing PrecompileTools here (it is not a test dep).
    pkg_proj = joinpath(pkgdir(SymbolicUncertainties), "Project.toml")
    @test occursin(
        "PrecompileTools = \"aea7be01-6a6a-4083-8856-8a6e6704d82a\"",
        read(pkg_proj, String),
    )
end
