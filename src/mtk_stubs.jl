# M9 stubs for `propagate_ode` / `uncertainty_ode`. Without
# `ModelingToolkit.jl` loaded, both raise `ArgumentError`
# pointing at the required upstream package; the
# `SymbolicUncertaintiesModelingToolkitExt` extension replaces
# both with `::ODESystem`-specific method overloads when
# MTK is loaded. GUM Supplement 3 (anticipated wording on
# dynamical measurement models).

"""
    propagate_ode(sys, uncertain_params) -> Vector{SymbolicMeasurement}

!!! note "Extension-provided"
    The full implementation lives in
    `SymbolicUncertaintiesModelingToolkitExt` and activates when
    [`ModelingToolkit.jl`](https://github.com/SciML/ModelingToolkit.jl)
    is loaded. Without MTK loaded, this stub raises
    `ArgumentError`.

Propagate parameter uncertainties symbolically through a
`ModelingToolkit.ODESystem`. Returns a
`Vector{SymbolicMeasurement}` of length `length(unknowns(sys))`
— one per state — whose `err` field is the GUM-combined
uncertainty `sqrt(Σⱼ (∂uᵢ/∂pⱼ)² · σⱼ²)` built from the
forward-sensitivity symbolic expressions.

Traces EARS REQ-081 / §10 (GUM Supplement 3, anticipated).
"""
function propagate_ode(args...; kwargs...)
    throw(
        ArgumentError(
            "propagate_ode requires `ModelingToolkit.jl`. " *
            "Add `using ModelingToolkit` to your session — " *
            "the M9 `SymbolicUncertaintiesModelingToolkitExt` will " *
            "then provide the `::ODESystem`-specific method. " *
            "GUM Supplement 3 methodology.",
        ),
    )
end

"""
    uncertainty_ode(sys, uncertain_params) -> ODESystem

!!! note "Extension-provided"
    The full implementation lives in
    `SymbolicUncertaintiesModelingToolkitExt` and activates when
    [`ModelingToolkit.jl`](https://github.com/SciML/ModelingToolkit.jl)
    is loaded. Without MTK loaded, this stub raises
    `ArgumentError`.

Return an augmented `ModelingToolkit.ODESystem` with the
original `N` states plus `K·N` forward-sensitivity states
`∂uᵢ/∂pⱼ(t)` (state-major, parameter-minor ordering) and
their corresponding forward-sensitivity equations. Pass
directly to `ODEProblem` / `solve` from the SciML stack
for numerical integration of both the trajectory and its
sensitivities.

Traces EARS REQ-082 / §10 (GUM Supplement 3, anticipated).
"""
function uncertainty_ode(args...; kwargs...)
    throw(
        ArgumentError(
            "uncertainty_ode requires `ModelingToolkit.jl`. " *
            "Add `using ModelingToolkit` to your session — " *
            "the M9 `SymbolicUncertaintiesModelingToolkitExt` will " *
            "then provide the `::ODESystem`-specific method. " *
            "GUM Supplement 3 methodology.",
        ),
    )
end
