# Limitations and Legal Notice

!!! warning "Not a substitute for independently validated metrology software"
    `SymbolicUncertainties.jl` implements the mathematical methodology of
    **JCGM 100:2008** (GUM). It is intended for research and
    educational use only and has not been independently validated
    for regulated or accreditation contexts.

This page consolidates the scope boundaries, waived
requirements, performance expectations, and legal
posture of `SymbolicUncertainties.jl` v0.10.0 (REQ-173).

## Non-warranty posture (REQ-170 / REQ-172)

`SymbolicUncertainties.jl` is distributed **without any
warranty** — not even the implied warranty of
merchantability or fitness for a particular purpose. The
package **paraphrases** the methodology of JCGM 100:2008
in software; it does not reproduce the normative text,
tables, or figures of that document, nor of any IEC or
EA publication. Users in regulated contexts (legal
metrology, ISO/IEC 17025 calibration laboratories,
clinical measurement, safety-critical instrumentation)
**MUST** independently verify every computed result
against their accreditation body's requirements.
Prohibited wording (per REQ-171) is absent from the
source tree and checked on every CI run by
`test/package/test_banned_terms.jl`. The verbatim clause
required by REQ-170 lives in
[`NOTICE.md`](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/NOTICE.md)
at the repository root, kept separate from
[`LICENSE.md`](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/LICENSE.md)
so the licence text itself stays the unmodified,
OSI-approved BSD 3-Clause Licence.

## The measurement model is an input, not an output

This package propagates uncertainty through a model `Y = f(X₁,…,Xₙ)`
that **you supply**. Building that model — deciding which influence
quantities matter, how they enter, and what has been left out — is the
subject of JCGM GUM-6:2020, and it is upstream of everything here.

That boundary is worth stating plainly, because the largest
uncertainties in practice usually come from the model rather than from
the propagation: a term omitted from `f` contributes nothing to `u_c`
no matter how carefully `u_c` is computed. A dimensionally consistent,
exactly propagated result can still be wrong for a reason this package
cannot see.

## Nonlinearity and the 2026 amendment

JCGM 100:2008/Amd.1:2026 requires that, where the nonlinearity of `f`
is significant, either a Monte Carlo method be used or higher-order
terms be included in the estimate of `y`. The package implements the
second-order term of §4.1.4 NOTE 1 and its correlated generalisation
(H.10) as [`second_order_correction`](@ref).

It is **returned, never applied**: `val` remains the first-order
estimate `f(x̄)` until you add the correction yourself. That is
deliberate — REQ-182 forbids silent higher-order corrections, and the
amendment asks for the term to be included knowingly.

Note that this concerns the **estimate**. The error the first-order
law makes in `u_c` is a different question, answered by
[`linearisation_bound`](@ref). A model can need one and not the other:
a product of independent inputs has an exact estimate and an
inexact combined uncertainty.

## No-reproduction audit (REQ-176)

The release audit confirms that **no
normative text, table, or figure from JCGM 100:2008 and
its Amendment 1:2026, JCGM 101:2008, JCGM 102:2011,
JCGM GUM-1:2023, JCGM GUM-5:2026, JCGM GUM-6:2020,
IEC 60359, IEC 61010, IEC 61298-3, or EA-4/02 is
reproduced** in
the source tree. Section numbers are *cited* in
docstrings to indicate the method each function realises;
the methodology itself is paraphrased, not copied.
Citations live in `CITATION.bib` at the repository
root.

## Waived EARS requirements

The following requirements from `specification/ears.md`
are explicitly **deferred** past v0.10.0, with rationale
below. Each waiver is tracked in `upstream-bugs.md` or
the ROADMAP post-1.0 candidate list.

| Waiver | Rationale | Tracking |
|--------|-----------|----------|
| **Second-order corrections** | Out of scope — constitution III: purely symbolic first-order GUM. Second-order / mixed partials are a v2.0 opt-in. | ROADMAP post-1.0 "Second-order propagation behind an explicit opt-in flag" |
| **`FortranTarget` code generation** | Blocked by upstream — `Symbolics.jl` 7.x does not export `FortranTarget`. C-target is the only non-Julia target at v0.10.0. | `upstream-bugs.md` UB-004 |
| **`assume_positive!` / `assume_nonzero!`** | Blocked by upstream — `Symbolics.jl` lacks a first-class assumptions API. The package takes a conservative over-warning stance (REQ-140 / REQ-141). | `upstream-bugs.md` UB-003 |
| **Monte Carlo propagation (JCGM 101:2008)** | Out of scope — constitution III delegates to `MonteCarloMeasurements.jl`. A v1.x bridge is a candidate. | ROADMAP post-1.0 "Bridge to MonteCarloMeasurements.jl" |
| **DAE support** | Scope constraint — the ModelingToolkit extension targets ODEs only; DAE systems raise `ArgumentError`. Driven by user demand. | `ROADMAP.md`, post-1.0 candidates |
| **Time-varying uncertain parameters** | JCGM 101:2008 territory; stochastic forcing belongs to `StochasticDiffEq.jl` + `MonteCarloMeasurements.jl`. | `ROADMAP.md`, post-1.0 candidates |
| **CI-gated benchmarks** | Wall-clock measurements are flaky on shared CI runners — benchmarks documented only. | `ROADMAP.md` |

