@testitem "budget_allocation: product-rule stationarity (numeric)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables a σa b σb
    # m = a·b → ca = b, cb = a. Stationarity: b²·σa = a²·σb.
    m = propagate((x, y) -> x * y, [a ± σa, b ± σb])

    B = 1.0
    alloc = budget_allocation(m, [a, b], [σa, σb], B)

    dict = Dict(a => 2.0, b => 3.0)
    σa_val = _as_float(alloc[σa], dict)
    σb_val = _as_float(alloc[σb], dict)

    # Stationarity: b²·σa = a²·σb  ⇒  9·σa = 4·σb.
    @test isapprox(9 * σa_val, 4 * σb_val; atol = 1e-10)
    # Budget constraint: σa + σb = B.
    @test isapprox(σa_val + σb_val, B; atol = 1e-10)
end
