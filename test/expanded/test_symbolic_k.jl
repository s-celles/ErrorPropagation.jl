@testitem "expanded_uncertainty: symbolic k (numeric)" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx k
    m = x ± σx

    U = expanded_uncertainty(m, k)
    dict = Dict(x => 1.0, σx => 0.1, k => 2.5)
    @test isapprox(_as_float(U.U, dict), 0.25; atol = 1e-12)
end