## Performance notes

### First-call latency (SC-001)

With v0.10.0's `PrecompileTools.@compile_workload` block,
the canonical arithmetic first call should complete in
**under 1 second** on a standard developer laptop:

```@example limitations
using SymbolicUncertainties
using Symbolics
@variables V I σV σI

@time (V ± σV) / (I ± σI)
# elapsed: ~0.1–0.5 s on a warm-precompile run
```

This target is **documented, not CI-gated** — shared
CI runners under neighbour load routinely exceed 1
second on cold startup, and a flaky gate would teach
contributors to ignore failures. The precompile
workload covers four call paths (arithmetic, math
functions, `propagate`, `uncertainty_budget`) — roughly
95% of common user sessions. The remaining paths —
substitution, inverse inference, linearity diagnostics,
code generation, the package extensions and the ODE
integration — are intentionally **not** in the
precompile workload, to keep package load time bounded.

### Type stability

A `@code_warntype` audit of the hot paths
(`SymbolicMeasurement` arithmetic, `propagate`,
`uncertainty_budget`) at v0.10.0 shows no `Any` or
`Union` returns on the canonical call shapes. Extension
paths (MTK, Latexify, DataFrames) inherit the upstream
packages' type-stability posture.

### Skipping precompilation

Users who want to skip the precompile workload (e.g. on
CI layers that precompile once per PR) can set
`JULIA_PKG_PRECOMPILE_AUTO=0` before `using
SymbolicUncertainties`. First-call latency will regress to
pre-v0.10.0 levels, but functionality is unaffected.

## Three things to know when reading a budget

**Repeating `±` declares a new source.** Identity comes from the
measurement object, not from the symbol name, so writing `R ± σR`
twice in one model declares two independent inputs sharing a
tolerance symbol. The budget then shows one row too many and `u_c`
double-counts that input. Bind each physical input to a variable once
and reuse it — see
[Uncertainty Sources](uncertainty-sources.md) for the worked
contrast. No warning is emitted, because two sources sharing a
standard uncertainty is also what two nominally identical instruments
look like, and the two cases are not distinguishable from the
expressions alone.

**A combined sensitivity comes out with its denominator expanded.**
Where an input appears more than once in the model, its sensitivity
coefficient is the sum of several contributions, and simplifying that
sum expands the denominator: a voltage divider reports
`R1·Vin/(R1² + 2R1R2 + R2²)` where `R1·Vin/(R1+R2)²` reads better.
The value is exact; only the form suffers. Neither `Symbolics.simplify`
nor `simplify_fractions` recovers the factored form, and the `Giac`
backend expands it too, so there is nothing to switch on — it is
recorded here rather than worked around.

**A sensitivity may be reported unsimplified.** Simplification here
is a presentation step, and it is not allowed to remove a source or to
abort a computation. Three defects in the default simplifier make that
rule necessary, all reached by ordinary metrological input:

