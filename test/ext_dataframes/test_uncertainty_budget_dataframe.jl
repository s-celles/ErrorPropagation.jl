@testitem "SymbolicUncertaintiesDataFramesExt: uncertainty_budget returns DataFrame" begin
    using SymbolicUncertainties
    using Symbolics
    using DataFrames
    using Logging

    @variables V σV R1 σR1 R2 σR2
    Vout = Logging.with_logger(Logging.NullLogger()) do
        propagate((v, r1, r2) -> v * r2 / (r1 + r2), [V ± σV, R1 ± σR1, R2 ± σR2])
    end

    df = uncertainty_budget(Vout, [V, R1, R2], [σV, σR1, σR2]; as = :dataframe)

    @test df isa DataFrames.DataFrame
    @test size(df, 1) == 3
    @test Set(names(df)) ==
          Set(["variable", "sigma", "sensitivity", "contribution", "relative"])
end
