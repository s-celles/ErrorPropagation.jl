```@meta
CurrentModule = SymbolicUncertainties
```

# Methodology Reference

A single-page consolidation of the JCGM section pointers
for every exported symbol of `SymbolicUncertainties.jl`.
Row order matches the EARS specification's exported-API
appendix.

The per-function docstrings under `src/*.jl` are the
**source of truth** for REQ-160 citations; the table
below is a navigable consolidation view. Drift between
this table and the docstrings is caught by the
`test/package/test_api_freeze.jl` audit
(REQ-160 enforcement).

## Public surface

| Symbol | Description | JCGM / GUM ref |
|--------|-------------|----------------|
| [`SymbolicMeasurement`](@ref) | Estimate + combined standard uncertainty + dof. | §4.1 (estimate), §5.1 (u_c), §G.4 (ν_eff) |
| [`±`](@ref) | Constructor shorthand `val ± u`. | §6 (notation) |
| [`apply`](@ref) | Scalar function with optional sensitivity coefficient. | §5.1.3 |
| [`propagate`](@ref) | Multi-variable uncertainty propagation — a convenience over the operators, not a second path. | §5.1.2 eq (10), §5.2.2 eq (13) |
| [`propagate_vector`](@ref) | Vector-valued measurand propagation. | JCGM 102:2011 |
| [`sensitivity_coefficient`](@ref) | Symbolic `cᵢ = ∂f/∂xᵢ`. | §5.1.3 |
| [`uncertainty_contribution`](@ref) | Symbolic `\|cᵢ\| · uᵢ`. | §5.1.6 |
| [`relative_sensitivity`](@ref) | Fractional variance contribution. | §5.1.6 |
| [`dominant_source`](@ref) | Variable with largest variance contribution. | §5.1.6 |
| [`uncertainty_budget`](@ref) | Full GUM uncertainty budget table, derived from the quantity's own sources. | §5.1.6; EA-4/02 §7.3 |
| [`UncertaintyBudget`](@ref) | The budget value: rows, measurand, `u_c`, and whether correlations are declared. | EA-4/02 §7.3 |
| [`BudgetRow`](@ref) | One budget line. | §5.1.3 eq (11a), (11b) |
| [`expanded_uncertainty`](@ref) | `U = k · u_c`, returned as an [`ExpandedUncertainty`](@ref). | §6 (k = 2); §G.1.2 (arbitrary k); Table G.2 (coverage probability) |
| [`ExpandedUncertainty`](@ref) | `(val, U, k, ν_eff)` — a coverage-interval half-width, deliberately not propagatable. | §6.2 |
| [`declare_correlated`](@ref) | Returns two quantities carrying a declared correlation. | §5.2.2 eq (13) |
| [`covariance`](@ref) | Covariance of two quantities over their shared sources. | JCGM 102:2011 |
| [`correlation`](@ref) | Correlation coefficient derived from that covariance. | §5.2.2 eq (14) |
| [`welch_satterthwaite`](@ref) | Effective degrees of freedom. | §G.4 |
| [`required_precision`](@ref) | Symbolic condition on `uᵢ` for target `u_c`. | §5.2 (inverse) |
| [`budget_allocation`](@ref) | Lagrange allocation of uncertainty budget. | §5.2 (inverse) + Lagrange optimisation |
| [`build_evaluator`](@ref) | Compile to Julia / C function. | — (code generation) |
| `Symbolics.substitute` | Numerical substitution — extension method, not a new export. | — (numerical evaluation) |
| [`infer_precision`](@ref) | Solve for `uᵢ` given observed `u_c`. | — (inverse, see §5.2) |
| [`infer_all_precisions`](@ref) | Worst-case single-source attribution. | — (inverse, see §5.2) |
| [`latex`](@ref) | LaTeX string for certificates (requires `Latexify.jl`). | §7 (reporting) |
| [`to_expr`](@ref) | Extract `(val, err)` tuple of `Num`. | — (export utility) |
| [`propagate_ode`](@ref) | ODE uncertainty propagation (requires `ModelingToolkit.jl`). | GUM Supplement 3 (anticipated) |
| [`uncertainty_ode`](@ref) | Augmented `ODESystem` for numerical integration. | GUM Supplement 3 (anticipated) |
| [`check_linearity`](@ref) | Nonlinearity indicator per input variable. | §5.1.1 (linearity note) |
| [`linearisation_bound`](@ref) | Rigorous bound on the first-order error over the whole coverage region. | §5.1.1 (linearity note); JCGM 101:2008 (the sampling alternative) |
| [`second_order_correction`](@ref) | Second-order term on the *estimate*, returned never applied. | JCGM 100:2008/Amd.1:2026 §4.1.4 NOTE 1; eq (H.10) |
| [`check_units`](@ref) | Opt-in, non-throwing dimensional report. | §4.3.1 (affine scales); VIM §1.1 (kind) |
| [`UnitReport`](@ref) | Findings returned by `check_units`. | §4.3.1 |
| `JuliaTarget` | Symbolics code-generation target, re-exported. | — (REQ-132 documented exception) |
| `CTarget` | Symbolics code-generation target, re-exported. | — (REQ-132 documented exception) |

## Notes

- **`substitute`** is accessed as
  `Symbolics.substitute(m, dict)` — an extension method
  on `Symbolics.substitute`, not a new export from
  `SymbolicUncertainties`. The specification captured this decision
  to avoid the `DynamicPolynomials.substitute` /
  `ExproniconLite.substitute` name clash.
- **`JuliaTarget`** and **`CTarget`** are re-exports
  from `Symbolics.jl` — the two documented exceptions to
  the REQ-132 "no-Symbolics-names-leaked" audit, needed
  for the `build_evaluator(m, variables; target = …)`
  keyword syntax.
- **`propagate_ode`** and **`uncertainty_ode`** are
  exported stubs in `src/mtk_stubs.jl` that raise
  `ArgumentError` until `ModelingToolkit.jl` is loaded;
  the live methods live in
  `ext/SymbolicUncertaintiesModelingToolkitExt.jl`.
- **`latex`** is similarly a stub in `src/latex_stub.jl`
  replaced by the `SymbolicUncertaintiesLatexifyExt` extension
  when `Latexify.jl` is loaded.
- **`linearisation_bound`** and
  **`second_order_correction`** answer two different
  questions and neither replaces the other: the first
  bounds the error the first-order law makes in `u_c`, the
  second returns the term the 2026 amendment asks for on
  the estimate `y`. A product of independent inputs needs
  the second not at all — its estimate is exact — and the
  first very much, since all of its nonlinearity sits in
  the mixed partial.

## Cross-reference

- Standards-traceability gate: EARS REQ-160 (per-function
  citation), REQ-161 (per-topic docs page), REQ-162 (six
  canonical worked examples — see [Worked Examples](worked-examples.md)).
- Waived requirements: see [Limitations](limitations.md)
  for the post-1.0 deferral list.
- Citation: `CITATION.bib` at the repository root.

## Re-export docstrings

```@docs
JuliaTarget
CTarget
```
