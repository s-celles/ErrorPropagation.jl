module SymbolicUncertainties

import Symbolics
import Printf
using PrecompileTools: @compile_workload

export SymbolicMeasurement,
    ±,
    apply,
    propagate,
    propagate_vector,
    sensitivity_coefficient,
    uncertainty_contribution,
    relative_sensitivity,
    uncertainty_budget,
    UncertaintyBudget,
    BudgetRow,
    expanded_uncertainty,
    ExpandedUncertainty,
    welch_satterthwaite,
    dominant_source,
    infer_precision,
    infer_all_precisions,
    required_precision,
    budget_allocation,
    check_linearity,
    check_units,
    evaluate,
    report,
    UncertaintyReport,
    certificate,
    CalibrationCertificate,
    ConformityStatement,
    CertificateFinding,
    declare_correlated,
    covariance,
    correlation,
    linearisation_bound,
    second_order_correction,
    UnitReport,
    build_evaluator,
    to_expr,
    latex,
    propagate_ode,
    monte_carlo,
    MonteCarloComparison,
    uncertainty_ode,
    parse_measurement_model,
    evaluate_measurement_model

# Re-exports from Symbolics for the code-generation target API.

"""
    JuliaTarget

Re-export of [`Symbolics.JuliaTarget`](https://symbolics.juliasymbolics.org/stable/manual/build_function/).
Pass to `build_evaluator(m, variables; target = JuliaTarget())`
to generate a compiled Julia evaluator (the default target).
Documented REQ-132 exception — see
[`docs/src/methodology-reference.md`](methodology-reference.md).
"""
const JuliaTarget = Symbolics.JuliaTarget

"""
    CTarget

Re-export of [`Symbolics.CTarget`](https://symbolics.juliasymbolics.org/stable/manual/build_function/).
Pass to `build_evaluator(m, variables; target = CTarget())`
to generate a C source `String` callable from C /
Fortran / any FFI-compatible host. Documented REQ-132
exception — see
[`docs/src/methodology-reference.md`](methodology-reference.md).
"""
const CTarget = Symbolics.CTarget

export JuliaTarget, CTarget

include("docstrings.jl")
include("source.jl")
include("type.jl")
include("correlation.jl")
include("pm.jl")
include("show.jl")
include("safety.jl")
include("arithmetic.jl")
include("mixed.jl")
include("differentiation.jl")
include("math.jl")
include("propagate.jl")
include("apply.jl")
include("propagate_vector.jl")
include("sensitivity.jl")
include("budget.jl")
include("expanded.jl")
include("welch.jl")
include("dominant.jl")
include("units.jl")
include("substitute.jl")
include("latex.jl")
include("infer.jl")
include("budget_allocation.jl")
include("linearity.jl")
include("certified.jl")
include("codegen.jl")
include("latex_stub.jl")
include("mtk_stubs.jl")
include("causal_types.jl")
include("causal_stubs.jl")
include("mc_stubs.jl")
include("report.jl")
include("certificate.jl")

# M10 precompile workload (FR-009) — warm up the four
# canonical call paths used in ~95% of user sessions:
# arithmetic (M1), math functions (M2), propagate (M2),
# uncertainty_budget (M3). The M4..M9 paths are
# intentionally excluded to keep package load time
# bounded. See `specs/012-stable-release/research.md` R2.
@compile_workload begin
    # Suppress REQ-140 / REQ-141 safety warnings during the
    # workload — they are expected on purely symbolic args.
    Base.CoreLogging.with_logger(Base.CoreLogging.NullLogger()) do
        Symbolics.@variables V I σV σI a b σa σb

        # Arithmetic (M1)
        _m1 = (V ± σV) / (I ± σI)

        # Math functions (M2)
        _m2 = sqrt(a ± σa)
        _m3 = exp(a ± σa)

        # Multi-variable propagate (M2)
        _m4 = propagate((x, y) -> x * y, [a ± σa, b ± σb])

        # Uncertainty budget (M3)
        _rows = uncertainty_budget(_m1, [V, I], [σV, σI])
    end
end

end # module SymbolicUncertainties