| upstream issue | what it does |
|---|---|
| [SymbolicUtils#1050](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1050) | returns a **numerically wrong** result — `1e-9(3.0 + 5.0x)/sqrt(1 + x)` becomes `5.0e-9sqrt(1 + x)`, a different function |
| [SymbolicUtils#1051](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1051) | **throws** `OverflowError` on `Rational` coefficients with a large denominator |
| [SymbolicUtils#1044](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1044) | **throws** `BoundsError` on an even power of a negated symbol |

The first is the dangerous one. On a sensitivity in the thermocouple
model of the [Metrology Gallery](metrology-gallery.md) the wrong result
was exactly `0`, which deleted the cold-junction source and understated
`u_c` with no diagnostic. The other two are reached through a plain
property access: a degrees-of-freedom count of `1e12`, the idiomatic
"effectively infinite" ν of JCGM 100:2008 §G.4.2, makes `m.dof` throw.

Two guards follow, and they are why this package is correct on its own:

- A simplified zero is re-checked numerically against the unsimplified
  sensitivity before any term is dropped, and where the two disagree
  the unsimplified form is kept. A term that cannot be evaluated at all
  is likewise kept: reporting a source that really cancels costs a
  `0·u` row, whereas dropping one that does not understates the
  combined uncertainty, and only one of those is a metrological error.
- Simplification never propagates an exception. On failure the
  unsimplified expression is returned.

The visible cost is that some sensitivity coefficients print in a
longer form than necessary. If that matters to you, loading `Giac.jl`
removes the cause rather than the symptom — see
[Optional CAS-grade simplification](sensitivity-analysis.md#Optional-CAS-grade-simplification-via-Giac.jl),
which records what Giac returns on each of the three cases above.
These entries are also tracked in `upstream-bugs.md` as UB-007,
UB-008 and UB-006.

## Post-1.0 candidates

See [ROADMAP.md](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/ROADMAP.md)
"Post-1.0 candidates (unscheduled)" for the full list.
Highlights:

- Bridge to `MonteCarloMeasurements.jl` for JCGM
  101:2008 Monte Carlo cross-checks.
- Certificate-quality PDF export from
  `uncertainty_budget`.
- Machine-readable certificate export (JSON / YAML) for
  downstream LIMS ingestion.
- Mechanical / thermal / optical tutorial gallery beyond
  the six canonical electrical examples.
- DAE support in the ModelingToolkit extension.
- ~~`Measurements.jl`-style linear-form-in-tagged-sources
  representation~~ — **shipped**, replacing the
  binary-operator path rather than supplementing it.
- ~~Second-order propagation behind an opt-in flag~~ —
  **shipped**: [`linearisation_bound`](@ref) bounds the
  error the first-order law makes in `u_c`, and
  [`second_order_correction`](@ref) returns the term
  JCGM 100:2008/Amd.1:2026 §4.1.4 NOTE 1 asks for on the
  estimate. Both are opt-in and neither is applied
  silently (REQ-182).
- ~~Richer Student-t `k` computation for symbolic
  `ν_eff`~~ — **shipped**: a Cornish-Fisher
  expansion in `1/ν` replaces the normal-quantile
  fallback, reproducing Table G.2 at p = 0.95 down to
  ν ≈ 10.

---

## Further limitations
## Linearity assumption (GUM §5.1.1)

The GUM framework assumes the measurement model function is
approximately linear in the vicinity of the input estimates. When the
model is strongly nonlinear, the first-order Taylor expansion that
drives the combined standard uncertainty formula becomes inadequate,
and higher-order terms or Monte Carlo propagation (JCGM 101:2008)
should be considered. Use
[`check_linearity`](linearity-check.md) to obtain per-variable
nonlinearity indicators and a runtime `@warn` when the GUM §5.1.1
threshold `|η| > 0.1` is exceeded.

## Normality assumption for coverage factor k = 2 (GUM §6.3.3)

The common choice `U = 2 · u_c(y)` for 95 % coverage assumes the output
distribution is approximately normal. When this assumption is violated
— small effective degrees of freedom, heavy-tailed input distributions,
strongly asymmetric models — a different coverage factor must be used.
The `welch_satterthwaite` helper (forthcoming) and the
`expanded_uncertainty` API (forthcoming) will document this explicitly.

## Effective degrees of freedom ν\_eff ≥ 30

Below `ν_eff = 30`, the choice `k = 2` is inadequate and the
Welch-Satterthwaite formula should be used to select an appropriate
coverage factor from the Student-t distribution. See the
[Expanded Uncertainty](expanded-uncertainty.md) page for the
`expanded_uncertainty(m; coverage_probability = …)` keyword form
that derives `k` from `m.dof` via the GUM Table G.2 quantile
lookup, and for `welch_satterthwaite(contributions, dofs)` that
computes the effective degrees of freedom itself. A numeric
`ν_eff < 30` triggers a runtime `@warn` per **REQ-175**.

## Over-warning on division-by-zero and `sqrt` / `log` domain

The safety warnings (REQ-140, REQ-141) fire whenever the
relevant `.val` field is not a concrete numeric `Real`. This
deliberately errs on the side of over-warning — users who
*know* a symbolic variable is positive (`σ > 0`) or nonzero
still receive the warning, because `Symbolics.jl` provides no
upstream assumptions framework (`assume` / `additionally`)
through which a library could query "is this expression
provably positive?". See
[`upstream-bugs.md` UB-003](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/upstream-bugs.md)
for the ecosystem-level gap and the deferred in-library
`assume_positive!` workaround. Three silencing options are
documented on the
[Display, Substitution, and Safety](display-substitute-safety.md)
page.

## Independent software validation for ISO/IEC 17025

Use in an ISO/IEC 17025-accreditation calibration laboratory or
regulated industry context requires independent software validation
per **ISO/IEC 17025 §6.4.7**. `SymbolicUncertainties.jl` does not provide
such validation and must not be relied upon as the sole uncertainty-
evaluation tool in those contexts.

## Copyright status of referenced standards

No normative text from JCGM, IEC, or EA publications is reproduced in
the package. References to section numbers in this documentation and
in docstrings are provided for traceability only; obtaining the full
text of the referenced standards is the user's responsibility.
