@testitem "check_linearity: empty input returns empty dict without calling f" begin
    using SymbolicUncertainties
    using Symbolics

    called = Ref(false)
    f = (_...) -> begin
        called[] = true
        error("f should not be called")
    end

    η = check_linearity(f, SymbolicMeasurement[])
    @test η isa Dict{Symbolics.Num,Symbolics.Num}
    @test isempty(η)
    @test called[] == false
end
