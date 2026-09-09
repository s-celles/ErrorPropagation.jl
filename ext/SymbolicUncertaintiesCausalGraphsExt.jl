module SymbolicUncertaintiesCausalGraphsExt

import SymbolicUncertainties
import CausalGraphs
using Symbolics

"""
    parse_measurement_model(m::CausalGraphs.MeasurementModel)

Parses a qualitative CausalGraphs `MeasurementModel` and generates a setup block 
for `SymbolicUncertainties.jl`.

Returns a string containing Julia code (scaffolding mode).
"""
function SymbolicUncertainties.parse_measurement_model(
    m::CausalGraphs.MeasurementModel,
)
    lines = String[]
    push!(lines, "using SymbolicUncertainties, Symbolics")
    push!(lines, "")

    var_names = String[]
    meas_lines = String[]
    dict_lines = String[]
    push!(dict_lines, "dict = Dict(")

    # We will assume m has inputs and an output, as specified in the roadmap
    for input in CausalGraphs.inputs(m)
        name = string(CausalGraphs.name(input))
        push!(var_names, name)
        push!(var_names, "u_$name")

        # Read metadata if present
        meta = CausalGraphs.metadata(input)
        val = get(meta, :value, 0.0)
        err = get(meta, :uncertainty, 0.1)

        push!(meas_lines, "$(name)_meas = $name ± u_$name")
        push!(dict_lines, "    $name => $val, u_$name => $err,")
    end
    push!(dict_lines, ")")

    if !isempty(var_names)
        push!(lines, "@variables " * join(var_names, " "))
    end

    append!(lines, meas_lines)

    push!(lines, "")
    out_name = string(CausalGraphs.name(CausalGraphs.output(m)))
    push!(lines, "# Define your measurement equation here:")
    push!(
        lines,
        "$out_name = " *
        join(
            [
                string(CausalGraphs.name(n)) * "_meas" for
                n in CausalGraphs.inputs(m)
            ],
            " + ",
        ) *
        " # <--- edit this",
    )

    push!(lines, "")
    push!(lines, "budget = uncertainty_budget($out_name)")

    push!(lines, "")
    push!(lines, "# To evaluate numerically:")
    append!(lines, dict_lines)
    push!(lines, "SymbolicUncertainties.evaluate($out_name, dict)")
    push!(lines, "SymbolicUncertainties.evaluate(budget, dict)")

    return join(lines, "\n")
end

"""
    evaluate_measurement_model(m::CausalGraphs.MeasurementModel)

Full-Auto mode: reads the `[:expr]` metadata from the output node of `m`,
substitutes the input variables with their `val ± err` values, and directly
returns the computed `UncertaintyBudget` evaluated with the numerical metadata.
"""
function SymbolicUncertainties.evaluate_measurement_model(
    m::CausalGraphs.MeasurementModel,
)
    out_node = CausalGraphs.output(m)
    out_meta = CausalGraphs.metadata(out_node)

    if !haskey(out_meta, :expr)
        throw(
            ArgumentError(
                "Full-Auto mode requires an `[:expr]` field in the output node metadata.",
            ),
        )
    end

    # 1. Generate symbolic variables and substitutions
    eval_env = Dict{Symbol,Any}()
    dict = Dict{Num,Real}()

    for input in CausalGraphs.inputs(m)
        sym_name = Symbol(CausalGraphs.name(input))
        err_name = Symbol("u_", sym_name)

        var_val = (@variables $sym_name)[1]
        var_err = (@variables $err_name)[1]

        meta = CausalGraphs.metadata(input)
        val = get(meta, :value, 0.0)
        err = get(meta, :uncertainty, 0.0)

        dict[var_val] = val
        dict[var_err] = err

        # Use ± operator to create the SymbolicMeasurement
        eval_env[sym_name] = var_val ± var_err
    end

    # 2. Add math functions safely
    eval_env[:+] = +
    eval_env[:-] = -
    eval_env[:*] = *
    eval_env[:/] = /
    eval_env[:^] = ^
    eval_env[:sin] = sin
    eval_env[:cos] = cos
    eval_env[:exp] = exp
    eval_env[:log] = log
    eval_env[:sqrt] = sqrt

    # 3. Parse the expression
    raw_expr = out_meta[:expr]
    parsed_expr = raw_expr isa String ? Meta.parse(raw_expr) : raw_expr

    # Evaluate the AST into a SymbolicMeasurement
    function eval_ast(ast)
        if ast isa Symbol
            return eval_env[ast]
        elseif ast isa Expr && ast.head == :call
            func = eval_ast(ast.args[1])
            args = [eval_ast(a) for a in ast.args[2:end]]
            return func(args...)
        elseif ast isa Number
            return ast
        else
            error("Unsupported AST node: $ast")
        end
    end

    sym_meas = eval_ast(parsed_expr)

    # 4. Generate uncertainty budget and evaluate numerically
    budget = SymbolicUncertainties.uncertainty_budget(sym_meas)

    return SymbolicUncertainties.evaluate(budget, dict)
end

end # module
