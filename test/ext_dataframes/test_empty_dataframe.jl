@testitem "SymbolicUncertaintiesDataFramesExt: empty inputs returns empty DataFrame" begin
    using SymbolicUncertainties
    using Symbolics
    using DataFrames

    @variables a σa
    m = a ± σa
    df =
        uncertainty_budget(m, Symbolics.Num[], Symbolics.Num[]; as = :dataframe)

    @test df isa DataFrames.DataFrame
    @test size(df, 1) == 0
end
