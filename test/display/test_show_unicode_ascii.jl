@testitem "Base.show uses ± by default and +/- under :unicode => false" begin
    using SymbolicUncertainties
    using Symbolics

    @variables V σV
    m = SymbolicMeasurement(V, σV)

    unicode_out = sprint(show, m)
    @test occursin("±", unicode_out)
    @test !occursin("+/-", unicode_out)

    ascii_out = sprint((io, x) -> show(IOContext(io, :unicode => false), x), m)
    @test occursin("+/-", ascii_out)
    @test !occursin("±", ascii_out)
end
