@testitem "JuliaFormatter compliance" begin
    using JuliaFormatter

    repo_root = normpath(joinpath(@__DIR__, "..", ".."))
    clean = JuliaFormatter.format(repo_root; overwrite = false, verbose = false)
    @test clean
end
