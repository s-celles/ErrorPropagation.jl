@testitem "negative numeric uncertainty is refused (GUM §4.3.1)" begin
    using SymbolicUncertainties

    @test_throws ArgumentError SymbolicMeasurement(1.5, -0.1)

    # The error message must explicitly mention non-negativity and the
    # GUM §4.3.1 section citation so that the user can trace it back
    # to the standard.
    try
        SymbolicMeasurement(1.5, -0.1)
    catch e
        @test e isa ArgumentError
        msg = sprint(showerror, e)
        @test occursin("non-negative", msg)
        @test occursin("§4.3.1", msg)
    end
end
