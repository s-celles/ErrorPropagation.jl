module SymbolicUncertaintiesModelingToolkitExt

# M9 — `propagate_ode` and `uncertainty_ode` implementations.
# Activates when `ModelingToolkit.jl` is loaded. Forward-
# sensitivity construction is purely symbolic (no numerical
# integration) — `Symbolics.derivative` provides the partial
# derivatives, `ModelingToolkit.System` provides the
# augmented system. GUM Supplement 3 (anticipated)
# methodology.
#
# MTK 11 note: the `System` type is canonical; `ODESystem`
# is a deprecated alias that returns `System`. Our methods
# dispatch on `ModelingToolkit.System` so both call sites
# work (users on the deprecated `ODESystem` name will see a
# deprecation warning from MTK itself, not from us).
#
# See `specs/011-mtk-ode-integration/` for the full design
# dossier (research.md R1–R8, data-model.md entities 1–5,
# contracts/propagate_ode.md, contracts/uncertainty_ode.md).

import SymbolicUncertainties
import SymbolicUncertainties: SymbolicMeasurement
import Symbolics
import ModelingToolkit
using ModelingToolkit:
    System, Differential, unknowns, parameters, equations, get_iv

# Local alias for the `SymbolicUtils` re-export carried by
# `Symbolics`, avoiding an explicit dep on `SymbolicUtils`
# (already transitively present via `Symbolics`).
const _SU = Symbolics.SymbolicUtils

"""
    _make_time_var(name::Symbol, iv) -> Symbolics.Num

Programmatically build a time-dependent symbolic variable
`name(iv)` — equivalent to `@variables name(iv)` — but
callable with a runtime `Symbol`. Matches the lowering
produced by `@macroexpand @variables u(t)` in Symbolics 7.x.
"""
function _make_time_var(name::Symbol, iv)
    iv_val = Symbolics.value(iv)
    T = _SU.FnType{Tuple,Real,Nothing}
    fn_sym =
        _SU.Sym{Symbolics.SymReal}(name; type = T, shape = UnitRange{Int64}[])
    return Symbolics.wrap(
        _SU.setmetadata(
            fn_sym(iv_val),
            Symbolics.VariableSource,
            (:variables, name),
        ),
    )
end

# --- Internal helpers --------------------------------------------

"""
    _validate_uncertain_params(sys, uncertain_params) -> Vector{Symbolics.Num}

Return the ordered vector of parameter symbols (pulled from
each `SymbolicMeasurement.val`) after validating that every
one appears in `parameters(sys)` and that `sys` is a pure
ODE (no algebraic constraints). Raises `ArgumentError` on
the first violation.
"""
function _validate_uncertain_params(sys::System, uncertain_params)
    for eq in equations(sys)
        lhs_val = Symbolics.value(eq.lhs)
        ok = try
            op = Symbolics.operation(lhs_val)
            op isa Differential
        catch
            false
        end
        ok || throw(
            ArgumentError(
                "uncertainty_ode / propagate_ode: only pure " *
                "ODE systems are supported at M9 — algebraic " *
                "(DAE) constraints are out of scope. Offending " *
                "equation: $(eq)",
            ),
        )
    end

    sys_params = parameters(sys)
    param_syms = Symbolics.Num[]
    for (i, m) in enumerate(uncertain_params)
        p = m.val
        found = any(
            q -> isequal(Symbolics.value(q), Symbolics.value(p)),
            sys_params,
        )
        found || throw(
            ArgumentError(
                "uncertain_params[$i].val = $(p) is not a " *
                "parameter of the ODESystem. Parameters of " *
                "`sys` are $(sys_params).",
            ),
        )
        push!(param_syms, Symbolics.Num(p))
    end
    return param_syms
end

