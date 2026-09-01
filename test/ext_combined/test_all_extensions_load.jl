@testitem "All extensions loaded together" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify
    using Measurements
    using DynamicQuantities
    using DataFrames
    using Logging
    using SymbolicUncertainties: ±

    # US1 Latexify
    @variables x σx
    m = x ± σx
    s = latex(m)
    @test s isa AbstractString
    @test occursin("\\pm", s)

    # US2 Measurements
    mm = 5.0 ± 0.1
    meas = Measurements.Measurement(mm)
    @test meas isa Measurements.Measurement

    # US3 DynamicQuantities — dimensional checking, opt-in and
    # non-throwing (M12 replaced the Unitful construction-time error).
    @variables Vd Id
    rep = check_units(
        Vd / Id,
        Dict(Vd => DynamicQuantities.u"V", Id => DynamicQuantities.u"A"),
    )
    @test rep isa UnitReport
    @test SymbolicUncertainties.is_consistent(rep)

    # US4 DataFrames
    @variables V σV R1 σR1 R2 σR2
    Vout = Logging.with_logger(Logging.NullLogger()) do
        propagate((v, r1, r2) -> v * r2 / (r1 + r2), [V ± σV, R1 ± σR1, R2 ± σR2])
    end
    df = uncertainty_budget(Vout, [V, R1, R2], [σV, σR1, σR2]; as = :dataframe)
    @test df isa DataFrames.DataFrame
end
