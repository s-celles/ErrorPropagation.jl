# SymbolicUncertainties.jl — Roadmap

This roadmap decomposes the [EARS specification](specification/ears.md) into
incremental milestones following [Semantic Versioning](https://semver.org/) and
[Keep a Changelog](https://keepachangelog.com/) conventions. Each milestone is
scoped so that the package remains functional, tested, and documented at every
release.

Development follows **Test-Driven Development** with
[TestItemRunner.jl](https://github.com/julia-vscode/TestItemRunner.jl) and
SciML/Julia package conventions. Each milestone ships with:

- failing tests written first, then implementation;
- docstrings with explicit JCGM 100:2008 section references (REQ-160);
- a documentation page in `docs/`;
- a `CHANGELOG.md` entry in *Keep a Changelog* format;
- clean `Pkg.test()` and warning-free `docs/make.jl` builds before commit;
- Conventional-commit prefixes on branches merged into `main`.

Status legend: `[ ]` planned · `[~]` in progress · `[x]` complete · `[⛔]` blocked upstream

---

## Milestone M0 — Project bootstrap (v0.0.1) ✅

Infrastructure only; no user-facing API.

- [x] Initialise `Project.toml` with `Symbolics.jl` as sole mandatory
      dependency (REQ-130).
- [x] Target Julia `>= 1.10` (LTS) in `[compat]` (REQ-156).
- [x] `src/SymbolicUncertainties.jl` module skeleton; `src/docstrings.jl`
      placeholder (DocStringExtensions deferred per REQ-130 tension).
- [x] `test/runtests.jl` wired to `TestItemRunner`; `test/package/` for
      Aqua.jl, JuliaFormatter, and DocTest quality checks.
- [x] `docs/` skeleton with `Documenter.jl`, `make.jl`, and `pages.jl`
      table of contents.
- [x] `CHANGELOG.md`, `README.md` with regulated-use disclaimer,
      `LICENSE.md` with verbatim REQ-170 non-warranty clause.
- [x] `.github/workflows/CI.yml`: test matrix on Julia LTS (1.10) and
      latest stable (`"1"`), Ubuntu, with Codecov upload (REQ-157).
- [x] `.github/workflows/Documentation.yml`: Documenter build + GitHub
      Pages deploy on `main` and tags (REQ-158).
- [x] `.github/workflows/TagBot.yml`: `JuliaRegistries/TagBot` for
      automatic release tagging (REQ-159).
- [x] Pre-commit hooks (JuliaFormatter, trailing whitespace).
- [x] `.JuliaFormatter.toml` (max 80 chars, no trailing whitespace).

**Exit criteria:** `Pkg.test()` and `docs/make.jl` both succeed with zero
warnings. ✅ Verified.

---

## Milestone M1 — Core type and arithmetic (v0.1.0) ✅

> EARS §2 terminology, §3 arithmetic.

- [x] `SymbolicMeasurement` type with fields `val::Num`, `err::Num`,
      `dof::Union{Num,Nothing}` (REQ-002).
- [x] `±` infix constructor for `Num` operands (REQ-003).
- [x] Numeric constructor promoting to `Num` literals (REQ-004).
- [x] Non-negativity check on numeric `err`, raising `ArgumentError`
      (REQ-005). Negativity guard excludes `Symbolics.Num` which is
      `<: Real` but whose `<` returns a symbolic boolean.
- [x] Explicitly *not* a subtype of `AbstractFloat`/`Real` (REQ-006).
- [x] Binary operators `+`, `-`, `*`, `/`, `^` for two
      `SymbolicMeasurement` operands (REQ-010 – REQ-014).
- [x] Mixed `SymbolicMeasurement`/`Number`/`Num` operations via zero-
      uncertainty wrapping (REQ-015).
- [x] `Base.show` Unicode `val ± err` display with ASCII `+/-` fallback
      (REQ-111). Notation `±` for `u_c` departs from JCGM 100:2008
      §7.2.2 — documented transparency clause in `getting-started.md`.
- [x] `Symbolics.simplify` applied after each operation (REQ-110),
      routed through `_simplify_for_report` hook since M2 refactor.
- [x] Docs page **Getting Started** with Ohm's-law worked example and
      `±` / §7.2.2 divergence notice (REQ-161 row 1).
- [x] Tests: arithmetic identities, negative-`err` rejection,
      type-stability sanity checks, Ohm's-law exit gate (75/75 pass).

**Known limitation (UB-002):** Binary operators do not track operand
identity — `x - x` returns spurious uncertainty. Worked around in M2 via
`propagate(f, [m])`; fixed at the type level in M11, which removes UB-002
from `upstream-bugs.md`. See `upstream-bugs.md` UB-002.

**Exit criteria:** Ohm's law `R = V/I` with symbolic V, I, σV, σI returns
the expected `(V/I)·sqrt((σV/V)² + (σI/I)²)` uncertainty. ✅ Verified
(`test/examples/test_ohms_law.jl`). Note: the textbook Ohm's-law form is
a derivation of JCGM 100:2008 §5.1.2 equation (10); the GUM's own
explicit "loi d'Ohm" reference is at §H.2.2 in a correlated 3-output
impedance context.

---

## Milestone M2 — Mathematical functions & multi-variable propagation (v0.2.0) ✅

> EARS §4 math functions, §5 multi-variable propagation.

- [x] Override `sin`, `cos`, `tan`, `asin`, `acos`, `atan`, `sinh`,
      `cosh`, `tanh`, `exp`, `log`, `log2`, `log10`, `sqrt`, `abs`,
      `inv` via `Symbolics.derivative` (REQ-020).
- [x] Closed-form derivative failure path: `ArgumentError` suggesting
      `apply(f, x; derivative=...)` (REQ-021). Detection via
      `_safe_derivative` + `_has_unresolved_differential` walk.
- [x] `apply(f, x::SymbolicMeasurement; derivative=nothing)` (REQ-022).
- [x] `propagate(f, ::Vector{SymbolicMeasurement})` — uncorrelated case
      (REQ-030). Fixes UB-002 (`x - x → 0 ± 0` via symbolic
      differentiation).
- [x] `propagate(f, measurements, Σ::Matrix{Num})` — correlated case with
      cross terms (REQ-031). Diagonal-Σ equivalence invariant (FR-010).
      **Superseded in M11** — correlation becomes a property of the
      sources, and this three-argument method is removed (REQ-203,
      REQ-207).
- [x] `DimensionMismatch` on non-square/mis-sized covariance matrices
      (REQ-032).
- [x] `propagate_vector(f, measurements)` — vector-valued measurand
      (REQ-033, JCGM 102:2011). Marginal `err` only; cross-output
      covariance deferred.
- [x] Docs page **Sensitivity Analysis** with voltage-divider worked
      example, identity-cancellation fix walkthrough, `apply` escape
      hatch, correlated and vector-valued demos, and full `@docs` API
      reference (REQ-161 row "Sensitivity Analysis").
- [x] Shared `AsFloat` `@testsnippet` factored from M1 inline helpers.
- [x] Tests: REQ-151 (linear-case closed form `|a|·u(x)`), voltage-
      divider exit gate, identity-cancellation regression (UB-002 fix),
      `DimensionMismatch` shape validation, `apply` escape hatch with
      `@register_symbolic`, polar-to-Cartesian `propagate_vector`.
      170/170 pass.
- [x] `_simplify_for_report` hook extracted for future CAS extensions
      (Giac.jl). Default: `Symbolics.simplify`.

**Exit criteria:** Voltage-divider `Vout = Vin·R2/(R1+R2)` via
`propagate` returns sensitivity coefficients matching the closed-form
textbook reference. ✅ Verified (`test/examples/test_voltage_divider.jl`).
Note: the voltage divider is a textbook illustration, not a GUM Annex H
worked example (corrected per M1 GUM audit — see REQ-153 in
`specification/ears.md`).

---

## Milestone M2.5 — Giac.jl CAS extension (v0.2.1) ✅

> Optional package extension for CAS-grade symbolic simplification.

- [x] `ext/SymbolicUncertaintiesGiacExt.jl` activating when `Giac.jl` is
      loaded, overloading `_simplify_for_report` to route through
      Giac's `simplify` (REQ-131 row 6).
- [x] `Giac` added to `Project.toml` `[weakdeps]` + `[extensions]`.
- [x] Bidirectional Symbolics ↔ Giac expression conversion via the
      `Giac.to_giac` / `Giac.to_symbolics` round-trip bridged by
      `Giac.giac_eval("simplify(…)")` (the actual round-trip uses
      Giac's public `to_giac`/`to_symbolics` API rather than a raw
      string round-trip through `Symbolics.parse_expr_to_symbolic`).
- [x] Verified: `-tan(x) + sin(x)/cos(x)` reduces to `0` via Giac's
      `simplify` (asserted in `test/ext/test_giac_ext.jl`).
- [x] Regression: all 170 M0/M1/M2 tests still pass when Giac is
      loaded; 8 new Giac-specific tests bring the total to 178/178.
- [x] Docs note in **Sensitivity Analysis** explaining the optional
      Giac integration and when to load it.
- [⛔] `assume(σ >= 0)` integration for sign-aware simplification of
      `abs(σ)` in sensitivity coefficients — **blocked upstream**, see
      `upstream-bugs.md` UB-003: `Symbolics.jl` has no assumptions
      framework, so there is no assumption context for the
      `Symbolics ↔ Giac` bridge to transport. Giac's own `assume`
      cannot be reached without inventing one on this side of the
      bridge, which is a design decision, not an integration. Not
      schedulable until UB-003 moves.

**Exit criteria:** With `using Giac` loaded before `using
SymbolicUncertainties`, the symbolic branch of the R7 two-check strategy
passes for the `-tan(x) + sin(x)/cos(x)` identity and for the
`tan(x)·cos(x) − sin(x)` identity. All 170 M2 tests remain green
(178/178 with the new Giac tests). ✅ Verified
(`test/ext/test_giac_ext.jl`).

---

## Milestone M3 — Uncertainty budget, expanded uncertainty, Welch-Satterthwaite (v0.3.0) ✅

> EARS §6 budget, §7 expanded uncertainty.

- [x] `sensitivity_coefficient(m, xᵢ)` (REQ-040).
- [x] `uncertainty_contribution(m, xᵢ, σᵢ)` (REQ-041).
- [x] `relative_sensitivity(m, xᵢ, σᵢ)` (REQ-042). Signature takes
      `(m, xᵢ, σᵢ)` — the per-variable call composes with
      `uncertainty_budget` row-by-row.
- [x] `dominant_source(m, variables, sigmas; values=nothing)`
      with optional numeric substitution (REQ-043). Signature
      takes an explicit `sigmas` positional vector per the
      contract review — see `specs/005-budget-and-expanded/contracts/dominant.md`.
- [x] `uncertainty_budget(m, variables, sigmas)` returning
      `Vector{NamedTuple}` per EA-4/02 §7.3 layout (REQ-044).
- [x] `expanded_uncertainty(m, k=2)` and `expanded_uncertainty(m)`
      (REQ-050).
- [x] `welch_satterthwaite(contributions, dofs)` (REQ-052).
- [x] `expanded_uncertainty(m; coverage_probability)` deriving
      `k` from `dof` via an internal Student-t quantile table
      (GUM Table G.2) for `p ∈ {0.68, 0.90, 0.95, 0.99}`
      (REQ-051). No new runtime dep.
- [x] `@warn` on numeric `ν_eff < 30` (REQ-175).
- [x] Mandatory warning admonition block in docstrings of
      `expanded_uncertainty` and `welch_satterthwaite` (REQ-174).
- [x] Docs pages **Uncertainty Budget** and **Expanded Uncertainty**
      (REQ-161).
- [x] Tests: REQ-045 / REQ-152 (variance fractions sum to 1) —
      asserted for linear, product, and voltage-divider cases.

**Exit criteria:** `uncertainty_budget` on the voltage-divider
returns three rows whose relative sensitivities sum to `1` under
`Symbolics.simplify`; `expanded_uncertainty(Vout, 2)` preserves
`val` and returns `err = 2·Vout.err`; `welch_satterthwaite` on
symbolic contributions matches JCGM §G.4 eq (G.2b); numeric
`ν_eff < 30` triggers the REQ-175 `@warn`. ✅ Verified by the M3
test suite (`test/budget/`, `test/expanded/`, `test/welch/`,
`test/dominant/`, `test/examples/test_budget_voltage_divider.jl`).

---

## Milestone M4 — Display, numerical evaluation, error handling (v0.4.0) ✅

> EARS §13 display, §14 substitution, §16 safety.

- [x] `show(io, MIME"text/latex", m)` for Jupyter/Pluto (REQ-112).
      Emits `$val \pm err$` with inline math delimiters per
      Clarifications Q1.
- [x] `substitute(m, dict)` across `val`, `err`, `dof` (REQ-120).
      Implemented as an extension of `Symbolics.substitute` (not a
      new exported name) to avoid the `DynamicPolynomials.substitute`
      / `ExproniconLite.substitute` name clash. Users call it via
      `using Symbolics`.
- [x] Silent ignore of extraneous dict keys (REQ-122).
- [x] Full symbolic preservation until explicit `substitute`
      (REQ-123, REQ-142). `build_evaluator` remains deferred to M7.
- [x] Division-by-zero `@warn` when `y.val` cannot be proven nonzero
      (REQ-140). Wired into the M1 `Base.:/` binary operator and
      the M2 `propagate` syntactic walker (uniform coverage).
- [x] Domain `@warn` for `sqrt`/`log`/`log2`/`log10` on non-positive
      `val` (REQ-141). Same uniform coverage across M1 overloads and
      propagate path.

**Deferred to later milestones:**

- REQ-121 (`Measurements.jl` interop — return a plain
  `Measurements.Measurement` when both fields are fully numeric)
  — parked for a dedicated extension-machinery milestone
  mirroring the M2.5 Giac pattern.
- `assume_positive!` / `assume_nonzero!` in-library layer — see
  `upstream-bugs.md` UB-003. Without an upstream `Symbolics.jl`
  assumptions API, the library takes a conservative over-warning
  stance.
- `SymbolicUncertaintiesLatexifyExt.jl` — optional package extension
  for production-grade LaTeX rendering via `Latexify.jl`, also
  mirroring the M2.5 Giac pattern.

**Exit criteria:** voltage-divider measurand substituted with
six concrete numerics produces numeric `val` and `err` matching
the hand-computed reference to 1e-10; `MIME"text/latex"` display
emits `$...$`-delimited output; REQ-140 / REQ-141 warnings fire
uniformly across M1 and M2 paths. ✅ Verified by the M4 test
suite (`test/substitute/`, `test/display/test_latex_rendering.jl`,
`test/safety/`, `test/examples/test_substitute_voltage_divider.jl`).

---

## Milestone M5 — Protocol optimisation & inverse inference (v0.5.0) ✅

> EARS §8 optimisation, §11 inverse inference.

- [x] `required_precision(m, σᵢ, target_uc)` (REQ-060).
      Implemented as a one-line delegate to `infer_precision`
      per research R6 — the two names preserve the distinct
      EARS framings (precision condition vs. solved equation)
      over identical closed-form output.
- [x] `budget_allocation(m, variables, sigmas, total_budget)`
      via the closed-form inverse-sensitivity-squared Lagrange
      weighting (REQ-061). Signature takes explicit parallel
      `variables + sigmas` vectors for consistency with the M3
      `uncertainty_budget` contract.
- [x] Return values are `Num` or `Dict{Num, Num}` — purely
      symbolic (REQ-062).
- [x] `infer_precision(m, σᵢ, target_uc)` — the literal
      `Symbolics.solve_for` in EARS REQ-090 refers to an
      older Symbolics API that only handles linear equations.
      M5 honours the **intent** of REQ-090 via a closed-form
      algebraic split that sidesteps the
      `Symbolics.symbolic_solve ⇒ Nemo.jl` chain, keeping the
      zero-new-deps guarantee.
- [x] `ArgumentError` on unsolvable cases (REQ-091) — fires
      when `m.err` is not quadratic in σᵢ, when the target is
      negative, or when σᵢ is absent from `m.err`.
- [x] `infer_all_precisions(m, variables, sigmas, target_uc)`
      (REQ-092) — closed-form worst-case table via
      `σᵢ* = target_uc / |cᵢ|`.
- [x] Docs pages **Protocol Optimisation** and **Inverse
      Inference** (REQ-161 rows).
- [x] Worked example: RLC resonance protocol optimisation —
      the M5 exit gate `test/examples/test_rlc_resonance.jl`
      (SC-004).

**Exit criteria:** `infer_precision(f0, σL, ε·f0.val)` on the
RLC-resonance measurand returns a closed-form σL* whose
round-trip substitution through `f0.err` satisfies the
equality `f0.err == ε·f0.val` to 1e-10. ✅ Verified by
`test/examples/test_rlc_resonance.jl` without `Nemo.jl`
loaded.

---

## Milestone M6 — Linearity diagnostics (v0.6.0) ✅

> EARS §20 linearity warnings.

- [x] `check_linearity(f, measurements; values = nothing)`
      returning `Dict{Num, Num}` of `ηᵢ` indicators
      (REQ-180). The `values` keyword mirrors the M3
      `dominant_source` convention.
- [x] `@warn` when any numeric `|ηᵢ| > 0.1`, recommending
      `MonteCarloMeasurements.jl` / JCGM 101:2008 (REQ-181).
      Only fires when `values` substitutes the indicator to
      a concrete `Float64`.
- [x] No silent higher-order corrections (REQ-182) —
      asserted by
      `test/linearity/test_no_higher_order_correction.jl`.
- [x] Docs page **Linearity Check**
      (`docs/src/linearity-check.md`).
- [x] Tests: REQ-155 (`exp(x)` near `x=1` vs linear model)
      — exit-gate test
      `test/linearity/test_nonlinear_indicator_positive.jl`.

**Deferred (documented in spec Assumptions):**

- Mixed partial derivatives `∂²f/∂xᵢ∂xⱼ` — diagonal only
  for M6.
- Threshold as keyword argument — fixed at `0.1` per
  REQ-181.
- Numerical fallback on second-derivative failure —
  `ArgumentError` per constitution Principle III.

**Exit criteria:** `check_linearity(a -> exp(a), [x ± σx])`
at `x=1, σx=0.1` evaluates numerically to `|η| ≈ 0.05`;
the linear `a -> 2a + 3` case simplifies to `η = 0`. ✅
Verified by `test/linearity/` (7 test items, 18 assertions).

---

## Milestone M7 — Code generation & LaTeX (v0.7.0) ✅

> EARS §9 code generation.

- [x] `build_evaluator(m, variables)` → compiled Julia
      function (REQ-070). Runtime-compiled via
      `Symbolics.build_function` with `expression = Val{false}`.
- [x] `build_evaluator(m, variables; target=CTarget())`
      returning C source `String` (REQ-071).
      **`FortranTarget` is dropped from scope** —
      Symbolics 7 does not export it; see
      `upstream-bugs.md` UB-004. `ArgumentError` fires on
      any unsupported target.
- [x] `to_expr(m)` → `Tuple{Num, Num}` (REQ-073).
- [x] Docs page **Code Generation** with hand-rolled
      LaTeX-certificate example using `to_expr` +
      handwritten prose (the formal `latex(m)` full
      implementation ships in M8).
- [x] `latex(m)` stub raising `ArgumentError` pointing at
      `Latexify.jl` and the M4
      `MIME"text/latex"` alternative (REQ-072 deferred to
      M8). The stub is declared `(args...; kwargs...)` so
      the M8 extension **adds** a more specific method
      rather than overwriting this one — method overwriting
      during precompilation is a hard error on Julia ≥ 1.12.
      Same pattern as the M9 `src/mtk_stubs.jl`.

**Deferred (documented in spec Assumptions):**

- `FortranTarget` support — blocked on upstream
  `Symbolics.jl` feature (UB-004).
- Full `latex(m)` — planned for M8 via
  `SymbolicUncertaintiesLatexifyExt` package extension.
- Compile-and-link validation of the C-target output —
  requires a C toolchain on CI; out of scope for M7.
- CI-gated performance benchmark — flaky; documented
  only.

**Exit criteria:** compiled Julia evaluator on the Ohm's-
law measurement returns `(10.0, 0.028284271247…)` at
`V=5, I=0.5, σV=0.01, σI=0.001` to 1e-12 (SC-002); C
target emits a `String` containing `#include <math.h>` and
`void evaluate_measurement(`; `latex(m)` stub fires
`ArgumentError` mentioning `Latexify.jl`. ✅ Asserted by
`test/codegen/` (6 test files, 37 assertions).

---

## Milestone M8 — Package extensions (v0.8.0) ✅

> EARS §12 dimensional analysis, §15 interoperability.

- [x] `ext/SymbolicUncertaintiesLatexifyExt.jl` implementing
      `latex(m)` (REQ-072, REQ-131 row 1) — adds a
      `Latexify.latexify`-backed `::SymbolicMeasurement`
      method that takes precedence over the M7 generic
      fallback.
- [x] `ext/SymbolicUncertaintiesMeasurementsExt.jl` with
      post-substitute conversion to
      `Measurements.Measurement` (REQ-121, REQ-131 row 2).
      Explicit conversion only (no auto-promotion from
      `substitute`).
- [x] `ext/SymbolicUncertaintiesUnitfulExt.jl` for dimensional
      annotations with `DimensionError` on mismatch
      (REQ-100, REQ-101, REQ-102, REQ-131 row 4). A
      `DynamicQuantities.jl` counterpart is a post-1.0 candidate —
      see "Ecosystem bridges" below.
- [x] `ext/SymbolicUncertaintiesDataFramesExt.jl` upgrading
      `uncertainty_budget` to return a `DataFrame` via
      the new opt-in `as = :dataframe` keyword (REQ-044,
      REQ-131 row 5). The default behaviour is
      preserved (`as = :namedtuple`) for M3 backward
      compatibility.
- [x] No re-export of `Symbolics.jl` symbols (REQ-132) —
      asserted by the strengthened smoke test listing a
      banned-names set. The M7 `JuliaTarget` / `CTarget`
      re-exports are explicitly documented exceptions.
- [x] Docs pages **Dimensional Analysis** and
      **Interoperability**.

**Exit criteria:** all 4 extensions ship and load cleanly;
451/451 tests green with all extensions active in the test
environment; `uncertainty_budget` preserves the M3
NamedTuple default; `as = :dataframe` triggers the DataFrame
path; `latex(m)` transparently upgrades from the M7 fallback to
the Latexify-backed implementation when `Latexify.jl` is
loaded, without overwriting a method. ✅ Verified by `test/ext_*/` plus the
`test/ext_combined/test_all_extensions_load.jl` smoke
test.

---

## Milestone M9 — ModelingToolkit integration (v0.9.0) ✅

> EARS §10, anticipating JCGM GUM Supplement 3.

- [x] `ext/SymbolicUncertaintiesModelingToolkitExt.jl` skeleton (REQ-080).
      Weakdep on `ModelingToolkit.jl` (^11) with matching
      `[weakdeps]` + `[extensions]` + `[compat]` entries.
- [x] `propagate_ode(sys, uncertain_params)` returning a
      `Vector{SymbolicMeasurement}` with forward-sensitivity-equation
      construction via `Symbolics.derivative` (REQ-081). Each output's
      `err` is `sqrt(Σⱼ (∂uᵢ/∂pⱼ)² · σⱼ²)` with time-dependent
      sensitivity symbols left free for the augmented solve.
- [x] `uncertainty_ode(sys, uncertain_params)` returning an augmented
      `ModelingToolkit.System` with `N + K·N` unknowns and the
      corresponding forward-sensitivity equations (REQ-082). Directly
      consumable by `ODEProblem` / `solve` from `OrdinaryDiffEq.jl`.
- [x] Docs page **ODE Integration** (`docs/src/ode-integration.md`)
      with the RC-charge worked example, symbolic-snapshot and
      augmented-ODE paths, and a when-to-use-which comparison.
- [x] Eager stubs in `src/mtk_stubs.jl` raising `ArgumentError`
      pointing at `using ModelingToolkit` when the extension is not
      loaded (matches the M7 `latex` stub pattern).

**Exit criteria:** SC-003 — the RC-charge augmented integration
converges to `u(50τ) ≈ Vin` within `rtol = 1e-6` via `Tsit5()`;
all 23 new M9 test assertions green in `test/ext_modelingtoolkit/`;
docs build warning-free with the new page. ✅ Verified.

**Deferred (documented in spec Assumptions):**

- DAE support — M9 is ODE-only; DAE systems raise `ArgumentError`.
  An M9.x follow-up driven by user demand is the expected path.
- Time-varying uncertain parameters — JCGM 101:2008 Monte Carlo
  territory via `MonteCarloMeasurements.jl` + `StochasticDiffEq.jl`.
- Sensitivity-construction benchmark — documentation-only per the
  M7 precedent (benchmarks are flaky in CI).

---

## Milestone M10 — Stable-release preparation (v0.10.0) ✅

> EARS §17 testing, §18 documentation, §19 legal.

- [x] Full test-suite coverage per REQ-150 (all operators, math, multi-var,
      budget, expanded, Welch-Satterthwaite, codegen, LaTeX, substitution,
      ODE). ~500/500 green at M10 exit.
- [x] Six worked electrical examples (REQ-162): Ohm, voltage divider,
      RC time constant, dissipated power, RLC resonance, RC charge ODE —
      consolidated into `docs/src/worked-examples.md`.
- [x] Docs page **Limitations and Legal Notice** (REQ-173) expanded with
      non-warranty posture, waived-EARS list, no-reproduction audit,
      performance notes, post-1.0 candidates.
- [x] Docs page **Methodology Reference**
      (`docs/src/methodology-reference.md`) mapping every export to its
      JCGM 100:2008 section (REQ-161).
- [x] `README.md` `> [!WARNING]` admonition immediately after the
      package description (REQ-172).
- [x] CI-gated banned-terms smoke test (`test_banned_terms.jl`) —
      zero matches for `GUM-compliant`, `GUM-certified`, `accredited`
      (REQ-171).
- [x] `CITATION.bib` at repository root with `@software` + `@techreport`
      entries (REQ-177).
- [x] No-reproduction audit conclusion recorded in
      `docs/src/limitations.md` (REQ-176).
- [x] `PrecompileTools.@compile_workload` block in
      `src/SymbolicUncertainties.jl` covering arithmetic, math, propagate, and
      budget paths. First-call latency ~0.15 s on a warm-precompile run
      (target < 1 s).
- [x] Type-stability notes recorded in `docs/src/limitations.md`
      (documented, not CI-gated).
- [x] API freeze: CI-gated `test_api_freeze.jl` iterates EARS Appendix A
      (25 rows after R7 reconciliation), asserts every symbol exported,
      documented, and cites a JCGM / EA / Symbolics reference (REQ-160).

**Exit criteria:** Aqua.jl clean, Documenter build warning-free, all
EARS requirements traced to a passing test or an accepted waiver in
`docs/src/limitations.md`. ✅ Verified — see
`test/package/test_aqua.jl`, `docs/make.jl`, and the M10 audit tests.

---

## Pre-1.0 decisions — no milestone, no code

Two items from the pre-1.0 review that cost nothing to settle and get
more expensive the longer they wait.

- [x] **Licence split** — `LICENSE.md` is the unmodified OSI-approved
      **BSD 3-Clause** text, and the REQ-170 non-warranty clause lives
      in a separate file, so SPDX detection, GitHub's licence widget
      and General's AutoMerge all see a clean BSD-3-Clause package.
      Done. One deviation from the review, which asked for
      `DISCLAIMER.md`: the file is named `NOTICE.md`. Renaming is a
      one-line change if the review's name is preferred.
- [x] **Package name.** Renamed to `SymbolicUncertainties.jl` before
      registration, while it was still free.

---

## Milestone M11 — Linear form over tagged sources (v0.11.0) ✅

> Foundation refactor. Brief: `TODO.md`. New EARS series REQ-200 – REQ-208.
> **Breaking by design.** The package is still `0.x`, where SemVer allows a
> minor bump to break the API. No effort is spent preserving backward
> compatibility; ruptures are documented in `CHANGELOG.md` and the work
> moves on. This milestone is *not* the 1.0.0 release.

### Problem

`SymbolicMeasurement` carries `val`, `err`, `dof` but **not** the provenance
of the uncertainty. Three consequences, all present in the code today:

1. **Two propagation paths with different correctness properties.**
   `src/arithmetic.jl` applies the uncorrelated formula to the raw `.err`
   fields; `propagate(f, ms)` differentiates the full expression and is
   correct. The ergonomic path is the wrong one: `x - x` silently returns
   `0 ± σ√2` instead of `0 ± 0` (UB-002, `docs/src/limitations.md`
   § "Binary operators do not track operand identity").
2. **Correlation is an argument, not a property.** `propagate(f, ms, Σ)`
   requires the user to know *a priori* which inputs are correlated. The
   case that matters — two quantities correlated because they derive from a
   common upstream measurement — is exactly the one they cannot know.
3. **Sensitivity coefficients are recomputed everywhere.**
   `sensitivity_coefficient`, `uncertainty_contribution`,
   `relative_sensitivity`, `uncertainty_budget`, `check_linearity` and
   `propagate` all restart from `m.val` through `_safe_derivative`, and
   `uncertainty_budget` demands hand-supplied `variables` / `sigmas`
   vectors that the quantity should already know.

### Target invariant

> An uncertain quantity knows which independent measurements it derives
> from and with what sensitivity. Every combined uncertainty, sensitivity
> coefficient, budget and covariance is derived from that structure. There
> is exactly **one** propagation path.

### Design

```julia
struct SourceId
    id::UInt64
end

struct SymbolicMeasurement
    val::Symbolics.Num
    terms::Dict{SourceId, Symbolics.Num}   # ∂val/∂source, symbolic
end
```

**Phase 0 decided against a module-level registry.** The source
descriptors (`u`, optional degrees of freedom, display name) and the
declared covariances are **carried by the quantity**, in two further
fields, not held in global state. A registry broke
`Symbolics.substitute`: substituting `σx => 0.7` would have to reach
shared state, and without that `substitute(m, …).err` no longer yields
a number — violating REQ-120, REQ-123 and the M4 exit criterion.
Carrying `u` makes substitution purely local again (`val`, each
`terms[s]`, each `sources[s].u`). The only global left is an **atomic
`SourceId` counter**, so `±` is impure exactly as `gensym` is: bounded,
no leakage between tests, no session growth, and M10's
`@compile_workload` pollutes nothing. Quantities also become
serialisable and thread-safe. Binary operations merge their operands'
source and covariance contexts — conflict-free, since a given
`SourceId` can only come from one construction.
`declare_correlated(m1, m2, ρ)` **returns** new quantities rather than
mutating shared state: a correlation hypothesis is a property of the
measurement model, traceable and local, never action at a distance.
`V ± σV` mints **one** fresh source with sensitivity 1. Operators
combine linear forms by the chain rule:
`z.terms[s] = ∂f/∂x · x.terms[s] + ∂f/∂y · y.terms[s]`.

The combined variance is the quadratic form over the source covariance —
diagonal by default, which reproduces JCGM 100:2008 eq. (10); non-diagonal
for declared-correlated sources, which reproduces eq. (13). The two
existing formulas become two regimes of a single implementation. `err`
becomes a derived quantity rather than a stored field (kept as a computed
property only if Phase 0 shows that dropping it forces disproportionate
rewriting in `ext/` and `test/`; otherwise `combined_uncertainty(m)`
replaces it and callers migrate).

### This milestone is subtractive

It must end with a net **decrease** in propagation paths, public methods
and documented limitations. If the plan starts adding API surface, stop and
report. By M11 exit the following must have disappeared from the repository:

- [x] the three-argument `propagate(f, ms, Σ)` method;
- [x] `src/propagate_correlated.jl`;
- [x] the "Binary operators do not track operand identity" section of
      `docs/src/limitations.md` and the two workarounds it documents;
- [x] entry UB-002 in `upstream-bugs.md`;
- [x] the duplicated formulas in `src/arithmetic.jl` (they become chain-rule
      applications);
- [x] the mandatory `variables` / `sigmas` parameters of
      `uncertainty_budget`, which become an optional filter.

Two further breaks, decided in phase 0 and absent from the original
scope:

- [x] `expanded_uncertainty` **stops returning a
      `SymbolicMeasurement`**. Scaling every term by `k` would
      manufacture false sensitivities: `U = k·u_c` is not a
      propagatable quantity, and feeding it back into a computation
      would be silently wrong. A dedicated type carries
      `(val, U, k, ν_eff)` — the same decision as "`UncertaintyBudget`
      as the primary return type".
- [x] `relative_sensitivity` **rebases on sources** rather than
      variables. Under correlation `(cᵢσᵢ)²/u_c²` is no longer a
      decomposition: the cross terms are missing from the numerator,
      the sum no longer reaches 1 (REQ-152 falls), and a negative
      cross term can push a contribution past 100 %. The per-source
      contribution stays well defined in both regimes.

If the net diff *adds* propagation-logic lines, the refactor is missed.

### Requirements (EARS series 200, no collision with REQ-176)

- [x] **REQ-200** — When a quantity is built with `±`, the system shall
      assign it a unique independent-source identifier.
- [x] **REQ-201** — When an expression reuses the same source several
      times, the system shall combine the sensitivities before computing
      the variance.
- [x] **REQ-202** — When the user evaluates `x - x` or `x / x` through the
      binary operators, the system shall return a zero combined
      uncertainty.
- [x] **REQ-203** — When two quantities derive from a common source, the
      system shall propagate the induced covariance without a user-supplied
      matrix.
- [x] **REQ-204** — When all sources are independent, the system shall
      produce a result mathematically equivalent to JCGM 100:2008 eq. (10).
- [x] **REQ-205** — When sources are declared correlated, the system shall
      produce a result mathematically equivalent to eq. (13).
- [x] **REQ-206** — When the user requests an uncertainty budget, the
      system shall derive the rows from the quantity's source structure,
      without requiring variable or standard-uncertainty lists.
- [x] **REQ-207** — The system shall not expose more than one public
      uncertainty-propagation path.
- [x] **REQ-208** — When a source carries degrees of freedom, the system
      shall derive the Welch-Satterthwaite `ν_eff` from the per-source
      contributions.

### Phases

Every phase ends on a green repository: `Pkg.test()` passes, `docs/make.jl`
builds warning-free, `JuliaFormatter`, Aqua and JET are clean, with a
conventional commit and a `CHANGELOG.md` entry.

- [x] **Phase 0 — Reconnaissance (mandatory exit gate, no source edits).**
      Markdown report answering: which callers depend on `err` as a *stored*
      field (exhaustive, `ext/` and `test/` included); the coupling surface
      of the 228-line `ext/SymbolicUncertaintiesModelingToolkitExt.jl` (the most
      likely breaking point); how many of the 123 test files encode the
      *wrong* numeric value from the old path (e.g. `σ√2` for `x - x`) and
      must change their expectation, versus those that must stay identical;
      whether `relative_sensitivity`'s division by `m.err^2` remains defined
      under correlation and what it should become if not; a signed
      per-file line-delta estimate. **Stop and report before Phase 1.**
- [x] **Phase 1 — The type and carried sources.** New `src/source.jl`
      (`SourceId`, `Source`, atomic counter, context merge, returning
      `declare_correlated`) and rewritten `src/type.jl`; `err` becomes
      computed. New tests for REQ-200, REQ-201. `arithmetic.jl` is not
      migrated yet — the package stays green with the old behaviour,
      `x - x` included. The mechanism: the historical
      `SymbolicMeasurement(val, err, dof)` constructor mints **one
      opaque source** of standard uncertainty `err` and sensitivity 1,
      so all 21 existing construction sites keep working unchanged and
      computed `err` returns exactly the old value — with a mandatory
      short-circuit on the single-source, unit-sensitivity case, else
      `err` would return `sqrt(E^2)` instead of `E` and break symbolic
      comparisons. Phase 2 replaces those opaque sources with the real
      chain rule, and that is what flips `x - x` to `0 ± 0`.
- [x] **Phase 2 — Operators.** `src/arithmetic.jl`, `src/math.jl` and
      `src/apply.jl` migrated to the chain rule (REQ-202, REQ-204);
      `arithmetic.jl` holds no uncertainty formula at all any more.
      804/804 green. As phase 0 predicted, **no pre-existing test
      encoded the faulty value** — the single expectation change was
      to a phase-1 test of my own that documented the transitional
      behaviour.
- [x] **Phase 3 — Unifying `propagate`.** `propagate(f, ms)` is now a
      convenience over the operators; `propagate_correlated.jl`, the
      three-argument method and `test/correlated/` are deleted
      (REQ-203, REQ-205, REQ-207). `declare_correlated` returns new
      quantities rather than mutating shared state. REQ-031/REQ-032
      lapse with the removed method. 801/801 green.
- [x] **Phase 4 — Consumers.** `budget.jl`, `sensitivity.jl`,
      `dominant.jl` and `type.jl` read `terms` instead of
      re-differentiating (REQ-206, REQ-208); `expanded.jl` returns the
      new `ExpandedUncertainty`. `linearity.jl` is unchanged by design:
      it computes **second** derivatives, which the linear form does
      not contain — that is M13's subject. API goes to 26 exports.
      815/815 green.
- [x] **Phase 5 — Extensions.** All six were **already green**: the
      compatibility constructor and the computed `err` property
      absorbed the refactor without any extension changing. The real
      work was the simplification phase 0 spotted in MTK — its
      variance loop is replaced by `_chain`, since `sens_matrix[i,j]`
      already *is* ∂uᵢ/∂pⱼ. That is not cosmetic: ODE outputs now
      carry the correlation induced by a shared uncertain parameter,
      so a difference of two such states cancels the shared
      contribution instead of accumulating it.
- [x] **Phase 6 — Documentation and cleanup.** The 78-line "Binary
      operators do not track operand identity" section of
      `limitations.md` becomes a 17-line historical note; **UB-002 is
      deleted** from `upstream-bugs.md` (150 lines), leaving only the
      three genuine upstream Symbolics limitations;
      `sensitivity-analysis.md` no longer tells readers to prefer
      `propagate` for expressions reusing a measurement; the UB-002
      claims in `src/propagate.jl` are rewritten. Migration note in
      `CHANGELOG.md`.

### Scope additions from the pre-1.0 review

The review's "M1" block lands here rather than in a milestone of its
own, because all four items are properties of the core type and M11 is
the milestone that rewrites it. Doing them separately would mean
rewriting `SymbolicMeasurement` twice.

- [x] **JCGM 100:2008 Annex H validation suite (H.1 – H.4) plus
      JCGM 102:2011, as regression tests — written *first*.** This is
      the artefact ISO/IEC 17025 §6.4.7 asks a user to produce for
      software validation, and it dictates the design rather than
      documenting it after the fact. H.2 (simultaneous resistance,
      reactance and impedance from correlated inputs) is the one that
      forces correlation into the type. **All four ship**: H.1
      (end-gauge length, `test/annexh/test_h1_end_gauge.jl`), H.2
      (impedance, both regimes), H.3 (thermometer calibration, where
      the correlation comes from an adjustment rather than from
      shared inputs) and H.4 (radon massic activity, where a
      correlation between numerator and denominator of a ratio
      *reduces* `u_c` by a third and both of the Annex's own analysis
      paths must agree), plus `test/jcgm102/` for the output
      covariance. Note the API-freeze tension: the 25 exports were
      already published at v0.10.0, so "before the public API" now
      means "before 1.0" — which `0.x` still permits.
- [x] **Correlation in the core type from the outset** — the eq. (13)
      cross term, and the Jacobian form JCGM 102:2011 needs for
      vector-valued measurands. Already the substance of REQ-203 and
      REQ-205 above; the review confirms it must not be deferred.
- [x] **`UncertaintyBudget` as the primary return type**, not a bare
      `Vector{NamedTuple}` (REQ-209). It carries the three facts the
      rows could not: the measurand they decompose, the `u_c` they
      recombine into, and whether declared correlations are in play —
      the last because under equation (13) the cross terms belong to
      no row, so the percentage column stops summing to 1 and the
      rows alone cannot say so. It stays an `AbstractVector` of its
      rows, so every loop, index and renderer written against the M3
      shape is untouched, and the DataFrames extension becomes one
      rendering (`as = :dataframe`) rather than a second
      implementation. Extends REQ-044 and REQ-206.
- [x] ~~**`unit` metadata slot in the type, even if inert** at M11 — so
      that M12's dimensional checker has somewhere to read from
      without another type rewrite.~~ **Dropped, deliberately.** M12
      chose the opposite and better answer (REQ-211): units annotate
      the *symbols* of the model, supplied by the caller in a
      dictionary, exactly as `ModelingToolkit` does. A unit living in
      the quantity would have to survive every chain-rule step,
      substitution and simplification the linear form performs, and
      `check_units` needs none of that to do its work. No type rewrite
      was needed, so the slot would have been inert storage with a
      migration cost and no reader.

### Non-goals — explicitly frozen for M11

Not to be touched, extended or added during this milestone. If one seems
necessary to finish, that is the signal of a design problem — stop and
report: `FortranTarget` (UB-004); `MonteCarloMeasurements.jl` bridge;
second-order propagation; PDF certificate export; DAE support in the MTK
extension; mechanical / thermal / optical tutorial gallery; any new package
extension; any new exported function not listed above.

### Stop and ask

- If Phase 0 shows the MTK extension needs a major rewrite.
- If a REQ-2xx requirement conflicts with an existing requirement in
  `specification/ears.md`.
- If the work starts adding an unlisted public method.
- If an existing test appears to encode faulty behaviour but the verdict is
  uncertain.
- If the net delta of propagation-logic lines turns positive.

**Exit criteria:** `x - x` returns `0 ± 0` **through the binary
operators**, with no user awareness that a trap ever existed; the
uncorrelated and correlated regimes both fall out of the single quadratic
form (REQ-204 / REQ-205); `uncertainty_budget(m)` needs no `variables` /
`sigmas`; the removal list above is empty in the tree; test suite,
docs build, Aqua and JET green.

---

## Milestone M12 — Dimensional checking & size guards (v0.12.0) ✅

> Pre-1.0 review, "M2" block. Depends on M11 (the `terms` structure is
> what a budget row and a CSE pass both read).

### Dimensional checking on `DynamicQuantities.jl`

Replaces the M8 `Unitful` extension's construction-time
`DimensionError` with an **opt-in checker that returns a report, not an
exception**. Reuses the mechanism `ModelingToolkit` already applies to
its own systems (`src/systems/unit_check.jl`: `get_unit` +
`validate`), so a units-annotated MTK system and an
`SymbolicUncertainties` measurand are validated by the same rules.

- [x] `DynamicQuantities` weakdep + `ext/…DynamicQuantitiesExt.jl`,
      replacing `Unitful` as the dimensional backend (rationale — type
      stability, one `Quantity` type inside the `Symbolics` tree, and
      the fact that MTK's `screen_unit` accepts only
      `DQ.AbstractQuantity` — recorded in the entry this milestone
      supersedes).
- [x] Checking is **opt-in and non-throwing**: a validation call
      returns a report of dimensional findings. Construction never
      raises on a mismatch, so a user exploring a model is not blocked
      by a unit typo mid-derivation.
- [x] Three cases handled **explicitly**, each with its own tests and
      documented behaviour — they are the ones a naive dimension
      equality check gets wrong:
      1. **affine temperatures** (°C, °F): differences are dimensional,
         absolute values are not additive — an uncertainty in °C is a
         kelvin interval;
      2. **dimensionless ratios carrying a scale** (%, ppm, dB): all
         dimensionless, none interchangeable, and dB is logarithmic;
      3. **non-fungible homonyms**: quantities sharing a dimension but
         not a meaning (torque vs energy, both N·m; activity vs
         frequency, both s⁻¹) must not silently unify.

### Expanded uncertainty

- [x] Symbolic Welch-Satterthwaite was **already shipped** (M3,
      `welch_satterthwaite`, REQ-052; `ν_eff` symbolic). What remains
      was the coverage factor: `k` was a symbolic placeholder when
      `ν_eff` is symbolic (M3 REQ-051 used a Student-t table for
      numeric `ν_eff` only). **Done** — a Cornish-Fisher expansion in
      `1/ν` gives a genuine closed form, reproducing Table G.2 at
      p = 0.95: 2.2280 at ν = 10 (table 2.228), 2.0860 at ν = 20,
      2.0423 at ν = 30 (table 2.042), and the normal quantile in the
      limit. Asymptotic, so it degrades below ν ≈ 10 — where REQ-175
      already warns and JCGM 101:2008 is the right tool anyway.

### Guards against expression blow-up

The failure mode of a purely symbolic GUM library: `u_c²` expanded
over a dozen sources produces an expression that no CAS can simplify
and no user can read.

- [x] **Never flatten `u_c²` by default** — already true since M11:
      `_combined_uncertainty` builds `sqrt(Σ cᵢ²uᵢ²)` and never
      expands the square of the sum. Measured on a product of 3, 6, 9
      and 12 sources: 32, 116, 254, 446 nodes — **quadratic**, with
      constant second differences, not exponential. That growth is the
      structure of the problem (a product's sensitivity coefficient
      holds n−1 factors), not a pathology.
- [x] `Giac` as the simplification back-end — already routed through
      `_simplify_for_report` since M2.5.
- [x] **CSE at `build_function`** — enabled for the Julia target. The
      real cost was never expression size but redundancy: sensitivity
      coefficients share almost all of their structure, so without CSE
      the emitted code recomputes them once per source. `Symbolics`
      defaults `cse` to `false`. The C target has no such keyword; C
      compilers do their own CSE, so the loss is on emitted source
      size, not runtime.

**Exit criteria:** a 12-source measurand builds, reports its budget and
generates C without the `u_c²` expression being expanded; the three
awkward unit cases each have a passing test asserting the documented
behaviour; `expanded_uncertainty` returns a closed-form `k` for
symbolic `ν_eff`.

---

## Milestone M13 — Certified linearisation (v0.13.0) ✅

> Pre-1.0 review, "the differentiator". Depends on M11 (`terms`) and
> M12 (expression-size guards — a Hessian is where blow-up bites).

M6 ships a linearity *indicator* `η` and warns past `|η| > 0.1`
(REQ-180, REQ-181). That is a heuristic. M13 turns it into a
**bound**:

- [x] Emit the second-order term from the **symbolic Hessian**
      `∂²f/∂xᵢ∂xⱼ` — including mixed partials, which M6 explicitly
      deferred (diagonal only).
- [x] **Bound** that term by interval arithmetic or Taylor models over
      the input coverage intervals, rather than evaluating it at a
      point.
- [x] Report the bound alongside `u_c`, so the user gets a certified
      statement: *the first-order GUM result is valid to within this
      much over this input domain*.

The claim this makes possible: JCGM 101:2008 checks the linearisation
**statistically**, by sampling. A symbolic Hessian with a rigorous
bound checks it **deterministically**, over the whole coverage
region — and no tool in the ecosystem currently does this. It is the
strongest argument for a purely symbolic library existing at all: it
is something a Monte Carlo library structurally cannot do.

- [x] Remains **opt-in** and never silently corrects the result —
      REQ-182 (no silent higher-order correction) stays in force.

### Scope addition — JCGM 100:2008/Amd.1:2026

The 2026 amendment landed during M13 and belongs here: it is the same
Hessian, asked for on the other side of the result.

- [x] **`second_order_correction(f, measurements)`** — §4.1.4 NOTE 1
      requires, where the nonlinearity of `f` is significant, either a
      Monte Carlo method or higher-order terms in the expression for
      the **estimate** `y`. Equation (H.10) generalises the term to
      non-independent inputs, and that double sum
      `½ ΣᵢΣⱼ (∂²f/∂xᵢ∂xⱼ) u(xᵢ,xⱼ)` is what ships, reusing
      `covariance` off the diagonal. Distinct from
      `linearisation_bound`, which bounds the error the first-order
      law makes in `u_c`: a product of independent inputs has an exact
      estimate and an inexact combined uncertainty.
- [x] Returned, never applied — REQ-182 governs the estimate as much
      as the uncertainty. Where no closed-form second derivative
      exists the function raises and points at Monte Carlo, the other
      route the amendment allows.
- [x] Normative reference table refreshed: JCGM GUM-1:2023 supersedes
      JCGM 104:2009, GUM-5:2026 and GUM-6:2020 added, in
      `docs/src/index.md`, the REQ-176 audit and `CITATION.bib`.
      GUM-6:2020 prompted the scope statement now opening
      `docs/src/limitations.md` — building `Y = f(X)` is upstream of
      this package, and a term omitted from `f` contributes nothing to
      `u_c` however carefully `u_c` is computed.

**Exit criteria:** for `exp(x)` at `x = 1 ± 0.1`, the reported bound
contains the true first-order error and is tight enough to be
actionable; a linear model returns a zero bound; the bound is derived
symbolically, with no sampling anywhere in the path. ✅ Verified by
`test/certified/` and `test/secondorder/`.

---

## Milestone M14 — Monte Carlo cross-validation (v0.14.0) ✅

> Promoted from the post-1.0 list. It is the only item there that
> validates the package **from outside**: the Annex H suite checks the
> implementation against the GUM's own worked answers, but every one of
> those answers comes from the same first-order framework this package
> implements. A Monte Carlo propagation does not.

JCGM 101:2008 §8 is explicit that the point of a Monte Carlo method,
for a user of the GUM framework, is to **validate** that framework's
result where the linearisation is in doubt. §8.2 even supplies the
objective test: express `u_c` to a stated number of significant
digits, and check that the two results agree to within that
resolution. That test is this milestone's exit criterion, not a
subjective "close enough".

### What it is

- [x] `MonteCarloMeasurements.jl` as a **weak** dependency plus
      `ext/SymbolicUncertaintiesMonteCarloExt.jl`, the same pattern as
      the six existing extensions. `Symbolics.jl` stays the only
      mandatory dependency (REQ-130).
- [x] A conversion from a quantity's source structure to sampled
      inputs, and a comparison of the sampled combined uncertainty
      against the symbolic first-order one.

### The design decision this milestone turns on

**A standard uncertainty is not a distribution.** A `Source` carries
`u` and optionally `ν` — that is all the GUM framework needs, and it
is *not* enough to sample from. JCGM 101 requires a PDF per input:
§6.4.2 assigns a rectangular distribution to a Type B evaluation
stated as a half-width, §6.4.7 a normal one to a Type A evaluation, and
the choice changes the answer.

- [x] The distribution shall therefore be **supplied by the caller**,
      per source, and shall not be silently defaulted to normal.
      Defaulting would manufacture an assumption the user never made
      and would make the validation circular — a Monte Carlo run that
      assumes normality cannot detect that normality was the wrong
      assumption.
- [x] Rectangular, normal, triangular and Student-t cover the Type A
      and Type B evaluations of §6.4; anything else is the caller's
      own `Distributions.jl` object.

### Correlation

- [x] Declared covariances shall be honoured by sampling the sources
      jointly, through the Cholesky factor of the source covariance
      matrix. This is the part that can be got quietly wrong: sampling
      correlated sources independently would silently reproduce the
      uncorrelated answer, and the comparison would then "agree" for
      the wrong reason.
- [x] Where the declared covariance matrix is not positive
      semi-definite the system shall raise rather than sample — a
      correlation hypothesis that admits no joint distribution is a
      modelling error, and `ρ` values assigned pairwise by hand can
      easily produce one.

### Requirements

- [x] **REQ-230** — The system shall provide a Monte Carlo propagation
      of a `SymbolicMeasurement` behind a package extension, leaving
      `Symbolics.jl` the only mandatory dependency.
- [x] **REQ-231** — The system shall require the caller to state the
      distribution of each source and shall not default it.
- [x] **REQ-232** — When sources carry declared covariances, the
      system shall sample them jointly, and shall raise when the
      implied covariance matrix is not positive semi-definite.
- [x] **REQ-233** — The system shall report the comparison between the
      first-order and sampled results using the JCGM 101:2008 §8.2
      criterion — agreement to the stated number of significant digits
      of `u_c` — rather than an arbitrary tolerance.
- [x] **REQ-234** — The Monte Carlo path shall never alter the
      symbolic result. It is a check on the framework, not a
      correction to it (REQ-182 in the same spirit).

### Non-goals

Not a replacement for the symbolic path, and not a general Monte Carlo
uncertainty library — `MonteCarloMeasurements.jl` already is one. No
sampling of the *model* itself (JCGM 101 propagates distributions
through a fixed model; a model uncertainty is GUM-6:2020 territory and
upstream of this package).

**Exit criteria:** ✅ met, with one correction to their wording. §H.1
– §H.4 are all propagated both ways. §H.2 (three mutually correlated
inputs, a 3×3 covariance), §H.3 (correlation from a least-squares
adjustment, an exactly linear model) and §H.4 (correlation through a
ratio, which reduces `u_c`) agree. The JCGM 102 case is cross-checked
too, on the output side: the three §H.2 outputs are evaluated on one
draw and their sampled correlation matrix is compared against the
symbolic one (REQ-236). **§H.1 does not** — and that is a result, not a failure: its model multiplies two
inputs whose estimates are both zero, so the first-order law assigns
one of them no contribution, and the missing variance `ls·u(δα)·u(θ)`
appears in quadrature exactly. The GUM's own worked example does not
pass its own supplement's test. The deliberate disagreement is
`exp(x)` at `σ = 0.8`, where the sampled mean exceeds the first-order
estimate by `exp(σ²/2)` and both `linearisation_bound` and
`second_order_correction` predict it from the symbolic Hessian without
sampling anything.

---

## Post-1.0 candidates (unscheduled)

Status legend: `[ ]` planned · `[~]` in progress · `[x]` complete.

### Core-type / propagation

- [x] ~~Second-order (higher-moment) propagation behind an opt-in
      flag~~ — **scheduled as M13**, and sharpened: not just emitting
      the second-order term but *bounding* it, which is the part that
      certifies the linearisation.
- [x] ~~Richer `t`-distribution `k` computation~~ — **scheduled as
      M12** (expanded-uncertainty section).
- [x] ~~`Measurements.jl`-style linear-form-in-tagged-sources
      representation~~ — no longer a post-1.0 candidate: **scheduled as
      milestone M11 (v0.11.0)** above, where it becomes the single
      propagation path rather than an alternative to it. Drop this line
      entirely at M11 Phase 6.

### Ecosystem bridges

- [x] ~~**`DynamicQuantities.jl` as a dimensional backend**~~ —
      **scheduled as M12**, and the design changed: the checker is
      opt-in and reports rather than throwing, and `DynamicQuantities`
      *replaces* `Unitful` instead of sitting beside it. Rationale
      kept below for the record. Same M8 weakdep + extension pattern:
      `ext/SymbolicUncertaintiesDynamicQuantitiesExt.jl` overloading `±` on
      `DynamicQuantities.AbstractQuantity` with the same
      dimension-mismatch guard (REQ-100 – REQ-102). Three reasons this
      is worth more than a convenience alias:
      1. **Type stability.** `Unitful` encodes units in the *type*
         parameter, so every distinct unit combination is a distinct
         concrete type; `DynamicQuantities` keeps dimensions in a
         runtime field, so `Quantity{Float64, Dimensions}` is one type
         for V, A, Ω and W alike. That matters here because
         `uncertainty_budget` returns rows whose entries are
         deliberately heterogeneous in unit — with `Unitful` that
         vector cannot have a concrete element type. Directly relevant
         to the type-stability limitation recorded in
         `docs/src/limitations.md` at M10.
      2. **`Symbolics` interop.** `SymbolicUncertaintiesUnitfulExt` wraps
         the quantity in `Symbolics.Num`, so the unit type travels
         *inside* the symbolic expression tree and `SymbolicUtils`
         dispatches on it. A single quantity type keeps that tree
         uniform.
      3. **SciML / MTK coherence.** `ModelingToolkit` v11 supports
         both systems but only screens the `DynamicQuantities` path
         (`src/systems/unit_check.jl`: `screen_unit` accepts
         `DQ.AbstractQuantity` and rejects everything else;
         `Unitful.Unitlike` metadata is passed through unvalidated).
         Since M9 ships an MTK extension, matching the unit system MTK
         actually validates lets a units-annotated system flow into
         `propagate_ode` without a backend switch.
      Open questions before scheduling: whether `Unitful` stays
      supported (it has the larger unit database and affine units such
      as °C, which `DynamicQuantities` handles differently), and
      whether half-integer dimensions arising from the `sqrt` in the
      combined-uncertainty formula round-trip cleanly through
      `DQ.FixedRational`. **Explicitly out of scope for M11**, whose
      non-goals freeze any new package extension.
- [x] ~~Bridge to `MonteCarloMeasurements.jl` for validated
      cross-checks against JCGM 101:2008~~ — **scheduled as M14
      (v0.14.0)** above, where the validation criterion becomes
      JCGM 101 §8.2's rather than a subjective tolerance.
- [ ] Bridge to `StochasticDiffEq.jl` for time-varying uncertain
      parameters — out of M9 scope today (ODE-only).
- [ ] DAE support in `SymbolicUncertaintiesModelingToolkitExt` (M9.x
      follow-up, driven by user demand).
- [⛔] `FortranTarget` in `build_evaluator` — blocked on upstream
      `Symbolics.jl` (UB-004).

### Reporting & deliverables

- [ ] Certificate-quality PDF export pipeline from `uncertainty_budget`
      (Latexify → LaTeX → PDF via `tectonic` or equivalent).
- [ ] Machine-readable certificate export (JSON / YAML schema) for
      downstream LIMS ingestion.

### Tutorial gallery

All eight shipped as `docs/src/metrology-gallery.md`, in order of
increasing difficulty, each asserted end to end in `test/gallery/`.
Each was written for a conclusion the algebra makes visible and a
single number does not.


- [x] **Power & Resistance metrology walkthrough** (`docs/src/power-resistance-metrology.md`)
      — full VIM + GUM worked example on measuring `P = V·I` and
      `R = V/I` on a precision E96 resistor, including coverage-interval
      construction, conformity assessment (VIM §4.17), and
      calibration-certificate reporting (VIM §4.18).
- [x] Wheatstone-bridge resistance measurement with correlated ratio
      arms (demonstrates the correlated regime — post-M11 this means
      shared tagged sources, not a hand-built `Σ`).
- [x] Four-wire Kelvin resistance measurement for low-value resistors
      (removes lead-wire resistance contribution).
- [x] Thermocouple thermometry — `T = f(Vₜₕ)` polynomial with ITS-90
      reference-function coefficients and cold-junction compensation.
- [x] Pt100 / Pt1000 resistance-thermometer linearisation with the
      Callendar–van Dusen equation.
- [x] Optical-metrology example — laser-wavelength stabilised
      interferometer displacement measurement.
- [x] Mechanical metrology — torque transducer calibration (load-cell
      + lever arm, `M = F · L`) with lever-arm geometry uncertainty.
- [x] Pressure-transducer span + zero adjustment from two-point
      calibration with a reference standard.
- [x] Gauge R&R (repeatability & reproducibility) example crossing
      into ISO 5725 territory — boundary with JCGM 101:2008.

---

## Traceability

Every requirement `REQ-0xx` in `specification/ears.md` maps to exactly one
milestone above. When adding a requirement, update both the specification
and this roadmap in the same commit so traceability stays intact.

The `REQ-2xx` series starts at 200 to leave a gap above the last `REQ-1xx`
requirement, so the two numbering spaces cannot collide as
`specification/ears.md` grows. It is allocated by milestone:

| Range | Milestone | Subject |
|---|---|---|
| REQ-200 – REQ-208 | M11 | Independent sources and the linear form (`ears.md` §21) |
| REQ-210 – REQ-216 | M12 | Dimensional checking, closed-form `k`, size guards (§12) |
| REQ-220 – REQ-223 | M13 | Certified linearisation and the 2026 amendment (§20) |
| REQ-230 – REQ-237 | M14 | Monte Carlo cross-validation (REQ-235, the source-to-input link, shipped as its prerequisite; REQ-236 the vector-valued case of JCGM 102) |

A requirement a milestone supersedes is **kept and marked lapsed or
amended** in `ears.md`, never deleted: REQ-031/REQ-032 lapse with the
three-argument `propagate`, REQ-100 – REQ-102 lapse with the Unitful
extension, and REQ-042, REQ-044 and REQ-050 are amended by M11. A
deleted requirement leaves a citation in an old docstring pointing at
nothing.

### GUM audit notes (applied to `specification/ears.md` locally)

A systematic audit of `ears.md` against JCGM 100:2008 (French-English
edition, September 2008) was performed during M1. Seven corrections were
applied locally to `specification/ears.md` (which is git-ignored):

1. REQ-030 cited §5.2.2 for uncorrelated inputs — corrected to §5.1.2.
2. REQ-153 cited "GUM Example H.2" for the voltage divider — corrected
   (H.2 is resistance + reactance, not a voltage divider).
3. REQ-013 claimed a non-existent R = V/I example in §5.1 — removed.
4. REQ-010..REQ-014 tightened from §5.1 to §5.1.2 eq. (10) + §5.1.3.
5. REQ-005 citation moved from §4.3.1 to §4.1.5.
6. REQ-040..REQ-044 budget attributions corrected to §5.1.3 + EA-4/02.
7. REQ-003 transparency clause added re: `±` for `u_c` vs GUM §7.2.2.

## Future Integration: CausalGraphs.jl Bridge (Package Extension)

### Motivation
Currently, users of `SymbolicUncertainties.jl` must construct their measurement models purely through code (e.g., `L = L_s + d + L_s * alpha * Theta`). However, in industrial practice, these models are often conceived visually as **Ishikawa (Fishbone) diagrams** or causal trees.

By building a bridge to **`CausalGraphs.jl`** (via a weak dependency / Package Extension), we can allow `SymbolicUncertainties.jl` to automatically ingest qualitative causal graphs and convert them into executable GUM evaluations.

### Implementation Strategy (The "Consumer" Pattern)
To keep `CausalGraphs.jl` lightweight and agnostic, the intelligence of the bridge will reside here in `SymbolicUncertainties.jl`, specifically in a `SymbolicUncertaintiesCausalGraphsExt.jl` extension.

#### 1. Ingesting the Graph
We will implement an entry point such as:
```julia
# Triggered when both packages are loaded
function SymbolicUncertainties.parse_measurement_model(m::CausalGraphs.MeasurementModel)
    # ...
end
```
This function will read the structural nodes (`inputs` and `output`) defined in the `CausalGraphs.MeasurementModel`.

#### 2. Translation to Symbolic Variables
For each input node in the causal graph (e.g., a `CauseNode` or `IntermediateNode`), the extension will:
- Auto-generate the corresponding `@variables`.
- Extract numerical values and uncertainties if they are embedded in the node's `metadata` (e.g., `metadata[:value]`, `metadata[:uncertainty]`), turning them into `Measurement` structs (`x ± u`).

#### 3. Resolving the Mathematical Expression
Because an Ishikawa graph is qualitative ("X causes Y") but `SymbolicUncertainties` requires an algebraic form ("Y = X^2"), the bridge will offer two modes:
- **Scaffolding Mode (Generator):** Read the graph and emit a `.jl` script pre-filled with all variable definitions and `uncertainty_budget()` calls, leaving just a blank `Y = ...` line for the user to type the equation.
- **Full-Auto Mode:** If the `CausalGraphs.jl` nodes/edges hold an `[:expr]` metadata field (e.g., `:(L_s + d)`), the bridge uses `Meta.parse` and symbolic substitution to instantly compute the sensitivities and budget without any manual coding from the user.

#### 4. The Reverse Bridge (Equation ➔ Graph)
A killer feature for **Auditing and Quality Reporting (ISO 17025)**. Instead of drawing a graph to generate math, the user provides a mathematical expression and the system parses the `Symbolics.jl` AST to automatically generate the Ishikawa/Causal Graph.
- **Explainability:** Instantly visualize hierarchical sub-models (e.g., `Area = w * l` and `Volume = Area * h`).
- **Auto-Documentation:** Metrologists can generate perfectly accurate cause-effect graphs directly from legacy equations without manual drawing in PowerPoint or Visio.

### Impact
This positions `SymbolicUncertainties.jl` not just as a computational engine, but as the first holistic tool capable of transforming a qualitative brainstorming session (Ishikawa) directly into a strict ISO/BIPM-compliant uncertainty budget, and vice versa (auto-documenting code into visual graphs).