"""
    _build_sensitivity_eqs(sys, param_syms)
        -> (sens_states, sens_eqs, sens_matrix)

For each state `uᵢ(t)` (N states) and each uncertain
parameter `pⱼ` (K parameters), construct:

- a new state variable `Sᵢⱼ(t) ≜ ∂uᵢ/∂pⱼ(t)` (ordered
  state-major, parameter-minor),
- the forward-sensitivity equation
  `dSᵢⱼ/dt = Σ_k (∂fᵢ/∂u_k)·S_kⱼ + ∂fᵢ/∂pⱼ`.

Initial conditions are zero (supplied by the caller, not
baked into the returned system).

Returns the vector of sensitivity state `Num`s, the vector
of new `Equation`s, and the `N×K` matrix of sensitivity
symbols so the caller can build the GUM `err` expressions.
"""
function _build_sensitivity_eqs(sys::System, param_syms::Vector{Symbolics.Num})
    iv = get_iv(sys)
    D = Differential(iv)
    states = unknowns(sys)
    N = length(states)
    K = length(param_syms)

    eqs = equations(sys)

    rhs_by_state = Dict{Any,Any}()
    for eq in eqs
        state_sym = Symbolics.arguments(Symbolics.value(eq.lhs))[1]
        rhs_by_state[state_sym] = eq.rhs
    end

    sens_matrix = Matrix{Symbolics.Num}(undef, N, K)
    for i in 1:N
        for j in 1:K
            uᵢ = states[i]
            pⱼ = param_syms[j]
            uname = Symbolics.getname(uᵢ)
            pname = Symbolics.getname(pⱼ)
            svar_name = Symbol("∂", uname, "_∂", pname)
            sens_matrix[i, j] = _make_time_var(svar_name, iv)
        end
    end

    sens_eqs = ModelingToolkit.Equation[]
    for i in 1:N
        uᵢ = states[i]
        fᵢ = get(rhs_by_state, Symbolics.value(uᵢ), nothing)
        fᵢ === nothing && throw(
            ArgumentError(
                "ODESystem is missing an equation for state " *
                "$(uᵢ); check that `equations(sys)` covers " *
                "every state in `unknowns(sys)`.",
            ),
        )
        for j in 1:K
            pⱼ = param_syms[j]
            chain = Symbolics.Num(0)
            for k in 1:N
                u_k = states[k]
                ∂fᵢ_∂u_k = Symbolics.derivative(fᵢ, u_k)
                chain = chain + ∂fᵢ_∂u_k * sens_matrix[k, j]
            end
            ∂fᵢ_∂pⱼ = Symbolics.derivative(fᵢ, pⱼ)
            rhs = chain + ∂fᵢ_∂pⱼ
            push!(sens_eqs, D(sens_matrix[i, j]) ~ rhs)
        end
    end

    sens_states = vec(sens_matrix)
    return sens_states, sens_eqs, sens_matrix
end

# --- Public API --------------------------------------------------

function SymbolicUncertainties.propagate_ode(
    sys::System,
    uncertain_params::AbstractVector{<:SymbolicMeasurement},
)
    states = unknowns(sys)
    N = length(states)

    if isempty(uncertain_params)
        return [
            SymbolicMeasurement(Symbolics.Num(s), Symbolics.Num(0), nothing) for
            s in states
        ]
    end

    param_syms = _validate_uncertain_params(sys, uncertain_params)
    _, _, sens_matrix = _build_sensitivity_eqs(sys, param_syms)

    # `sens_matrix[i, j]` IS ∂uᵢ/∂pⱼ — a linear-form sensitivity
    # coefficient. Since M11 there is nothing left to compute here:
    # hand the coefficients to the chain rule and let the single
    # quadratic form produce the variance, as it does everywhere else.
    #
    # This is strictly more correct than the variance loop it
    # replaces. Two states that depend on a common uncertain parameter
    # are correlated, and the outputs now carry that correlation:
    # a difference of two such states cancels the shared contribution
    # instead of accumulating it.
    result = Vector{SymbolicMeasurement}(undef, N)
    for i in 1:N
        parts = [
            (uncertain_params[j], sens_matrix[i, j]) for
            j in eachindex(param_syms)
        ]
        result[i] =
            SymbolicUncertainties._chain(Symbolics.Num(states[i]), parts...)
    end
    return result
end

function SymbolicUncertainties.uncertainty_ode(
    sys::System,
    uncertain_params::AbstractVector{<:SymbolicMeasurement},
)
    param_syms = _validate_uncertain_params(sys, uncertain_params)
    sens_states, sens_eqs, _ = _build_sensitivity_eqs(sys, param_syms)

    all_states = [unknowns(sys); sens_states]
    all_eqs = [equations(sys); sens_eqs]
    iv = get_iv(sys)

    augmented =
        System(all_eqs, iv, all_states, parameters(sys); name = nameof(sys))
    return augmented
end

end # module SymbolicUncertaintiesModelingToolkitExt
