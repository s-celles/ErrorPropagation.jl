@testitem "module loads cleanly" begin
    using SymbolicUncertainties

    public = names(SymbolicUncertainties; all = false, imported = false)

    # Public surface at the end of Milestone M9:
    #   M1: SymbolicMeasurement, ±
    #   M2: apply, propagate, propagate_vector
    #   M3: sensitivity_coefficient, uncertainty_contribution,
    #       relative_sensitivity, uncertainty_budget,
    #       expanded_uncertainty, welch_satterthwaite,
    #       dominant_source
    #  M11: UncertaintyBudget, BudgetRow (the budget's own type and
    #       its rows — REQ-209)
    #  M14: monte_carlo, MonteCarloComparison (REQ-230; the working
    #       method arrives with the MonteCarloMeasurements extension)
    #   M4: (substitute is a Symbolics.substitute method — not exported)
    #   M5: infer_precision, infer_all_precisions, required_precision,
    #       budget_allocation
    #   M6: check_linearity
    #   M7: build_evaluator, to_expr, latex (stub),
    #       JuliaTarget, CTarget (re-exports)
    #   M9: propagate_ode, uncertainty_ode (stubs + MTK extension)
    @test Set(public) == Set([
        :SymbolicUncertainties,
        :SymbolicMeasurement,
        :±,
        :apply,
        :propagate,
        :propagate_vector,
        :sensitivity_coefficient,
        :uncertainty_contribution,
        :relative_sensitivity,
        :uncertainty_budget,
        :UncertaintyBudget,
        :BudgetRow,
        :expanded_uncertainty,
        :ExpandedUncertainty,
        :welch_satterthwaite,
        :dominant_source,
        :infer_precision,
        :infer_all_precisions,
        :required_precision,
        :budget_allocation,
        :check_linearity,
        :check_units,
        :evaluate,
        :report,
        :UncertaintyReport,
        :certificate,
        :CalibrationCertificate,
        :ConformityStatement,
        :CertificateFinding,
        :declare_correlated,
        :covariance,
        :correlation,
        :linearisation_bound,
        :second_order_correction,
        :UnitReport,
        :build_evaluator,
        :to_expr,
        :latex,
        :JuliaTarget,
        :CTarget,
        :propagate_ode,
        :uncertainty_ode,
        :monte_carlo,
        :MonteCarloComparison,
    ])
end

@testitem "REQ-132: no canonical Symbolics names leaked (M8 audit)" begin
    using SymbolicUncertainties

    public = Set(names(SymbolicUncertainties; all = false, imported = false))

    # `JuliaTarget` and `CTarget` are the two documented-exceptions
    # re-exports from M7. Every other canonical Symbolics name must
    # stay qualified as `Symbolics.<name>` (REQ-132).
    banned = [
        Symbol("@variables"),
        :simplify,
        :derivative,
        :gradient,
        :jacobian,
        :substitute,
        :get_variables,
        :Num,
        :value,
        :toexpr,
        :symbolic_solve,
        :build_function,
    ]
    for name in banned
        @test !(name in public)
    end
end
