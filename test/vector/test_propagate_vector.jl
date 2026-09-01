@testitem "propagate_vector: polar to Cartesian (JCGM 102:2011)" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables r σr θ σθ
    r_m = r ± σr
    θ_m = θ ± σθ

    out = propagate_vector((r, θ) -> (r * cos(θ), r * sin(θ)), [r_m, θ_m])

    @test out isa Vector{SymbolicMeasurement}
    @test length(out) == 2

    # x-component reference: ∂(r·cos(θ))/∂r = cos(θ),
    # ∂(r·cos(θ))/∂θ = -r·sin(θ); marginal err is sqrt of sum of
    # (∂f/∂xₖ · σₖ)² so the sign of the second partial doesn't matter
    ref_x = sqrt((cos(θ))^2 * σr^2 + (r * sin(θ))^2 * σθ^2)
    # y-component reference: ∂(r·sin(θ))/∂r = sin(θ),
    # ∂(r·sin(θ))/∂θ = r·cos(θ)
    ref_y = sqrt((sin(θ))^2 * σr^2 + (r * cos(θ))^2 * σθ^2)

    dict = Dict(r => 2.0, σr => 0.01, θ => 0.5, σθ => 0.005)
    @test isapprox(
        _as_float(out[1].err, dict),
        _as_float(ref_x, dict);
        atol = 1e-12,
    )
    @test isapprox(
        _as_float(out[2].err, dict),
        _as_float(ref_y, dict);
        atol = 1e-12,
    )
end
