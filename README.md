# SymbolicUncertainties.jl

A Julia package for **purely symbolic** propagation of measurement
uncertainties, implementing the methodology of **JCGM 100:2008** (GUM —
Guide to the Expression of Uncertainty in Measurement) and its
supplements, built on `Symbolics.jl`.

Rather than computing a numerical result, `SymbolicUncertainties.jl`
produces closed-form symbolic expressions for both the central value
and the propagated uncertainty of any differentiable function of
symbolic quantities. This enables analytical sensitivity analysis
(GUM §5.1.6), measurement protocol optimisation, code generation
(LaTeX, C, Fortran), and integration with differential equation
systems via `ModelingToolkit.jl`.

[![CI](https://github.com/s-celles/SymbolicUncertainties.jl/actions/workflows/CI.yml/badge.svg)](https://github.com/s-celles/SymbolicUncertainties.jl/actions/workflows/CI.yml)
[![Documentation](https://github.com/s-celles/SymbolicUncertainties.jl/actions/workflows/Documentation.yml/badge.svg)](https://s-celles.github.io/SymbolicUncertainties.jl/)
[![codecov](https://codecov.io/gh/s-celles/SymbolicUncertainties.jl/branch/main/graph/badge.svg)](https://codecov.io/gh/s-celles/SymbolicUncertainties.jl)
[![License: BSD-3-Clause](https://img.shields.io/badge/License-BSD_3--Clause-blue.svg)](LICENSE.md)

> [!WARNING]
> **Regulated-use disclaimer** — `SymbolicUncertainties.jl` is distributed
> **without any warranty**, not even the implied warranty of
> merchantability or fitness for a particular purpose. The package
> paraphrases the methodology of JCGM 100:2008 in software; it is
> **not** GUM-conformant in an accreditation sense. Use in
> regulated, safety-critical, or ISO/IEC 17025 contexts requires
> independent software validation per ISO/IEC 17025 §6.4.7. See
> [`NOTICE.md`](NOTICE.md) and
> [`docs/src/limitations.md`](docs/src/limitations.md) for the full
> legal posture, waived requirements, and citation instructions.

## Status

**Last release v0.10.0 (Milestone M10, pre-1.0); `main` carries
M11 – M13, unreleased.** The stabilised M10 surface is symbolic
uncertainty propagation (`propagate`, `propagate_vector`, `±`),
sensitivity analysis (`sensitivity_coefficient`,
`uncertainty_contribution`, `relative_sensitivity`), uncertainty
budgets (`uncertainty_budget`, `expanded_uncertainty`,
`welch_satterthwaite`, `dominant_source`), precision inference
(`infer_precision`, `infer_all_precisions`, `required_precision`,
`budget_allocation`), a linearity diagnostic (`check_linearity`),
code generation (`build_evaluator`, `to_expr`, `latex`,
`JuliaTarget`, `CTarget`), and `ModelingToolkit.jl` integration
(`propagate_ode`, `uncertainty_ode`).

Since then, on `main` and **not yet released**: M11 gave a quantity
the independent sources it derives from, so `x - x` is `0 ± 0`
through the plain operators and correlation is a property of the
sources (`declare_correlated`, `covariance`, `correlation`) rather
than a covariance matrix the caller must build; M12 added an opt-in,
non-throwing dimensional checker (`check_units`); M13 added a
certified bound on the linearisation (`linearisation_bound`) and the
second-order term on the estimate that JCGM 100:2008/Amd.1:2026
asks for (`second_order_correction`). `CHANGELOG.md` has the
migration notes. See
[`docs/src/methodology-reference.md`](https://s-celles.github.io/SymbolicUncertainties.jl/dev/methodology-reference/)
for the full API-to-GUM-section mapping and
[`ROADMAP.md`](ROADMAP.md) for what's planned post-1.0.

## Installation

Once registered in the Julia General registry:

```julia
using Pkg
Pkg.add("SymbolicUncertainties")
```

Until then, install directly from this repository:

```julia
using Pkg
Pkg.add(url = "https://github.com/s-celles/SymbolicUncertainties.jl")
```

## Quickstart (contributors)

```bash
git clone https://github.com/s-celles/SymbolicUncertainties.jl.git
cd SymbolicUncertainties.jl
julia --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path = pwd())); Pkg.instantiate(); include("docs/make.jl")'
```

Requires **Julia ≥ 1.10 (LTS)**. See
[`CONTRIBUTING.md`](CONTRIBUTING.md) for the full contributor
onboarding procedure.

## References

- **JCGM 100:2008** — GUM: Guide to the Expression of Uncertainty in Measurement
- **JCGM 102:2011** — GUM Supplement 2: multiple output quantities
- **IEC 60359**, **IEC 61298-3**, **EA-4/02**

## How to cite

If this package contributes to work you publish, please cite it. The
licence cannot require this — no OSI-approved licence can impose
academic citation — but it is how scientific software stays funded and
maintained. GitHub's *Cite this repository* button reads
[`CITATION.cff`](CITATION.cff); a BibTeX entry is in
[`CITATION.bib`](CITATION.bib).

## Licence

BSD 3-Clause Licence — see [`LICENSE.md`](LICENSE.md) — with an additional
non-warranty notice, see [`NOTICE.md`](NOTICE.md).
