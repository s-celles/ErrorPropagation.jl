@testitem "piecewise models are refused with a reason, not a MethodError" begin
    using SymbolicUncertainties
    using Symbolics
    using Test

    @variables x σx y σy
    m = x ± σx
    n = y ± σy

    # The GUM linearises around the estimate (§5.1.2). At a switch
    # point a piecewise model has no derivative, so a first-order
    # combined uncertainty is not defined there — JCGM 101:2008 Monte
    # Carlo is the right tool. Refusing is correct; refusing with a
    # bare MethodError is not, because it reads as an oversight.
    for f in (
        () -> max(m, n),
        () -> min(m, n),
        () -> max(m, 0.0),
        () -> min(0.0, m),
        () -> clamp(m, 0.0, 10.0),
    )
        err = try
            f()
            nothing
        catch e
            e
        end
        @test err isa ArgumentError
        msg = sprint(showerror, err)
        @test occursin("JCGM 101", msg)
        @test occursin("derivative", msg)
    end
end
