"""
    parse_measurement_model(m) -> String

!!! note "Extension-provided"
    The full implementation lives in
    `SymbolicUncertaintiesCausalGraphsExt` and activates when
    [`CausalGraphs.jl`] is loaded. Without it loaded, this stub raises
    `ArgumentError`.

Parses a qualitative CausalGraphs `MeasurementModel` and generates a setup block 
for `SymbolicUncertainties.jl`.

Returns a string containing Julia code (scaffolding mode) that:
- defines all variables using `@variables`
- creates `SymbolicMeasurement` objects for all inputs with metadata
- prepares an `uncertainty_budget` call.
"""
function parse_measurement_model(args...; kwargs...)
    throw(
        ArgumentError(
            "parse_measurement_model requires `CausalGraphs.jl`. " *
            "Add `using CausalGraphs` to your session."
        ),
    )
end

"""
    evaluate_measurement_model(m) -> UncertaintyBudget

!!! note "Extension-provided"
    The full implementation lives in
    `SymbolicUncertaintiesCausalGraphsExt` and activates when
    [`CausalGraphs.jl`] is loaded. Without it loaded, this stub raises
    `ArgumentError`.

Evaluates a `CausalGraphs.MeasurementModel` in Full-Auto mode.
Requires the output node to contain an `[:expr]` metadata field with a 
Julia expression of the measurement equation.
Returns the evaluated `UncertaintyBudget`.
"""
function evaluate_measurement_model(args...; kwargs...)
    throw(
        ArgumentError(
            "evaluate_measurement_model requires `CausalGraphs.jl`. " *
            "Add `using CausalGraphs` to your session."
        ),
    )
end
