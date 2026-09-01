```@raw html
---
layout: home

hero:
  name: SymbolicUncertainties.jl
  text: Purely symbolic propagation of measurement uncertainties
  tagline: Implementing the methodology of JCGM 100:2008 (GUM) on top of Symbolics.jl
  image:
    src: /assets/logo.png
    alt: SymbolicUncertainties.jl Logo
  actions:
    - theme: brand
      text: Getting Started
      link: /getting-started/
    - theme: alt
      text: View on GitHub
      link: https://github.com/s-celles/SymbolicUncertainties.jl

features:
  - icon: 📐
    title: JCGM 100:2008 Methodology
    details: Complete linear uncertainty propagation, sensitivity analysis, and uncertainty budgets.
  - icon: 🧮
    title: Built on Symbolics.jl
    details: Purely symbolic derivation of gradients and covariances with fast Julia function generation.
---
```
!!! warning "Regulated-use disclaimer"
    This package is intended for **research and educational purposes**.
    It implements the mathematical methodology of JCGM 100:2008 but
    has **not** been independently validated as calibration software
    for accreditation use. Use in regulated, safety-critical, or
    ISO/IEC 17025-accreditation contexts requires independent
    software validation per ISO/IEC 17025 §6.4.7. See the
    [Limitations](limitations.md) page and
    [`LICENSE.md`](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/LICENSE.md)
    for the full non-warranty clause.

## Status

The last tagged release is **v0.10.0**. Its public API is
**25 exports**: symbolic uncertainty
propagation (`propagate`, `propagate_vector`, `±`), sensitivity
analysis (`sensitivity_coefficient`, `uncertainty_contribution`,
`relative_sensitivity`), uncertainty budgets (`uncertainty_budget`,
`expanded_uncertainty`, `welch_satterthwaite`, `dominant_source`),
precision inference (`infer_precision`, `infer_all_precisions`,
`required_precision`, `budget_allocation`), a linearity diagnostic
(`check_linearity`), code generation (`build_evaluator`, `to_expr`,
`latex`, `JuliaTarget`, `CTarget`), and `ModelingToolkit.jl`
integration (`propagate_ode`, `uncertainty_ode`).

Start with [Getting Started](getting-started.md); the
[Methodology Reference](methodology-reference.md) maps every export
to its JCGM 100:2008 section.

Substantial work has landed on `main` since that release and is
**not yet tagged**. A quantity now carries the independent sources
it derives from, so `x - x` returns `0 ± 0` through the binary
operators and correlation is a property of the sources rather than a
covariance matrix the caller has to build. There is an opt-in,
non-throwing dimensional checker; a certified bound on the GUM
linearisation; and the second-order term on the estimate that
JCGM 100:2008/Amd.1:2026 asks for. The migration notes are in
[`CHANGELOG.md`](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/CHANGELOG.md);
the plan is in
[`ROADMAP.md`](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/ROADMAP.md).

## Contributor quickstart

```julia
using Pkg
Pkg.activate(".")
Pkg.instantiate()
Pkg.test()
```

Requires **Julia ≥ 1.10 (LTS)**.

## Normative references

| Standard | Scope |
|----------|-------|
| **JCGM 100:2008** (GUM) | Linear uncertainty propagation, uncertainty budget |
| **JCGM 100:2008/Amd.1:2026** | Nonlinearity in measurement models — the second-order term on the *estimate*, implemented by [`second_order_correction`](@ref) |
| **JCGM 101:2008** (GUM S1) | Monte Carlo propagation — out of scope (see `MonteCarloMeasurements.jl`) |
| **JCGM 102:2011** (GUM S2) | Multiple output quantities — see [`covariance`](@ref) |
| **JCGM GUM-1:2023** (Part 1) | Introduction and terminology. Supersedes JCGM 104:2009; adopted as ISO/IEC Guide 98-1:2024 |
| **JCGM GUM-5:2026** (Part 5) | Worked examples across disciplines, comparing the GUM framework, Monte Carlo and Bayesian treatments |
| **JCGM GUM-6:2020** (Part 6) | Developing and using measurement models — **upstream of this package**, which takes `Y = f(X)` as given |
| **IEC 60359** | Electrical instrument performance |
| **IEC 61298-3** | Process measurement uncertainty |
| **EA-4/02** | Calibration uncertainty expression |
