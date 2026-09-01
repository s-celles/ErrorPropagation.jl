@testitem "SymbolicUncertaintiesModelingToolkitExt: ode-integration docs page exists" begin
    page = joinpath(@__DIR__, "..", "..", "docs", "src", "ode-integration.md")
    @test isfile(page)

    content = read(page, String)
    @test occursin("propagate_ode", content)
    @test occursin("uncertainty_ode", content)
    @test occursin("Vin", content)  # RC-charge fingerprint
end
