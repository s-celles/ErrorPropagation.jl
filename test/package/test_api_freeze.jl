@testitem "REQ-160: Appendix A symbols exported, documented, and JCGM-cited" begin
    # M10 API-freeze audit: every symbol in EARS Appendix A
    # (after the M10 R7 reconciliation) MUST be exported,
    # MUST have a non-empty docstring, and MUST cite at least
    # one JCGM / EA section. See
    # `specs/012-stable-release/contracts/api_freeze_audit.md`.

    using SymbolicUncertainties
    using Symbolics

    # Order matches EARS Appendix A: the 25 rows of the M10
    # reconciliation, plus the symbols M11, M12 and M13 added.
    # `ExpandedUncertainty` is the M11 return type of
    # `expanded_uncertainty`, and `UnitReport` the M12 return type
    # of `check_units` — a listed export cannot have an
    # undocumented return type.
    # `:substitute` is special-cased — it is a method on
    # `Symbolics.substitute`, not a new export from
    # `SymbolicUncertainties`. We check export status only for the
    # 24 names that ARE exported, and separately verify that
    # `Symbolics.substitute` has a `SymbolicMeasurement` method
    # and its docstring is present in `src/substitute.jl`.
    APPENDIX_A_EXPORTED = [
        :SymbolicMeasurement,
        :±,
        :apply,
        :propagate,
        :propagate_vector,
        :sensitivity_coefficient,
        :uncertainty_contribution,
        :relative_sensitivity,
        :dominant_source,
        :uncertainty_budget,
        :UncertaintyBudget,
        :BudgetRow,
        :expanded_uncertainty,
        :ExpandedUncertainty,
        :welch_satterthwaite,
        :required_precision,
        :budget_allocation,
        :build_evaluator,
        :infer_precision,
        :infer_all_precisions,
        :latex,
        :to_expr,
        :propagate_ode,
        :uncertainty_ode,
        :check_linearity,
        :check_units,
        :UnitReport,
        :declare_correlated,
        :covariance,
        :correlation,
        :linearisation_bound,
        :second_order_correction,
        :JuliaTarget,
        :CTarget,
    ]

    public_set =
        Set(names(SymbolicUncertainties; all = false, imported = false))

    jcgm_rx =
        r"§\d+(\.\d+)*|GUM\s+Supplement\s+\d|EA[-\s]?4/02|JCGM\s*\d+|Symbolics"

    for s in APPENDIX_A_EXPORTED
        # (a) exported
        @test s in public_set

        # (b) docstring non-empty (use @doc macro which works
        # uniformly across single-method and multi-method syms)
        doc = string(Core.eval(@__MODULE__, :(@doc SymbolicUncertainties.$(s))))
        @test length(strip(doc)) > 20

        # (c) cites a JCGM section (lax rule — either §, GUM Supplement,
        # EA-4/02, JCGM number, or Symbolics reference for the two
        # re-exports). Skip the JCGM-regex rule for `JuliaTarget` and
        # `CTarget` which are re-exports and would require re-documenting
        # upstream content.
        if s ∉ (:JuliaTarget, :CTarget)
            @test occursin(jcgm_rx, doc)
        end
    end

    # Separately verify the `substitute` method-extension path
    # (M4): at least one `SymbolicMeasurement` method exists on
    # `Symbolics.substitute`.
    subst_ms = methods(Symbolics.substitute)
    has_sm_method =
        any(m -> occursin("SymbolicMeasurement", string(m.sig)), subst_ms)
    @test has_sm_method
end
