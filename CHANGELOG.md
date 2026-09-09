# Changelog

All notable changes to **SymbolicUncertainties.jl** are documented in this
file. The format is based on [Keep a Changelog
v1.1.0](https://keepachangelog.com/en/1.1.0/), and this project adheres
to [Semantic Versioning 2.0.0](https://semver.org/).

## [Unreleased]
n### Added
- **CausalGraphs.jl Integration**: `SymbolicUncertaintiesCausalGraphsExt` weak dependency extension providing `parse_measurement_model` (Scaffolding Mode) and `evaluate_measurement_model` (Full-Auto Mode) for generating uncertainty budgets directly from causal graphs/Ishikawa diagrams.

### Fixed — the budget no longer lists sources that carry no uncertainty

Every constant operand is wrapped as a measurement with `u = 0`, so a
model written with literal coefficients accumulates such sources. They
were already excluded from the variance, but `uncertainty_budget` still
emitted a row for each: zero contribution, zero variance fraction, and
one line of noise per constant in the model. A polynomial in one input
produced more rows for its coefficients than for its input.

- `uncertainty_budget` drops any source whose standard uncertainty is
  zero. The variance decomposition is unchanged, since the dropped rows
  carried none of it, and the reported fractions still sum to one.

### Changed — the upstream simplifier defects are documented, with a remedy

The three defects in `Symbolics.simplify` that this package guards
against are now named in the documentation, with links to the upstream
issues, and `Giac.jl` is presented as the way to remove their cause
rather than only their symptom.

- [Limitations](https://s-celles.github.io/SymbolicUncertainties.jl/dev/limitations/)
  tabulates SymbolicUtils
  [#1050](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1050)
  (wrong result),
  [#1051](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1051)
  (`OverflowError`) and
  [#1044](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1044)
  (`BoundsError`), says what each one does to a budget, and points at
  the guards that make the package correct without any extension.
- [Sensitivity Analysis](https://s-celles.github.io/SymbolicUncertainties.jl/dev/sensitivity-analysis/)
  records what Giac returns on each of the three, and states three
  caveats against treating it as a safety net: it is optional, its own
  failure is silent (UB-005), and its round trip moves float
  coefficients in the fifteenth digit.
- The claim that the Giac override is "strictly additive" is corrected:
  it also avoids defects that make the default path return a wrong
  answer or throw.

### Added — `report`, the textual forms JCGM 100:2008 §7.2 prescribes (REQ-239)

Since M1 the documentation has told users that the package's `±`
display is **not** what a calibration certificate may say, and to "use
one of the four §7.2.2 textual forms instead" — without giving them any
way to produce one. This closes that.

- **`report(y, u; symbol, unit, digits, k, coverage_probability, dof)`**
  returns an `UncertaintyReport` carrying all four §7.2.2 renderings.
  The tests use the GUM's own worked example, the 100 g mass standard
  `m_S = 100.02147 g` with `u_c = 0.35 mg`, so a formatting drift fails
  against the standard's own text rather than against my reading of it.
- **§7.2.6 rounding is the substance of it.** `u_c` is quoted to two
  significant digits and the estimate is rounded to that same last
  place — `report(1234.5678, 12.0)` reports `y = (1235 ± 12) m`, not
  `1234.5678`. More digits than the uncertainty supports claims a
  precision the measurement does not have. Trailing zeros are
  significant, so the rendering goes through `Printf` rather than
  `string(round(...))`, which drops them.
- **The §7.2.4 expanded statement is separate and names its basis.**
  Supplying `k` produces it, with the coverage probability and degrees
  of freedom written into the sentence. Without `k` there is none:
  `± U` with no stated coverage factor is exactly the ambiguity §7.2.2
  warns about.
- **`report(m, values)`**, with `DynamicQuantities` loaded, derives the
  numbers and the unit from the model through the same walk as
  `evaluate`, and names it: see the entry below.
- `Printf` (stdlib) becomes a dependency; new page,
  [Reporting a Result](https://s-celles.github.io/SymbolicUncertainties.jl/dev/reporting/).

### Added — a calibration certificate in the shape ISO/IEC 17025 §7.8 requires (REQ-241)

`report` renders a result; a certificate is the document that result
travels in, and §7.8 is prescriptive about what it must carry.
`certificate(...)` builds one, `show` renders it as text, and
`latex(cert)` produces a complete compilable document.

**Every rendering carries a specimen watermark, and it cannot be
switched off** — only reworded. This package is not an accredited
laboratory, so a document it emits is a draft whatever the caller
intends. In LaTeX the watermark goes across the diagonal of every
shipped page via `eso-pic`, is repeated in the running header, boxed at
the top, and repeated at the foot.

- **Unmet clauses are printed on the document**, not returned by a
  separate checker. A certificate missing its traceability statement is
  defective, and the failure mode of a checker is that nobody calls it.
  Rendering the gaps in place turns the type into a working checklist
  against §7.8.2.1 b), c), e), f), g), h), i), j), o); §7.8.4.1 b), c),
  d); §7.8.6.2 c); and §7.8.4.3.
- **§7.8.6.2 c)** — a statement of conformity must name its decision
  rule, which is what makes a pass/fail statement interpretable at all
  (ILAC-G8). `ConformityStatement` without one produces a finding.
- **§7.8.4.3** — a certificate shall not recommend a calibration
  interval unless that was agreed with the customer. Stating one
  without `interval_agreed = true` produces a finding.
- **§7.8.2.1 d)** — every LaTeX page carries the certificate number and
  `Page n of m`, and the document ends with an explicit *End of
  certificate*.

**The compile check earned its place immediately.** Every string
assertion passed while `pdflatex` refused the document outright: it
rejects `Ω` even under `utf8` input encoding, and metrology writes `Ω`,
`µ`, `°C` and unit exponents like `A⁻¹` constantly. Those characters
are now mapped to LaTeX commands, and the test suite compiles a
document containing all of them whenever a TeX engine is available. A
certificate that does not compile is worse than one that does not
exist, because the failure surfaces at the worst possible moment.

### Added — a derived unit is reported by its conventional name (REQ-240)

The dimensional walk composes what it is given, so a resistance came
out of `report` as `A⁻¹ V` and a power as `A V`. Both are correct, and
neither is what a calibration certificate writes.

- `report` now recognises the thirteen coherent derived SI units — Hz,
  N, Pa, J, W, C, V, F, Ω, S, Wb, T, H — by their dimension, and writes
  the conventional name. The thirteen dimensions are distinct from one
  another, so the lookup is unambiguous as a dimension.
- **A prefixed unit is never renamed.** `1 kΩ` expands to a thousand
  base units, so a result computed in kilohms is reported in kilohms:
  naming it `Ω` while the number is in kΩ would be wrong by a factor of
  a thousand. Only a unit that already expands to exactly 1 is given a
  name — the guard is on the scale, not only the dimension.
- **A dimension does not determine a kind of quantity** (VIM §1.1).
  Torque and energy share `m² kg s⁻²`, so the table names it `J`, and a
  torque must be reported with `unit = "N m"`. `Hz` carries the same
  caveat against an activity in becquerel. `check_units` refuses to
  unify such homonyms through `Kind`; `report` cannot make the same
  distinction, because a product of two plain quantities carries no
  kind to propagate. That is what the `unit` keyword is for, and the
  tests pin the escape hatch alongside the default.

`evaluate` is unchanged: it still returns the composed form, which is
the honest answer when no certificate is being written.

### Changed — every numeric value in the documentation carries its unit

This is a metrology library, and a page that substitutes `V => 5.0`
leaves the reader to guess whether that is volts, millivolts or
something else. Every executed example now declares its values as
quantities.

- **Where the answer's unit can be derived, it is** — the power and
  resistance certificate page now reads `evaluate(P, readings)` and
  `evaluate(R, readings)`, so watts and ohms come from the model
  rather than from a comment.
- **Where an API needs plain numbers, the stripping is explicit.**
  `dominant_source` ranks numbers, `build_evaluator` compiles them,
  `Measurements.Measurement` converts them; those blocks declare
  unit-carrying values and strip them at the call, rather than
  starting from bare floats.
- **The `Measurements.jl` bridge keeps its unit**:
  `Measurements.Measurement(R_num) * oneunit(evaluate(R, ohm).val)`
  returns `10.0 ± 0.028 Ω`.
- Pages touched: interoperability, power-resistance-metrology,
  uncertainty-budget, expanded-uncertainty, code-generation,
  display-substitute-safety, inverse-inference.

**Two places deliberately keep no units, and now say why.** The
argument of `exp` must be dimensionless — `exp(1 V)` is not a
quantity — so the linearity examples are genuinely dimensionless, as
is the nonlinearity indicator `η`, a ratio of two quantities of the
same dimension. The domain-guard examples test the *number* in
`.val`, and a scaling ratio carries no unit of its own. Annotating
either would be a physical error dressed as an improvement.

### Added — `evaluate` returns a result carrying the unit its model derives (REQ-238)

The worked examples substituted bare numbers and named the unit of the
answer in a trailing comment — `(r_num.val, r_num.err)   # ohms`. A
comment records what the author believed the model computes. If the
model computes something else, nothing says so.

- **`evaluate(m, values)`**, in the `DynamicQuantities` extension,
  takes values that carry units and returns `(val = …, err = …)` as
  quantities whose unit comes from the same dimensional walk
  `check_units` performs. Plain reals are accepted for dimensionless
  inputs.
- **The estimate and the uncertainty are annotated independently**, so
  a `u_c` that has drifted from the dimension of its own measurand
  (JCGM 100:2008 §4.3.1) is visible in the returned pair. Where they
  agree, the uncertainty is reported in the estimate's own unit, since
  the walk reaches it through squares and a square root and would
  otherwise print it in expanded base dimensions.
- **A missing value raises** rather than returning a half-substituted
  expression: there would be no number for a unit to attach to.
  `Symbolics.substitute` still does partial substitution.

**A trap worth recording.** The dimensional walk exists to check
dimensions, where an annotation's numeric magnitude is irrelevant, so
it lets a literal through as its own value: the annotation of
`f₀ = 1/(2π·sqrt(L·C))` carries the `2π`. Multiplying the substituted
number by that annotation divides the answer by `2π` — and the result
still looks like a plausible frequency. `evaluate` strips the
magnitude and keeps only the unit; the RLC example pins it.

### Fixed — `check_units` accepts symbolic units

Annotations built with `us"V"` raised instead of being compared:
dimensions were compared in whichever form the caller supplied, and a
`SymbolicDimensions` value cannot be compared against a base
`Dimensions` one. Both are now expanded to SI base form first, so the
two notations are interchangeable and can be mixed. `us"..."` is what
the worked examples use, because a result reading `A⁻¹ V` is worth
more to a reader than `m² kg s⁻³ A⁻²`.

### Fixed — a failing simplification no longer aborts the computation

Reading `m.dof` could throw. `Symbolics.simplify` raises an `Int64`
overflow inside `DynamicPolynomials` on `Rational` coefficients with a
large denominator. A degrees-of-freedom count of `1e12` — the
idiomatic "effectively infinite" ν for a Type B component under
JCGM 100:2008 §G.4.2 — enters Welch-Satterthwaite as
`1//1000000000000`, and putting that over a common denominator with
`1//30` is enough. The gauge R&R example in the documentation failed to build for
this reason (`upstream-bugs.md` UB-008).

- **`_simplify_for_report` no longer propagates exceptions.** On
  failure it returns the unsimplified expression: less tidy to read,
  identical in value. Simplification here has always been cosmetic, so
  it had no business taking down a computation whose result was
  already correct.
- This also covers UB-006, whose `BoundsError` on `(-U)^2` reached
  users by the same route.
- Like UB-007, the defect was masked by the Giac extension, which
  overloads `_simplify_for_report` and does not share it — so the same
  model raised in a docs build and passed in the test suite.

### Fixed — a wrong simplification could delete an uncertainty source

An uncertainty source could disappear from a model, understating the
combined standard uncertainty with no diagnostic. It was found in the
thermocouple gallery example, whose cold-junction source vanished when
the model was inverted through `sqrt`.

The cause is upstream and it is a **wrong answer**, not a missed
simplification: `SymbolicUtils.simplify_fractions` drops the constant
term of a numerator polynomial when the coefficients are small in
absolute terms, so `1e-9(3.0 + 5.0x)/sqrt(1 + x)` simplifies to
`5.0e-9sqrt(1 + x)` — a different function, wrong by `0.15` there. On
the sensitivity that exposed it the simplified form was exactly `0`:
the whole term gone, not merely mis-valued. Recorded as
`upstream-bugs.md` UB-007; the threshold is
absolute, so the defect is invisible in ordinary algebra and routine
in metrology, where a sensitivity of `1e-12` is unremarkable.

- **`_chain` no longer trusts a simplified zero.** Simplification is
  now treated strictly as a presentation step, and one that may never
  delete a source. When `simplify` reports zero, the *unsimplified*
  sensitivity is re-checked numerically against the scale of the
  contributions it was summed from; the term is dropped only if that
  confirms it, and where the two disagree the unsimplified form is
  kept — less readable, and correct.
- **Anything that cannot be evaluated keeps the term.** The bias is
  deliberate and asymmetric: reporting a source that really cancels
  costs a `0·u` row in the budget, while dropping one that does not
  understates `u_c`. Only one of those two is a metrological error.
- Genuine cancellations are unaffected — `x - x` still carries no
  sources and reports exactly `0`.

### Added — Monte Carlo cross-validation (REQ-230, REQ-231, REQ-233, REQ-234)

The first check on this package that does not come from the framework
it implements. The Annex H suite verifies the implementation against
the GUM's own worked answers, and every one of those answers is itself
first-order; sampling the input distributions is not.

- **`monte_carlo(m, distributions; n, coverage_probability, ndig)`**,
  behind the new `SymbolicUncertaintiesMonteCarloExt` extension. The
  propagation goes through `m.val` — the **nonlinear** model — with
  each input replaced by sampled `Particles`. Perturbing the linear
  form instead would reproduce the first-order answer by construction
  and validate nothing, which is the trap this milestone exists to
  avoid; it needs the source-to-input link added just before.
- The extension is triggered by **both** `MonteCarloMeasurements` and
  `Distributions`, which keeps `Statistics` out of the mandatory
  dependencies (REQ-130) and matches how it is used: the caller states
  each input's density as a `Distributions` object.
- **Densities are never defaulted** (REQ-231). A standard uncertainty
  is not a distribution — §6.4 assigns rectangular to a Type B
  half-width and normal to a Type A evaluation — and assuming
  normality would make the validation circular.

**What the §8.2 test actually asks turned out to be worth writing
down.** It compares coverage intervals, not `u_c`, and the first
version of these tests asserted the wrong thing:

- An **exactly linear** model — a sum, with no higher-order terms at
  all — with rectangular inputs **fails** the test: the sum of two
  uniforms is trapezoidal, so `y ± 1.96·u_c` is the wrong interval
  though the linearisation is perfect. "GUM validated" and "the model
  is linear" are different statements.
- Ohm's law at 1 % relative input uncertainty **fails** as well: a
  quotient of normals is skewed with heavier tails, so the sampled
  interval is wider and shifted by far more than the tolerance — while
  `u_c` agrees to four digits. Ten times smaller inputs and it passes.
  Adequacy is a property of the operating point, not of the formula.
- **The verdict is warned about when it is marginal.** A tail
  quantile's standard error falls only as `1/√n`, so a verdict near
  the tolerance boundary flips between runs; without the warning a
  noisy "not validated" reads as a finding about the measurement
  model. JCGM 101:2008 §7.9 answers this with an adaptive procedure,
  which is not implemented here. The first version of the test suite
  was itself caught by this.

### Added — the metrology gallery, eight worked calibrations

`docs/src/metrology-gallery.md`, in order of increasing difficulty,
each asserted end to end in `test/gallery/`. Every one was chosen for
a conclusion the algebra makes visible and a single number does not.

- **Torque transducer** `M = F·L` — the relative form of §5.1.6
  equation (12), and a budget that says to improve the lever arm
  rather than the force.
- **Four-wire Kelvin** — correcting a two-wire reading for a *known*
  lead resistance leaves that correction's uncertainty dominating the
  budget, while four-wire carries no lead source at all. The
  difference shows as a missing row, not a small number: a change of
  measurement model in the sense of GUM-6:2020.
- **Pressure transducer, two-point calibration** — the budget is not a
  property of the instrument. It changes along the range, and the
  relative uncertainty is five times worse at the bottom, which is why
  transducers are specified over a stated turndown.
- **Wheatstone bridge** — a matched pair of ratio arms beats two
  independent resistors of the same tolerance, and at ρ = 1 with equal
  relative tolerances the arms contribute **nothing**: only the
  standard is left. An uncorrelated budget cannot see this.
- **Pt100, Callendar–van Dusen** — the model is the inverse of the
  standard's relation, so the sensitivity is the reciprocal slope, and
  since B is negative the same 10 mΩ costs more at 600 °C than at 0 °C.
- **Thermocouple with cold-junction compensation** — the cold junction
  enters through the Seebeck coefficient at its own temperature and
  contributes ten times what the voltmeter does. Ten times better
  voltage resolution changes nothing.
- **Interferometric displacement** — the air, not the laser. A
  stabilised HeNe gives 10 nm over a metre; 0.1 °C and 50 Pa of air
  give 93 and 134 nm, and room conditions win by four orders of
  magnitude.
- **Gauge R&R** — where ISO 5725 stops. An R&R study yields Type A
  components only, so the reported `u_c` is understated; and three
  operators give the reproducibility term two degrees of freedom, so
  Welch-Satterthwaite drives `ν_eff` well below the naive 30 and `k`
  past 2.1. More operators barely change `u_c` and tighten the
  interval appreciably — an experiment-design conclusion the budget
  hands over for free.

### Added — the adaptive Monte Carlo procedure (REQ-237)

- `monte_carlo(..., adaptive = true)` implements JCGM 101:2008 §7.9:
  blocks of `n` trials are drawn until the results stabilise — twice
  the standard deviation of the block means, for the estimate, `u(y)`
  and **both interval endpoints**, below the numerical tolerance.
  Stabilising `u(y)` alone would miss the point: §8.2 compares
  intervals, and it is their endpoints that carry the quantile noise —
  which is exactly what made two of this release's own tests flicker.
- **"Not verified" and "verified and failed" are kept distinct.** A
  plain single run reports `converged = false` because nothing checked
  it, and `blocks == 1` says so; a run that exhausted its block budget
  reports `converged = false` with `blocks > 1` and warns. Collapsing
  the two would be the same ambiguity the package refuses elsewhere.
- **Refused for a vector of measurands.** §7.9 states its stopping
  rule for the four scalar results of one measurand; what
  stabilisation means for a correlation matrix the standard does not
  say, so the request raises rather than inventing a criterion.

### Added — the vector-valued case of JCGM 102 (REQ-236)

- `monte_carlo` now accepts a **vector of measurands**, samples the
  inputs once, and evaluates every output on that draw — returning one
  §8.2 comparison per output plus the sampled and symbolic
  **correlation matrices**, comparable entry by entry.
- It has to work that way. JCGM 102:2011 §6 asks for the covariance
  matrix of a vector-valued measurand rather than only its marginal
  uncertainties, and two separate calls would draw independent inputs
  and measure a correlation of zero by construction. That is the same
  defect as sampling correlated *inputs* independently, seen from the
  output side.
- Checked on §H.2's three outputs, which descend from the same three
  measurements and are therefore mutually correlated even with
  independent inputs. The test guards against a trivial pass: the R–Z
  correlation must exceed 0.5, so an identity-like matrix cannot
  satisfy it.

### Added — Milestone M14 complete: the Annex H cross-validation suite

The milestone's exit criterion, and one result worth stating on its
own.

- **JCGM 100:2008 §H.1 does not pass the §8.2 test**, and the package
  is not at fault. The end-gauge model contains `ls·δα·θ` with
  `δα` estimated at zero, so the first-order sensitivity to `θ` is
  `−ls·δα = 0` — the framework gives `θ` no contribution at all.
  Sampling recovers a variance of size `ls·u(δα)·u(θ)` ≈ 12 nm, which
  appears in quadrature: `√(31.7² + 11.9²) = 33.9 nm`, the sampled
  value. This is a second-order term in the strict sense, a product of
  two inputs whose estimates are both zero, and JCGM 100:2008 §5.1.2
  note 1 is the caveat it falls under. The first-order result remains
  correct — it computes what the GUM prescribes and reproduces the
  published 32 nm. The test asserts the mechanism, not just the
  disagreement, so a future change tells us which term moved.
- **§H.2 and §H.3 are cross-propagated as well.** §H.2 is the only
  case with three *mutually* correlated inputs — a 3×3 covariance
  rather than a pair — and the published coefficients turn out to be
  mutually consistent, which the Cholesky path requires: r(V,I) =
  −0.36, r(V,φ) = 0.86, r(I,φ) = −0.65 give a positive-definite
  matrix. Ignoring the correlations would put u(R) at 0.203 Ω instead
  of 0.071, so an independent draw would be unmistakable. §H.3 is the
  positive control of the correlated set: the model is exactly linear
  in two normally distributed fitted parameters, so the output is
  exactly normal and a failure there would indict the sampling rather
  than the framework.
- **§H.4 is validated with its declared correlation.** Sample and
  standard counting rates share six cycles at r = 0.646, and because
  they enter as a ratio the cross term reduces `u_c`; the sampled
  uncertainty lands on the correlated value, well under the
  uncorrelated one, which an independent draw could not do.
- **A deliberate disagreement, predicted without sampling.**
  `exp(x)` at `σ = 0.8` fails the test, and the sampled mean exceeds
  the first-order estimate by exactly `exp(σ²/2)` — the second-order
  term the framework drops. `linearisation_bound` and
  `second_order_correction` both flag it beforehand from the symbolic
  Hessian alone. A validation that could only demonstrate agreement
  would demonstrate nothing.

### Fixed — the Monte Carlo path asked for a density for a constant

- `_wrap` mints a zero-uncertainty source for every constant operand,
  so `y₂·(30 − 20)` carried one whose estimate is a number rather than
  an input variable, and the extension demanded a distribution for
  it — refusing §H.3 outright. A source of zero standard uncertainty
  is not a source of uncertainty; the rule was already applied when
  forming the variance and is now applied here too.
- **A stochastic assertion sitting near the §8.2 boundary was
  replaced.** It asserted that a finer operating point *passes*, from
  within a factor of two of the tolerance — the zone where
  `monte_carlo` itself warns. It flipped on CI's Julia 1.10 while
  passing locally on 1.12: seeding does not make such a test
  reproducible, because the RNG stream itself differs between Julia
  versions. The assertion is now on the discrepancy shrinking with the
  inputs, which is the point being made and is independent of the
  draw.

### Added — correlated inputs are sampled jointly (REQ-232)

- A declared correlation is now honoured on the Monte Carlo side as
  well, by drawing independent standard normals through the Cholesky
  factor of the source covariance — the multivariate normal of
  JCGM 101:2008 §6.4.8. Sampling the inputs independently would have
  silently reproduced the uncorrelated answer: for a difference of two
  inputs at ρ = 0.9 that is `0.707` against the correct `0.224`, and
  the comparison would have reported a disagreement that says nothing
  about the measurement model.
- **A covariance matrix that is not positive semi-definite is
  refused.** Pairwise coefficients assigned by hand produce one
  easily — `ρ(x,y) = ρ(x,z) = 0.9` with `ρ(y,z) = −0.9` asks two
  inputs to track a third closely while opposing each other — and no
  joint distribution has them. The factorisation is its own test: the
  diagonal term under the square root goes non-positive exactly there.
- **A non-normal marginal on a correlated input is refused**, not
  transformed. The Cholesky construction preserves marginals only
  because they are normal; applying it to a rectangular density would
  replace the density the caller stated. §6.4.8.4 is where a genuine
  joint PDF belongs.
- The factorisation is written in the extension rather than taken from
  `LinearAlgebra`, for the reason the certified-linearisation work
  wrote its own interval arithmetic: REQ-130 keeps `Symbolics.jl` the
  only mandatory dependency, and an extension may not reach for a
  standard library the package itself does not depend on.

### Added — a source records the input it perturbs

Groundwork for the Monte Carlo cross-validation milestone, and a fix
in its own right.

- **`Source` gains a `variable` field** (REQ-235). `V ± σV` states
  that the input `V` was measured with standard uncertainty `σV`; the
  quantity kept `σV` and dropped `V`, severing the only link between a
  contribution and the input it came from. Two things followed: every
  budget row was labelled `:opaque`, and a Monte Carlo cross-check
  could perturb only the **linear form** — comparing the linearisation
  with itself, which is no validation at all. That second consequence
  is what the M14 reconnaissance ran into.
- Only a **bare** input variable is recorded. `(V + 1) ± σ` gets
  `nothing`: it is already a function of an input, not an input, and
  naming it would invent a quantity the measurement model does not
  have.
- The label survives substitution, because it is provenance and not a
  value — a fully numeric budget still says which input each
  contribution came from.
- Budget rows derived from sources now carry both the name and the
  variable, so a source-derived row labels itself exactly as a
  variable-filtered one does.

### Changed — the documentation stops narrating its own construction

- **116 milestone references removed from the 17 published pages.**
  "Milestone M7 turns the symbolic pipeline into…", "the M8
  extension", "the M4 `@warn`" — development scaffolding that told a
  reader nothing about the library and dated every page. Three of them
  were not merely internal but **wrong**: `getting-started.md`
  announced that "the next milestone will add mathematical functions"
  which shipped long ago; `code-generation.md` presented `latex` as a
  stub awaiting an extension that exists; and `linearity-check.md`
  stated that mixed partials are not covered, which stopped being true
  when `linearisation_bound` landed. Those three are corrections, not
  cosmetics.
- Two historical sections of `docs/src/limitations.md` are **deleted**
  rather than rewritten — "Known limitations (M1–M9 legacy)" and
  "Binary operators and operand identity — resolved in M11". The
  history of a defect that no longer exists teaches a present-day
  reader nothing, and it occupied the top of the page.
- The specification is brought level with the code it describes:
  REQ-011 now covers unary minus, **REQ-023** the two-argument
  `atan`, **REQ-024** the deliberate refusal of non-differentiable
  models, and **REQ-074** the numerical robustness of emitted code.
  REQ-215 and REQ-216, written earlier in this release, are now traced
  from the code that implements them. An audit of all 104 requirements
  against every `Traces REQ-…` in `src/` and `ext/` shows nothing
  traced that the specification does not define.

### Added — Milestone M14 planned: Monte Carlo cross-validation

- `ROADMAP.md` promotes the `MonteCarloMeasurements.jl` bridge from
  the post-1.0 list to a scheduled milestone (v0.14.0), because it is
  the only item there that validates the package **from outside**: the
  Annex H suite checks the implementation against the GUM's own worked
  answers, and every one of those comes from the same first-order
  framework this package implements. Requirements REQ-230 – REQ-234.
- The milestone is written around the two decisions that can quietly
  ruin it. A standard uncertainty **is not a distribution**, so the
  per-source PDF is supplied by the caller and never defaulted to
  normal — a run that assumes normality cannot detect that normality
  was wrong, and the validation would be circular. And correlated
  sources must be sampled **jointly**, through the Cholesky factor of
  the source covariance: sampling them independently would reproduce
  the uncorrelated answer and "agree" for the wrong reason.
- The exit criterion is JCGM 101:2008 §8.2's own test — agreement to
  the stated significant digits of `u_c` — and the milestone requires
  a case where the two methods **disagree**, with
  `linearisation_bound` predicting it. A validation that can only
  demonstrate agreement demonstrates nothing.

### Added — phase, robust code generation, and an honest refusal

A third round of differential testing, on numeric robustness and on
model shapes the package had never been asked for.

- **`atan(y, x)`**, the quadrant-preserving phase, with sensitivity
  coefficients `x/(x²+y²)` and `-y/(x²+y²)`. Only the one-argument
  form existed, so a phase built from quadrature components — what a
  lock-in amplifier or a vector analyser actually reports — could not
  be propagated at all. At the origin the phase is undefined and both
  sensitivities diverge; the package warns rather than refuses, the
  same posture as the REQ-140 division guard.
- **Generated code emits `hypot`.** `sqrt(Σ (cᵢuᵢ)²)` is exact in
  algebra and fragile in double precision: it overflows once a
  contribution passes ~1e154 and underflows to zero below ~1e-150, so
  the C evaluator returned `Inf` or `0` where `hypot` — `math.h`, and
  Julia's `Base` — returns the right number. Four of five probe cases
  were wrong. The symbolic form is untouched, because a square root of
  a sum of squares is what every GUM text writes; only the emitter
  changes. The rewrite applies exactly when every addend is a square,
  so a **declared correlation falls back to `sqrt`**: the eq. (13)
  cross term is not a square and may be negative, and dropping it
  silently would be worse than an unprotected root. Both directions
  are tested.

  The inputs that trigger the overflow are outside any plausible
  measurement range, so this is insurance rather than a defect that
  was biting: the argument for doing it is that generated C is called
  by code the package never sees.
- **`max`, `min` and `clamp` now refuse with a reason.** They raised a
  bare `MethodError`, which reads as an oversight. It is a decision:
  the GUM linearises around the estimates (§5.1.2), a piecewise model
  has no derivative at its switch point, and near the switch the
  linearisation is arbitrarily poor even where the derivative exists.
  The error says that and points at JCGM 101:2008. Same defect as the
  REQ-021 message fixed earlier in this release — a refusal that does
  not explain itself is indistinguishable from a gap.

### Added — two documented traps in reading a budget

Both came out of extending the differential testing to the shapes the
package itself produces. Neither is a defect; both are silent, so they
are now written down and pinned by a test.

- **Repeating `±` declares a new source.** Identity comes from the
  measurement object, never from the symbol name, so `R2 ± σR2`
  written twice in one model is two independent resistors sharing a
  tolerance symbol. The budget shows four rows for three inputs, and
  `u_c` double-counts: on a voltage divider it reports 0.0335 V where
  the answer is 0.0135 V. No warning is emitted, and deliberately so —
  two sources sharing a standard uncertainty is also exactly what two
  nominally identical instruments look like, and nothing in the
  expressions tells the two apart. The guidance is one line: bind each
  physical input to a variable once, then reuse it. Documented in
  `docs/src/uncertainty-sources.md` with the worked contrast, and
  pinned by `test/source/test_duplicate_sources.jl`. Found by making
  the mistake while writing a probe.
- **A combined sensitivity prints with its denominator expanded.**
  Where an input appears more than once, its coefficient is a sum of
  contributions, and simplifying that sum expands the denominator:
  `R1·Vin/(R1² + 2R1R2 + R2²)` where `R1·Vin/(R1+R2)²` reads better.
  Exact, merely less readable, and unreachable: neither
  `Symbolics.simplify` nor `Symbolics.simplify_fractions` factors it,
  and the `Giac` backend expands it as well. Recorded in
  `docs/src/limitations.md` rather than worked around.

### Fixed — four defects found by differential testing against other CAS

Comparing the package's own expression shapes against Giac.jl and
SymPy.jl turned up nothing unsound upstream in metrology-shaped
expressions, but four defects here. None of them was visible by
reading the code; all four needed the expressions to be *built*.

- **Unary minus was not defined.** `-m` raised a `MethodError` while
  `0 - m` and `-1 * m` — the same operation written differently — both
  worked. It now goes through the chain rule with `c = -1`, so the
  source survives and `m + (-m)` is exactly zero rather than `σ√2`.
  `+m` is the identity, added for the same reason. A sign change
  cannot alter a dispersion (JCGM 100:2008 §4.3.1), so `u_c` is
  unchanged.
- **The REQ-021 error blamed the wrong thing.** `apply(z -> -z, m)`
  reported "cannot compute closed-form derivative", sending the reader
  to look at differentiability — while `∂(-x)/∂x = -1` all along, and
  the real cause was a missing method. The only thing the code
  observes is a `MethodError`, so the message now **names the
  operation that failed to dispatch** and stops diagnosing a
  derivative it never examined.
- **A source of zero uncertainty is no longer a source.** Every
  constant operand is wrapped as a measurement with `u = 0`, so
  `2 * m` and `0 - m` carried two sources where the model has one and
  the variance read `sqrt(0·0² + c²u²)`. Such sources are now dropped
  from the variance.
- **A constant sensitivity no longer leaves `sqrt(c²u²)` behind.** The
  M11 short-circuit covered `c = 1` only, so every negation reported
  `sqrt(σ²)` where the answer is `σ`. It now factors any constant
  whose square is an exact integer square — `|c|·u`, no float
  contamination — and recognises the `ifelse(signbit(x), -1, 1)` that
  differentiating `abs` produces, whose two arms square to the same
  value. `abs(m)` therefore reports `σ` instead of carrying a branch
  test in its uncertainty. Symbolics cannot make this reduction
  itself: it needs `u ≥ 0` and there is no way to state it
  (`upstream-bugs.md` UB-003, Symbolics.jl#98). The package can,
  because REQ-005 makes it true by construction.

  One consequence is a reversal: `x + x` now prints `16.8 ± 1.4`,
  which is what `getting-started.md` claimed before the doctest
  conversion earlier in this release replaced it with the
  `sqrt(1.9599999999999997)` the code actually produced. The prose was
  right and the code was wrong.

### Added — the budget becomes a type

- **`UncertaintyBudget` and `BudgetRow`.** `uncertainty_budget` no
  longer returns a bare `Vector{NamedTuple}`. The rows could not
  carry what a budget is *about*: which measurand they decompose,
  what `u_c` they recombine into, and whether a declared correlation
  is in play. The last one matters for reading the table at all —
  under JCGM 100:2008 §5.2.2 equation (13) the cross terms belong to
  no single row, so the percentage-of-variance column stops summing
  to 1 and a negative cross term can push one row past 100 %. A
  reader cannot tell that from the rows, so `budget.correlated` says
  it. Traces REQ-209.
- The budget **is** an `AbstractVector` of its rows, so every loop,
  index, `length` and renderer written against the M3 shape keeps
  working. Two test files moved from `haskey(row, :field)` to
  `hasproperty` — rows are structs now, not named tuples.
- The `DataFrames.jl` extension becomes one **rendering** of that
  value (`as = :dataframe`) rather than a second implementation, and
  follows the rows: `variable` for the filtered form, `source` for
  the source-derived one. The `as = :namedtuple` default is gone;
  `as = :budget` is the default and the error message names the
  change.

### Added — JCGM 100:2008 §H.4 validation

- **Radon massic activity by liquid-scintillation counting**, the
  fourth and last Annex H worked example, completing the ISO/IEC
  17025 §6.4.7 validation suite alongside H.1, H.2, H.3 and
  JCGM 102. It is the case where correlation *reduces* the combined
  uncertainty: the sample and standard counting rates come from the
  same six cycles and the same background counts, r = 0.646, and
  because they enter as a ratio the cross term is negative — ignoring
  it overstates `u_c` by about a third. The package reproduces both
  of the Annex's own analyses, 0.4300 Bq/g with u_c = 0.0083 through
  the correlated means (§H.4.3.1) and 0.4304 with 0.0084 through the
  averaged ratio (§H.4.3.2), and the agreement between the two paths
  — one of which goes through `declare_correlated` and the other not
  — is itself the test.

### Added — the first tests that measure output size

- **Expression-size regressions.** A purely symbolic GUM library
  fails by producing expressions no CAS can simplify and no user can
  read, and nothing in the suite measured that: the 285 000-character
  `expanded_uncertainty` fixed earlier in this release was found by
  rendering the documentation. Two tests now bound it — a 12-source
  product's `u_c` stays in the thousands of characters with growth
  bounded well under exponential, and its budget and C evaluator both
  build; a three-source divider with symbolic `ν` keeps its expanded
  uncertainty under 5 000 characters. The bounds are loose by design:
  they catch a blow-up, not a refactor. This is the M12 exit criterion,
  which had been verified by measurement but never by a test.

### Changed — silent failures made audible

- **The Giac extension no longer swallows its failures.** A bare
  `catch` sent every Giac parse or conversion failure to the
  `Symbolics.simplify` fallback with nothing recorded, so a session
  with `Giac` loaded could advertise CAS-grade simplification and
  quietly not deliver it. It now logs the expression and the
  exception at `@debug`. A full test run does hit this path — four
  parse errors on a mangled `u_`-prefixed identifier, now recorded as
  **UB-005** in `upstream-bugs.md`, where the non-UTF-8 bytes after
  the prefix point at a string read past its end rather than at a
  malformed expression.

### Added — UB-006, a latent crash in the default simplifier

- `Symbolics.simplify((-U)^2)` **throws a `BoundsError`** on Symbolics
  7.39.0 / SymbolicUtils 4.46.1. `(-U)^2` builds a degenerate `Mul`
  node holding a single factor, and the associative-commutative rule
  machinery takes a two-element `view` of its arguments without
  checking there are two. The value also *prints* as `(U^2)` while
  `isequal((-U)^2, U^2)` is `false`, so an equality-based test can
  fail against an expression that displays identically. `expand`
  normalises the node and is the workaround.
- It matters here because `_simplify_for_report` **is**
  `Symbolics.simplify` when `Giac.jl` is not loaded, with no guard. No
  propagation path reaches it today — a difference of two quantities
  yields `sqrt(σx² + σy²)`, whose square terms carry two factors — but
  any measurand whose combined uncertainty reduces to the square of a
  single negated symbol would take propagation down. Recorded rather
  than worked around, since a blind `expand` before every
  simplification would undo the M12 no-flattening guard.
- Filed upstream as
  [SymbolicUtils.jl#1044](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1044),
  after reproducing it on the current releases of both packages —
  SymbolicUtils 4.46.2 alone, and with Symbolics 7.39.0. Reducing it
  for the report showed the same node is a concrete instance of
  SymbolicUtils.jl#1023, the TermInterface contract violation: `iscall`
  is true while `isexpr` is false, `head` and `children` raise
  `MethodError`, and the node does not round-trip through `maketerm`.

### Fixed — two statements that were simply untrue

- `upstream-bugs.md` UB-003 said the missing assumptions framework had
  **no upstream issue filed**. There is one:
  [Symbolics.jl#98](https://github.com/JuliaSymbolics/Symbolics.jl/issues/98),
  open since 2021 and dormant since June 2023, where the proposed
  design — domains via `DomainSets.jl`, carried on the metadata
  system — was raised and never pursued. Symbolics' own SymPy-parity
  checklist does not list assumptions at all, so the entry now says
  what is actually the case: tracked, dormant, nothing expected soon.
- `ROADMAP.md` described `LICENSE.md` as the MIT text; the file is
  BSD 3-Clause. The same claim in this changelog's `[Unreleased]`
n### Added
- **CausalGraphs.jl Integration**: `SymbolicUncertaintiesCausalGraphsExt` weak dependency extension providing `parse_measurement_model` (Scaffolding Mode) and `evaluate_measurement_model` (Full-Auto Mode) for generating uncertainty budgets directly from causal graphs/Ishikawa diagrams.
  section was corrected in the previous commit.

### Changed — specification traceability restored

- `specification/ears.md` had no **REQ-200 – REQ-208** at all: the
  M11 series existed only in `ROADMAP.md`, and M12 and M13 shipped
  with no requirements of their own. The 2xx series is now allocated
  by milestone — 200–209 (M11, new §21), 210–216 (M12, §12),
  220–223 (M13, §20) — and `ROADMAP.md` carries the allocation table.
- Superseded requirements are **kept and marked**, never deleted: a
  deleted requirement leaves a citation in an old docstring pointing
  at nothing. REQ-031/REQ-032 lapse with the three-argument
  `propagate`; REQ-100 – REQ-102 lapse with the Unitful extension;
  REQ-042, REQ-044 and REQ-050 are amended by M11. `src/units.jl` and
  `src/certified.jl` now trace the requirements they actually
  implement rather than the ones they replaced.
- **Appendix A listed 25 exports against 34 in the module.** Missing
  were `ExpandedUncertainty`, `declare_correlated`, `covariance`,
  `correlation`, `check_units`, `UnitReport`, `linearisation_bound`,
  `second_order_correction` and now the two budget types — so the
  published `docs/src/methodology-reference.md`, which mirrors it,
  documented two thirds of the API. Both are complete, and
  `test/package/test_api_freeze.jl` audits all of them: adding
  `UnitReport` to the audit immediately caught its docstring for
  carrying no JCGM citation (REQ-160).
- `ROADMAP.md` marked M11, M12 and M13 "📋 planned" with their work
  done and their boxes unticked, and `docs/src/limitations.md` still
  listed second-order propagation and a richer Student-t `k` as
  future candidates after both had shipped. Statuses now match the
  tree, and the legend gains `[⛔] blocked upstream` for the two items
  that are waiting on `Symbolics.jl`: `FortranTarget` (UB-004) and
  sign-aware `abs(σ)` simplification (UB-003).
- The **inert `unit` metadata slot** planned for M11 is dropped
  deliberately rather than left open. M12 answered the same need
  better: units annotate the *symbols* of the model, in a dictionary
  supplied by the caller. A unit inside the quantity would have to
  survive every chain-rule step, substitution and simplification the
  linear form performs, and `check_units` needs none of that.

### Added — JCGM 100:2008/Amd.1:2026, nonlinearity in the estimate

- **`second_order_correction(f, measurements)`** returns the term the
  2026 amendment asks for where the nonlinearity of `f` is
  significant. §4.1.4 NOTE 1 requires either a Monte Carlo method or
  higher-order terms in the expression for the **estimate** `y` — not
  for the uncertainty — and equation (H.10) generalises the term to
  non-independent inputs. The implementation is that double sum,
  `½ ΣᵢΣⱼ (∂²f/∂xᵢ∂xⱼ) u(xᵢ,xⱼ)`, reusing the `covariance` function
  added for JCGM 102 off the diagonal; with independent inputs it
  collapses onto NOTE 1.
- Verified against results that hold whatever the amendment's wording:
  for `f = x²` the correction is exactly `u²(x)`, which is
  `E[X²] = μ² + σ²`; for a product of independent inputs it is zero,
  since `E[AB] = E[A]E[B]`; for correlated inputs it is `cov(a,b)`.
  And against the amendment's own claim about §H.1 — the term vanishes
  there, so the end-gauge estimate is unaffected.
- The correction is **returned, never applied** (REQ-182). The
  amendment asks for the term to be included knowingly; folding it
  into `val` would make a corrected estimate indistinguishable from an
  uncorrected one. Where no closed-form second derivative exists the
  function raises and points at Monte Carlo, the other route the
  amendment allows.
- It answers a different question from
  [`linearisation_bound`](docs/src/linearity-check.md), which bounds
  the error the first-order law makes in `u_c`. A model can need one
  and not the other: a product of independent inputs has an exact
  estimate and an inexact combined uncertainty.

### Changed — normative references brought up to date

- JCGM 104:2009 is superseded by **JCGM GUM-1:2023** (adopted as
  ISO/IEC Guide 98-1:2024); **JCGM GUM-5:2026** (worked examples) and
  **JCGM GUM-6:2020** (developing and using measurement models) are
  added, along with the amendment itself, to the reference table in
  `docs/src/index.md`, to the REQ-176 no-reproduction audit and to
  `CITATION.bib`.
- GUM-6:2020 prompted a scope statement the package had left implicit,
  now the opening section of `docs/src/limitations.md`: **building the
  model `Y = f(X)` is upstream of everything here.** In practice the
  largest uncertainties usually come from the model rather than from
  the propagation — a term omitted from `f` contributes nothing to
  `u_c` however carefully `u_c` is computed.

### Added

- **JCGM 100:2008 §H.2 validation** — simultaneous resistance,
  reactance and impedance from a common voltage, current and phase.
  The package reproduces the reference figures in both regimes:
  independent inputs, and the correlated case with r(V,I) = −0.36,
  r(V,φ) = 0.86, r(I,φ) = −0.65, giving u(R) = 0.070, u(X) = 0.296,
  u(Z) = 0.237 against the published 0.071, 0.295, 0.236. This is the
  ISO/IEC 17025 §6.4.7 validation artefact, and it is the example that
  forces correlation into the type.

### Fixed

- **Declared covariances were silently dropped mid-expression.**
  `_chain` pruned any covariance whose sources were not currently in
  `terms`, so in `(V/I)·cos(φ)` the division discarded both
  covariances involving φ before `cos(φ)` reintroduced it. §H.2 then
  returned u(R) = 0.203 instead of 0.071 — wrong by a factor of three,
  with no warning, in exactly the case correlation support exists to
  serve. A declared correlation is a hypothesis about the measurement
  model and must survive the intermediate steps of an expression.
- **`declare_correlated` could not be chained.** It counted the source
  descriptors a quantity carries rather than the sources it derives
  from, and a quantity that has already taken part in one declaration
  carries its partner's descriptor. Three mutually correlated
  inputs — §H.2 exactly — were therefore inexpressible.

- **`expanded_uncertainty` produced a 285 000-character expression**
  when `ν_eff` was symbolic. `k` contains `(1/ν)³` from the
  Cornish-Fisher series, and expanding the product `k · u_c` against a
  Welch-Satterthwaite fraction inflated it beyond any use — a
  three-source voltage divider emitted `abs(R2/(R1+R2))^24`. The
  product is no longer simplified: 285 816 characters become 429, and
  the factored form is the readable one anyway. Found by rendering the
  documentation, not by the test suite, which measured no output
  sizes.
- `docs/src/expanded-uncertainty.md` still used `.err` on an
  `ExpandedUncertainty`, having survived the M11 phase 4 break that
  the tests were migrated for.
- `declare_correlated` is now **exported**. It is the API for REQ-203
  and REQ-205, and `docs/src/uncertainty-sources.md` had been using it
  unqualified since M11 — so the documented call did not work.
- `docs/src/inverse-inference.md` showed `Float64(::Symbolics.Num)`,
  which throws (UB-001), and two `linearity-check.md` blocks relied on
  variables that were never defined.

### Added — Milestone M13, certified linearisation

- **`linearisation_bound(f, measurements; coverage_factor, values)`**
  bounds how wrong the GUM's first-order result can be, over the whole
  coverage region. Taylor's theorem with the Lagrange remainder gives
  `|R| ≤ ½ Σᵢⱼ max|Hᵢⱼ|·(k·uᵢ)(k·uⱼ)`, each `Hᵢⱼ` bounded by interval
  arithmetic. JCGM 101:2008 validates the linearisation by *sampling*
  and can only speak for the points it drew; a bounded symbolic
  Hessian certifies every point at once.
- **Mixed partials are included**, unlike M6's diagonal-only
  indicator. This is not academic: a product's Hessian has a zero
  diagonal, so `check_linearity` calls `a·b` linear when all of its
  nonlinearity sits in `∂²(ab)/∂a∂b`.
- A small internal interval arithmetic rather than a dependency —
  REQ-130 keeps `Symbolics.jl` the only mandatory one. It **raises**
  where no rigorous bound exists (a denominator spanning zero, `log`
  reaching zero, an operation with no interval extension): an unsound
  bound is worse than none.
- The bound is reported, never applied. REQ-182 stands.

### Fixed

- **`x / x` reported a round-off residue as uncertainty for some
  numeric estimates.** With `x = 0.1` the two opposite sensitivities
  are computed as `1/0.1 = 10.0` and `0.1/0.01 = 9.999999999999998` —
  `0.01` is not representable — so they failed to cancel by 1.8e-15,
  surfacing as `1 ± sqrt(9.4e-35)`. That is exactly the defect M11
  exists to remove, resurfacing through floating-point arithmetic
  instead of through operand identity. `_chain` now keeps each
  contribution separately and recognises a sum that has lost every
  significant digit of its own terms. The test is relative and only
  fires when everything is numeric, so a genuinely tiny uncertainty is
  untouched. Reported by a user; `5.0`, `3.0` and `7.0` all cancelled
  correctly, which is why no test caught it.
- **The documentation still described the pre-M11 trap as current.**
  `getting-started.md` carried a `!!! warning "Repeated operands give
  spurious uncertainty"` block printing the faulty results as expected
  behaviour, and `sensitivity-analysis.md` still told readers to reach
  for `propagate` whenever an expression reuses a measurement.

### Changed

- **`Measurements.jl` exports `±` too**, so `using` it alongside
  `SymbolicUncertainties` makes the operator ambiguous and unusable —
  Julia resolves neither. The interoperability page had been showing
  code that could not run since M8; it now uses `import Measurements`
  with a qualified call, and says so in a warning. Same trap as
  `@u_str` between `Unitful` and `DynamicQuantities`, on a more
  central operator.
- `docs/src/power-resistance-metrology.md` used `.err` on an
  `ExpandedUncertainty` in seven places — the third page found to have
  outlived the M11 phase 4 break.
- `docs/src/index.md` had a block running `Pkg.test()`, which a
  documentation build must never execute.
- **63 of the 103 documentation blocks now execute at build time** (`@example`), so their output is generated rather than
  transcribed. Every defect listed under *Fixed* above was found by
  running them.
- **Documentation examples are now executed, not transcribed.** The
  package had 102 inert ```julia blocks and zero doctests, while
  `test/package/test_doctests.jl` ran `Documenter.doctest` in CI over
  nothing at all — which is how the obsolete passages survived M11.
  The identity-cancellation examples become `jldoctest` blocks,
  verified at build time, with `DocTestSetup` in each page's `@meta`.
  The very first conversion caught an error in this changelog's own
  documentation: `x + x` was written as `16.8 ± 1.4` when the real
  output was `16.8 ± sqrt(1.9599999999999997)`. (Later in this release
  the constant-sensitivity fold makes the original `16.8 ± 1.4`
  correct again — the prose had been right and the code wrong.)

### Added — Milestone M12, dimensional checking

- **`check_units(expr_or_measurement, units)` returns a report and
  never throws.** A unit mistake is something to be told about, not
  something that should stop a derivation — which is what the M8
  Unitful extension's construction-time `DimensionError` did. Units
  are annotations of symbols supplied in a dictionary, never values
  inside the expression: `ModelingToolkit` makes the same choice, and
  a quantity living in the tree would be dragged through every
  simplification and derivative.
- Three annotations for the cases dimensional equality cannot decide,
  because it is necessary but never sufficient:
  **`Affine`** (°C, °F — `20 °C + 20 °C` is not `40 °C`; only
  differences are intervals, and an uncertainty in °C *is* a kelvin
  interval since a dispersion has no origin, §4.3.1);
  **`Scaled`** (%, ppm, dB — all dimensionless, none interchangeable,
  and dB logarithmic on top); and **`Kind`** (torque vs energy, both
  N·m; activity vs frequency, both s⁻¹ — VIM §1.1: a quantity is not
  defined by its dimension).
- Checking a `SymbolicMeasurement` also verifies that **`u_c` carries
  the dimension of the measurand** — the most common unit error in a
  budget, and structurally invisible elsewhere since `y` and `u` live
  in different fields.

- **A closed-form coverage factor for symbolic `ν_eff`.** A
  Cornish-Fisher expansion in `1/ν` replaces the placeholder: where a
  symbolic `ν_eff` previously fell back to the normal quantile —
  silently discarding the degrees of freedom, the one thing a coverage
  factor exists to account for — `k` is now a real function of `ν`.
  Against JCGM Table G.2 at p = 0.95 it gives 2.2280 at ν = 10 (table
  2.228), 2.0860 at ν = 20, 2.0423 at ν = 30 (table 2.042), and the
  normal quantile in the limit. The expansion is asymptotic and
  degrades below ν ≈ 10, which is where REQ-175 already warns.
- **Common-subexpression elimination in `build_evaluator`** for the
  Julia target. Sensitivity coefficients share almost all of their
  structure — for a product, each is the product of all the *other*
  inputs — so without CSE the generated code recomputes them once per
  source, with redundancy growing quadratically in the number of
  sources. `Symbolics` defaults `cse` to `false`. Results are
  unchanged, which is the point. The C target accepts no such keyword;
  C compilers do their own, so the cost is emitted source size rather
  than runtime.

### Removed

- **The `Unitful` extension**, replaced by `DynamicQuantities`.
  `Unitful` encodes units in the type parameter, so a budget's
  deliberately heterogeneous rows cannot share a concrete element
  type; `DynamicQuantities` keeps dimensions in a runtime field. It is
  also the system `ModelingToolkit` actually validates — its
  `screen_unit` accepts only `DQ.AbstractQuantity` and passes Unitful
  metadata through unchecked. `DynamicQuantities` is a **weak**
  dependency: `Symbolics.jl` remains the only mandatory one (REQ-130).

### Changed — package renamed

- **`ErrorPropagation.jl` is now `SymbolicUncertainties.jl`.** The old
  name claimed a whole problem domain and was generic enough to draw
  objections at General registration, where a rename after the fact
  costs a new UUID and a user migration. Nothing was registered and no
  tag existed, so the change was free — this was the last cheap moment
  to make it.

  `Symbolic` states the actual differentiator (you get the algebraic
  expression of `u_c`, not a number) and places the package in the
  `Symbolics` family, which is accurate: `Symbolics.jl` is the sole
  mandatory dependency. The plural follows the ecosystem convention
  for a package supplying a family of quantities (`Measurements.jl`,
  `Distributions.jl`).

  493 occurrences across 167 files, seven files renamed (the module
  and the six extensions, e.g. `ErrorPropagationGiacExt` →
  `SymbolicUncertaintiesGiacExt`). The UUID is unchanged. The GitHub
  repository is renamed; URLs, badges and `CITATION.bib` follow.

### Fixed

- `docs/src/inverse-inference.md` named the voltage measurement `R_m`
  and then reused `R` for the resistance two lines later — two
  quantities under one name in a six-line block. It is `V_m`,
  matching the convention every other page uses.

### Migrating to M11

`x - x` and `x + x` change value. If you relied on either through the
binary operators, you were relying on a defect: they returned `σ√2`
where the answers are `0` and `2σ`. Nothing else in a model built from
distinct inputs changes — equation (10) is reproduced exactly.

Three signatures change:

| Before | Now |
|---|---|
| `propagate(f, ms, Σ)` | declare correlations on the quantities: `declare_correlated(a, b, ρ)` |
| `expanded_uncertainty(m, k).err` | `expanded_uncertainty(m, k).U` — the result is an `ExpandedUncertainty` |
| `uncertainty_budget(m, variables, sigmas)` | `uncertainty_budget(m)`; the three-argument form still works as a filter |
| `uncertainty_budget(m)[1].field` on a `NamedTuple` | the same access on a `BudgetRow`; `haskey(row, :field)` becomes `hasproperty` |
| `uncertainty_budget(m; as = :namedtuple)` | `as = :budget` (the default); the value already iterates as a vector of rows |

`relative_sensitivity(m, xᵢ, σᵢ)` now raises instead of answering once
correlations are declared — use `relative_sensitivity(m, source)`.
`m.err` and `m.dof` are computed properties rather than stored fields;
reading them is unchanged.

### Added

- **Milestone M11, phase 1 — independent uncertainty sources.** New
  `src/source.jl` introduces `SourceId` (the identity of one
  independent measurement), `Source` (its symbolic standard
  uncertainty, optional degrees of freedom and display name), an
  atomic identity counter, sensitivity accumulation, context merging,
  and `_combined_uncertainty` — the single quadratic form that yields
  JCGM 100:2008 eq. (10) with independent sources and eq. (13) with
  declared covariances. Traces REQ-200, REQ-201, REQ-204, REQ-205.
- `SymbolicMeasurement` now carries `val`, `terms` (∂val/∂source),
  `sources` and `cov`. Source descriptors and covariances are carried
  **by the quantity**, not held in a module-level registry: phase 0
  found that a registry breaks `Symbolics.substitute`, since
  substituting `σx => 0.7` would have to reach shared state and
  without it a fully substituted measurement no longer yields a number
  (REQ-120, REQ-123, M4 exit criterion). The only global left is the
  identity counter, making `±` impure exactly as `gensym` is.

### Removed

- **`expanded_uncertainty` no longer returns a `SymbolicMeasurement`.**
  It returns the new `ExpandedUncertainty`, carrying `(val, U, k,
  dof)`. `U = k · u_c` is a coverage-interval half-width, not a
  standard uncertainty, so a quantity holding it is not propagatable —
  feeding it back into a computation would silently inflate every
  downstream result by `k`. A distinct type makes that mistake
  impossible to make by accident (JCGM 100:2008 §6.2). The API is
  therefore **26 exports**, not 25: a listed export cannot have an
  undocumented return type.
- **`propagate(f, ms, Σ)`, the three-argument correlated method, and
  `src/propagate_correlated.jl` (99 lines).** Correlation is a
  property of the sources, not an argument the caller supplies — the
  case that matters is two quantities correlated *because they derive
  from a common upstream measurement*, which is exactly the case where
  the user cannot write `Σ` by hand. REQ-207: one public propagation
  path. REQ-031 and REQ-032 (the `DimensionMismatch` guard that
  existed to protect the removed method) lapse with it.

### Changed

- **Milestone M11, phase 4 — the consumers read the source structure.**
  `uncertainty_budget(m)` derives its rows from `terms` and no longer
  requires `variables` and `sigmas` (REQ-206) — asking the caller to
  restate them requested information the object already holds, and
  could not express a source with no user-facing symbol. The
  three-argument form survives as a filter. A cancelled source
  produces no row at all, where the old budget listed whatever the
  caller passed.
- `m.dof` derives `ν_eff` by Welch-Satterthwaite from the per-source
  contributions (JCGM 100:2008 §G.4 eq. G.2b) instead of hand-passed
  vectors, returning `nothing` unless every contributing source
  carries degrees of freedom (REQ-208).
- `relative_sensitivity(m, s::SourceId)` is the source-based form,
  well defined in both regimes. The variable-based
  `relative_sensitivity(m, xᵢ, σᵢ)` now **raises** once correlations
  are declared rather than returning a quietly wrong number: under
  eq. (13) the cross terms are missing from the numerator, the
  fractions no longer sum to 1, and a negative cross term can push a
  contribution past 100 %.
- `dominant_source(m)` likewise derives from the structure.
- **Milestone M11, phase 3 — one propagation path.** `propagate(f, ms)`
  is now a convenience over the operators rather than a second
  implementation: it applies `f` to the measurements and lets the
  overloaded operators build the linear form. A source shared between
  two arguments therefore cancels or correlates correctly, which the
  previous implementation could not do. Its REQ-021 contract is
  preserved — a function built from unoverloaded operations still
  raises `ArgumentError` pointing at `apply(f, m; derivative = ...)`
  rather than leaking a raw `MethodError` — as is the constant-model
  case, which returns a zero-uncertainty measurement.
- `declare_correlated(m1, m2, ρ)` **returns** new quantities instead of
  mutating shared state, so two models in one session can hold
  different and equally valid correlation hypotheses. The declared
  covariance enters as the cross term of JCGM 100:2008 §5.2.2
  equation (13); with `ρ = 0` it collapses onto equation (10), so the
  independent case is a special case rather than a separate path.
  Traces REQ-203, REQ-205.
- **Milestone M11, phase 2 — the binary operators propagate by the
  chain rule.** `x - x` and `x / x` now return **exactly zero
  uncertainty through the plain operators**, with no user awareness
  that a trap ever existed. This is the acceptance test of M11 and it
  closes UB-002 at the type level. `x + x` is equally affected and
  equally wrong before: it returned `σ√2` where the answer is `2σ` —
  the old path mishandled shared operands in both directions, not just
  subtraction.
- `src/arithmetic.jl` no longer contains **any** uncertainty formula.
  Each operator states its estimate and its sensitivity coefficients
  (JCGM 100:2008 §5.1.3) and `_chain` builds the linear form; the
  variance is formed in exactly one place. `math.jl` and `apply.jl`
  migrate the same way. The `|∂f/∂x|` absolute value in the unary path
  is gone: for a single source the two agree once squared, but keeping
  the sign is what lets a source cancel in a larger expression.
- `err` and `dof` are **computed properties** rather than stored
  fields, so the 93 `.err` reads across the test suite, the 4 in
  `ext/` and the 52 in `docs/` keep working untouched. The historical
  `SymbolicMeasurement(val, err, dof)` constructor mints one *opaque*
  source of sensitivity 1, which is why all 21 pre-M11 construction
  sites behave identically and `x - x` still returns `σ√2` at this
  phase — phase 2 replaces those opaque sources with the chain rule
  and flips it to `0 ± 0`.
- `Symbolics.substitute` on a measurement now traverses `val`, every
  sensitivity, every source `u` and every covariance, **preserving
  source identities**: substituting numbers must not turn one
  measurement into an unrelated one.

### Fixed

- **LaTeX in the published documentation rendered as literal text.**
  Every `math` block in `getting-started.md` and
  `sensitivity-analysis.md` used doubled backslashes, so KaTeX read
  `\\` as a line break and rendered the following command name as
  prose: the Ohm's-law uncertainty showed as "fracVI sqrtleft…",
  and so did GUM equations (10) and (13) and the voltage-divider
  sensitivity coefficients. Doubling is required inside a Julia
  docstring, where `\f` would be a control character; it is wrong in
  a Markdown file, and the LaTeX had evidently been copied from one to
  the other. 14 lines across 2 files. The Julia string literals in
  `code-generation.md` and `interoperability.md` keep their doubled
  backslashes, which are correct there.

  Documenter cannot catch this — KaTeX renders valid text and the
  build stays warning-free — so it survived until the pages were
  actually published, which only became possible once the
  `devbranch = "develop"` deployment bug was fixed earlier in this
  release.
- **`SymbolicUncertaintiesLatexifyExt` failed to precompile on Julia
  ≥ 1.12.** The M7 stub declared the concrete signature
  `latex(m::SymbolicMeasurement)` and the M8 extension redefined the
  same signature, so loading `Latexify.jl` *overwrote* a method
  instead of adding one. Julia 1.12 turned method overwriting during
  module precompilation from a warning into a hard error
  (`ERROR: Method overwriting is not permitted during Module
  precompilation`), so the extension no longer precompiled — it still
  worked once loaded, which is why the functional tests stayed green.
  The stub is now declared `latex(args...; kwargs...)`, strictly more
  general than the extension's method, so the extension **adds** a
  method. This is the pattern `src/mtk_stubs.jl` already used for
  `propagate_ode` / `uncertainty_ode`, which is why those extensions
  were unaffected. Two regression tests in
  `test/codegen/test_latex_stub.jl` now assert the two methods
  coexist (one in the package, one in the extension) and that
  dispatch on a measurement lands in the extension. Behaviour of
  `latex(m)` itself is unchanged; the fallback's `ArgumentError` now
  also covers unsupported argument types, which previously raised
  `MethodError`. CI would only have caught this on the `"1"` matrix
  entry, not on the 1.10 LTS one.

### Changed

- **`main` is now the only long-lived branch, everywhere.** The
  `develop` integration branch described by `CONTRIBUTING.md` never
  existed on the remote, so every reference to it was dead: CI and
  Documentation workflows triggered on a branch that cannot exist,
  `docs/make.jl`'s `edit_link = "develop"` produced broken
  "Edit on GitHub" links on every docs page, and four
  `github.com/.../blob/develop/...` links in `docs/src/index.md`,
  `docs/src/limitations.md` and `docs/src/sensitivity-analysis.md`
  were 404s. All now point at `main`; `CONTRIBUTING.md` documents the
  actual model (feature branches `NNN-short-kebab-description` merged
  into `main`, which is also the release/tag branch).
- `docs/src/index.md`'s `## Status` section still announced
  "Milestone M0 (v0.0.1) — scaffolding only, no user-facing API is
  exposed" on the published documentation home page, three years of
  milestones out of date. Rewritten to the actual v0.10.0/M10 state
  (25 stabilised exports, links to Getting Started and the
  Methodology Reference) with a forward pointer to M11 — the same
  correction applied to `README.md` in the previous entry.
- `ROADMAP.md`: absorbed a pre-1.0 review into the plan. Adds a
  **Pre-1.0 decisions** section (licence split — already done via
  `NOTICE.md`; package name, which risks objections at General
  registration), four **scope additions to M11** (JCGM Annex H.1–H.4
  plus JCGM 102 as a regression suite written first, correlation in
  the core type, `UncertaintyBudget` as the primary return type, an
  inert `unit` metadata slot), and two new milestones: **M12**
  (opt-in non-throwing dimensional checker on `DynamicQuantities`
  replacing `Unitful`, handling affine temperatures, %/ppm/dB and
  non-fungible homonyms; closed-form Student-t `k`; guards against
  `u_c²` expression blow-up — no default flattening, Giac back-end,
  CSE at `build_function`) and **M13** (second-order term from the
  symbolic Hessian, *bounded* by interval arithmetic or Taylor models,
  certifying the GUM linearisation deterministically where JCGM
  101:2008 only checks it statistically). Three post-1.0 candidates
  are now scheduled milestones and marked as such.
- `ROADMAP.md`: recorded a post-1.0 candidate for a
  **`DynamicQuantities.jl` dimensional backend** alongside
  `Unitful.jl` (type-stable budget rows, uniform quantity type inside
  the `Symbolics` expression tree, and alignment with the unit system
  `ModelingToolkit` actually validates). Out of scope for M11.
- `ROADMAP.md`: added **milestone M11 — linear form over tagged
  sources (v0.11.0)**, the foundation refactor that gives
  `SymbolicMeasurement` a `Dict{SourceId, Num}` of sensitivities to
  independent sources, collapses the binary-operator and `propagate`
  paths into one, and makes correlation a property of the sources
  rather than a user-supplied `Σ`. Breaking by design (still `0.x`).
  Requirements REQ-200 – REQ-208, phases 0–6, brief in `TODO.md`.
  Consequently the "linear-form-in-tagged-sources" line moved out of
  the post-1.0 candidate list in `ROADMAP.md` and
  `docs/src/limitations.md`; the M1 UB-002 note and the M2
  `propagate(f, ms, Σ)` line are marked as superseded by M11.

- Moved the REQ-170 non-warranty clause out of `LICENSE.md` into a
  new, separate `NOTICE.md`. `LICENSE.md` is now the unmodified,
  OSI-approved BSD 3-Clause Licence text only, so license-detection
  tooling (GitHub, SPDX) identifies it cleanly as BSD-3-Clause.
  `README.md` and `docs/src/limitations.md` updated to point at
  `NOTICE.md`.
- `README.md`'s `## Status` section updated from the stale "Milestone
  M0 — v0.0.1, no public API" to the actual v0.10.0/M10 state (25
  stabilised exports, linked from `docs/src/methodology-reference.md`).
  Also replaced two links into the untracked `specs/`/`specification/`
  directories (which never reach GitHub) with a `CONTRIBUTING.md` link
  and, where there was no public equivalent, removed the dead
  reference.
- `docs/make.jl`'s `deploydocs(devbranch = "develop")` and
  `README.md`'s codecov badge URL (`/branch/develop/`) both referenced
  a `develop` branch that was never the actual default branch on
  GitHub (`main`); Documenter's own deployment-criteria check was
  correctly refusing to deploy as a result (`GITHUB_REF` matches
  `devbranch="develop"` → `✘`). Both now point at `main`.

## [0.10.0] — 2026-04-19

### Added — Milestone M10 (Stable-release preparation, pre-1.0)

- **API surface stabilised at 25 exports.** This release
  stages the v1.0.0-candidate contract without yet bumping
  the major version. See
  [`docs/src/methodology-reference.md`](https://s-celles.github.io/SymbolicUncertainties.jl/dev/methodology-reference/).
- **`PrecompileTools.jl`** as a new direct runtime
  dependency (`^1`) with a `@compile_workload` block in
  `src/SymbolicUncertainties.jl` covering the four canonical
  call paths (arithmetic, math functions, `propagate`,
  `uncertainty_budget`). Target: first-call latency
  under 1 second on a warm-precompile run (SC-001,
  documented-not-gated per M10 research R4).
- **Three new documentation pages:**
  - `docs/src/worked-examples.md` — the six canonical
    electrical worked examples (Ohm, voltage divider,
    RC time constant, dissipated power, RLC resonance,
    RC-charge ODE) consolidated into one page
    (REQ-162).
  - `docs/src/methodology-reference.md` — a single-page
    table mapping every one of the 25 exports to its
    JCGM 100:2008 section (REQ-161).
  - `docs/src/limitations.md` expanded with
    non-warranty posture (REQ-170 / REQ-172), waived
    EARS requirements with rationale (REQ-173),
    no-reproduction audit conclusion (REQ-176),
    performance notes, and post-1.0 candidates list.
- **`CITATION.bib`** at the repository root with two
  BibTeX entries: `@software{SymbolicUncertaintiesjl, …}`
  and `@techreport{JCGM100-2008, …}` (REQ-177).
- **`README.md`** non-warranty `> [!WARNING]`
  admonition immediately after the package description
  (REQ-172).
- **Three new CI-gated audit tests** under
  `test/package/`:
  - `test_banned_terms.jl` — scans
    README/CHANGELOG/docs/src/src/ext for
    case-insensitive matches of the three banned
    phrases `GUM-compliant`, `GUM-certified`,
    `accredited`. Zero matches required (REQ-171).
  - `test_citation_bib.jl` — validates the
    `CITATION.bib` structure (REQ-177).
  - `test_api_freeze.jl` — iterates EARS Appendix A
    (25 symbols after the M10 reconciliation);
    asserts every symbol is exported, has a non-empty
    docstring, and cites a JCGM / GUM Supplement /
    EA-4/02 / Symbolics reference (REQ-160 + REQ-132).
- **One new smoke test** at
  `test/smoke/test_precompile_workload.jl` exercising
  the four canonical call paths and confirming
  `PrecompileTools` is a direct dependency.
- **`specification/ears.md` Appendix A** reconciled to
  match the live 25-symbol surface: added rows for
  `uncertainty_ode`, `JuliaTarget`, `CTarget`; updated
  the `substitute` row to clarify it is a method on
  `Symbolics.substitute` (research R7).
- Docstrings added to the `JuliaTarget` and `CTarget`
  re-exports and extended on `latex` (stub) and
  `to_expr` to satisfy REQ-160 citation regex.
- Legal-wording hygiene: replaced "accredited
  calibration software" phrasings across
  `docs/src/index.md`, `docs/src/getting-started.md`,
  `docs/src/limitations.md`, and `src/type.jl` with
  JCGM-paraphrase-compliant wording. No user-visible
  behaviour change.

### Changed — Milestone M10

- Bumped version from `0.9.0` to `0.10.0` (MINOR bump).
  The public API is stabilised in this release as a
  v1.0.0 candidate; the major bump is deferred until
  post-release soak confirms there are no breaking
  adjustments needed.

### Added — Milestone M9 (ModelingToolkit ODE integration)

- New weakdep on
  [`ModelingToolkit.jl`](https://github.com/SciML/ModelingToolkit.jl)
  (`^11`) with a corresponding package extension
  `SymbolicUncertaintiesModelingToolkitExt`. Activates on
  `using ModelingToolkit`. Traces EARS REQ-080.
- Two new exports (total now 25):
  - `propagate_ode(sys, uncertain_params)` — takes a
    `ModelingToolkit.System` and a vector of uncertain
    parameters as `SymbolicMeasurement`s, returns a
    `Vector{SymbolicMeasurement}` of length
    `length(unknowns(sys))`. Each element's `err` is the
    symbolic GUM combined uncertainty
    `sqrt(Σⱼ (∂uᵢ/∂pⱼ)² · σⱼ²)` where the sensitivity
    symbols are time-dependent variables `∂uᵢ_∂pⱼ(t)`.
    Traces EARS REQ-081, GUM Supplement 3.
  - `uncertainty_ode(sys, uncertain_params)` — returns an
    augmented `ModelingToolkit.System` with `N + K·N`
    unknowns (original states + forward-sensitivity
    states, state-major param-minor) and the corresponding
    forward-sensitivity equations
    `d(∂uᵢ/∂pⱼ)/dt = Σ_k (∂fᵢ/∂u_k)·(∂u_k/∂pⱼ) + ∂fᵢ/∂pⱼ`.
    Directly consumable by `ODEProblem` / `solve` from
    `OrdinaryDiffEq.jl`. Traces EARS REQ-082.
- Eager stubs for both functions in `src/mtk_stubs.jl`:
  without the extension loaded, both raise
  `ArgumentError` pointing at `using ModelingToolkit`.
- New docs page `docs/src/ode-integration.md` walking
  through the RC-charge worked example end-to-end
  (spec User Story 3, EARS §10 / GUM Supplement 3).
- New test subdirectory `test/ext_modelingtoolkit/` with
  8 `@testitem`s covering: signature, RC-charge symbolic
  err, missing-parameter error path, empty-uncertain-
  params edge case, augmented-system shape, state
  ordering, the **SC-003 numeric exit gate**
  (`u(50τ) ≈ Vin` within `rtol = 1e-6` via `Tsit5()`),
  and docs-page presence.
- Test-only deps added: `ModelingToolkit` (^11),
  `OrdinaryDiffEq` (^6) — only used by the new M9 tests
  and the numeric exit gate.

### Added — Milestone M8 (package extensions)

- `SymbolicUncertaintiesLatexifyExt` — activates on
  `using Latexify`. Replaces the M7 `latex(m)` stub with a
  `Latexify.latexify`-backed implementation returning
  `"$(latexify(m.val)) \\pm $(latexify(m.err))"`. Traces
  REQ-072, REQ-131 row 1.
- `SymbolicUncertaintiesMeasurementsExt` — activates on
  `using Measurements`. Adds
  `Measurements.Measurement(m::SymbolicMeasurement)`
  constructor that unwraps both fields via `Symbolics.value`
  or `toexpr+eval` and wraps as
  `Measurements.measurement(val, err)`. Raises
  `ArgumentError` for still-symbolic measurements
  recommending `substitute` first. `m.dof` is not carried
  across. No auto-promotion from `substitute` — explicit
  conversion only (research R8). Traces REQ-121, REQ-131
  row 2.
- `SymbolicUncertaintiesUnitfulExt` — activates on
  `using Unitful`. Adds
  `±(a::Unitful.Quantity, b::Unitful.Quantity)` method
  that validates matching dimensions, raising
  `Unitful.DimensionError` on mismatch; otherwise wraps
  both quantities as a `SymbolicMeasurement`. Traces
  REQ-100, REQ-101, REQ-102, REQ-131 row 4.
- `SymbolicUncertaintiesDataFramesExt` — activates on
  `using DataFrames`. Opt-in via the new `as = :dataframe`
  keyword on `uncertainty_budget` — when DataFrames.jl is
  loaded the call returns a `DataFrame` with the EA-4/02
  column layout. Requesting `as = :dataframe` without
  DataFrames raises `ArgumentError`. The default remains
  `as = :namedtuple`, preserving M3 backward compatibility.
  Traces REQ-044, REQ-131 row 5.
- REQ-132 audit: `test/smoke/test_module_loads.jl` now
  asserts explicitly that no canonical `Symbolics.jl`
  names (`@variables`, `simplify`, `derivative`,
  `gradient`, `jacobian`, `substitute`, `get_variables`,
  `Num`, `value`, `toexpr`, `symbolic_solve`,
  `build_function`) leak into the `SymbolicUncertainties`
  public surface. The two M7 documented exceptions
  (`JuliaTarget`, `CTarget`) remain.
- Minor internal refactor of `src/budget.jl` — extracted
  `_uncertainty_budget_rows` helper (research R4) so the
  DataFrames extension's hook can share the row-
  construction logic.
- Two new documentation pages:
  `docs/src/interoperability.md` (Latexify / Measurements /
  DataFrames) and `docs/src/dimensional-analysis.md`
  (Unitful / IEC 60359).
- 451/451 tests green; zero new mandatory runtime
  dependencies; four new `[weakdeps]` entries in
  `Project.toml` joining the M2.5 Giac entry.

### Changed

- `uncertainty_budget` gains a new
  `as::Symbol = :namedtuple` keyword. Default preserves M3
  behaviour (returns `Vector{NamedTuple}`);
  `as = :dataframe` triggers the DataFrames extension path.
  The EARS REQ-044 "DataFrame if DataFrames.jl is loaded"
  wording is satisfied via this opt-in mechanism to preserve
  backward compatibility for M3 consumer code that assumes
  the NamedTuple return type.

### Added — Milestone M7 (code generation and LaTeX stub)

- `build_evaluator(m, variables; target = JuliaTarget(), fname = :evaluate_measurement)`
  — compile the `(m.val, m.err)` computation to a Julia
  callable (default) or emit C source as a `String` via
  `target = CTarget()`. Internally dispatches to
  `Symbolics.build_function` with `expression = Val{false}`
  for runtime-compiled Julia callables. Traces REQ-070,
  REQ-071. Empty-variables fast path for fully-numeric
  measurements. Sub-100 ns per call on typical GUM
  measurements (docs-only benchmark; not CI-gated).
- `to_expr(m)` — one-line escape hatch returning
  `Tuple{Num, Num}` of `(m.val, m.err)` for downstream
  symbolic pipelines. `m.dof` is not included. Traces
  REQ-073.
- `latex(m)` — **M7 stub** raising `ArgumentError`
  pointing at `Latexify.jl` and cross-referencing the M4
  `Base.show(io, MIME"text/latex", m)` method. Full
  implementation lands as an
  `SymbolicUncertaintiesLatexifyExt` package extension in
  **M8** (REQ-072 deferred).
- `JuliaTarget` and `CTarget` re-exported from
  `Symbolics.jl` for user-facing dispatch ergonomics.
- New documentation page `docs/src/code-generation.md`
  covering Julia compilation, C-source emission, the
  `to_expr` escape hatch, the `latex(m)` stub, and a
  hand-rolled calibration-certificate example.
- `upstream-bugs.md` UB-004 — Symbolics 7 lacks
  `FortranTarget`. Scope narrowed in M7 (JuliaTarget +
  CTarget only). Upstream escalation suggested.

Exported public surface grows from 18 names at M6 exit to
**23** at M7 exit (three new functions + two re-exports).
Zero new mandatory runtime dependencies. Bumps version
0.6.0 → 0.7.0 per SemVer MINOR (strictly additive public
API).

### Added — Milestone M6 (linearity diagnostics)

- `check_linearity(f, measurements; values = nothing)` —
  GUM §5.1.1 linearity-assumption diagnostic. Returns a
  `Dict{Num, Num}` keyed by σ-variables, mapping each to
  the symbolic nonlinearity indicator
  `ηᵢ = (∂²f/∂xᵢ²)·σᵢ² / (2·∂f/∂xᵢ·σᵢ)` (REQ-180). Reuses
  the M2 `_safe_derivative` helper for both first and
  second partials.
- REQ-181 runtime `@warn` fires when `values` substitutes
  the indicator to a concrete `Float64` whose `|ηᵢ|`
  exceeds the fixed `0.1` threshold. The message cites
  REQ-181 and recommends Monte Carlo via
  `MonteCarloMeasurements.jl` / JCGM 101:2008.
- REQ-182 pure-observer invariant: running
  `check_linearity` does **not** modify any M1..M5
  propagation output. Asserted by
  `test/linearity/test_no_higher_order_correction.jl`.
- REQ-155 exit-gate test: `check_linearity(a -> 2a + 3, …)`
  returns `η = 0` symbolically; `check_linearity(a -> exp(a), …)`
  at `x=1, σx=0.1` evaluates to `|η| ≈ 0.05`, at `σx=0.5`
  to `|η| ≈ 0.25` (warning-worthy).
- New documentation page
  `docs/src/linearity-check.md` walking through the
  linear-vs-nonlinear contrast, the threshold warning, the
  no-higher-order-correction invariant, and the diagonal-
  only scope limitation.
- `docs/src/limitations.md` §"Linearity assumption" updated
  to cross-link to the new page, replacing the
  "forthcoming" placeholder wording.
- Zero new runtime dependencies. Exported public surface
  grows from 17 at M5 exit to **18** at M6 exit (one new
  name, `check_linearity`).

**Deferred (documented in spec Assumptions):**

- Mixed partial derivatives `∂²f/∂xᵢ∂xⱼ` — diagonal entries
  only for M6. Strongly-coupled measurands should use
  Monte Carlo.
- Threshold exposed as a keyword — fixed at `0.1` per
  REQ-181.
- Numerical fallback on second-derivative failure —
  `ArgumentError` per constitution Principle III.

### Added — Milestone M5 (protocol optimisation and inverse inference)

- `infer_precision(m, σᵢ, target_uc)` — symbolic inverse
  operation. Solves `m.err == target_uc` for `σᵢ` via a
  closed-form algebraic split of the GUM-standard quadratic
  `m.err² = cᵢ²·σᵢ² + others²` — no general-purpose polynomial
  solver required, **no `Nemo.jl` dependency**. Traces
  REQ-090.
- `infer_all_precisions(m, variables, sigmas, target_uc)` —
  worst-case single-source precision table via the closed-
  form shortcut `σᵢ* = target_uc / |cᵢ|` (research R4). Traces
  REQ-092.
- `required_precision(m, σᵢ, target_uc)` — one-line delegate
  to `infer_precision` per research R6. Preserves the
  "precision condition" framing of EARS REQ-060 alongside the
  REQ-090 "solved equation" framing. Traces REQ-060, REQ-062.
- `budget_allocation(m, variables, sigmas, total_budget)` —
  Lagrange-multiplier optimal allocation via the closed-form
  inverse-sensitivity-squared weighting
  `σᵢ* = total_budget · (1/cᵢ²) / Σⱼ (1/cⱼ²)`. No solver
  dependency. Traces REQ-061, REQ-062.
- `ArgumentError` failure path (REQ-091) fires when the
  algebraic split cannot isolate σᵢ (e.g. transcendental
  measurands), when the target is negative, or when the
  supplied variable does not appear in `m.err`.
- Two new documentation pages:
  `docs/src/inverse-inference.md` (headline solve +
  worst-case table + RLC-resonance exit gate) and
  `docs/src/protocol-optimisation.md` (required-precision
  inequality framing + budget-allocation examples).
- Zero new mandatory runtime dependencies. `Nemo.jl` is
  recommended in docstring notes for users who want to try
  `Symbolics.symbolic_solve` directly for non-quadratic
  cases, but the default M5 pipeline does **not** require it.
- Exported public surface grows from thirteen at M4 exit to
  **seventeen** at M5 exit (four new names).

### Added — Milestone M4 (LaTeX display, numeric substitution, and safety warnings)

- `Symbolics.substitute(m::SymbolicMeasurement, dict::AbstractDict)`
  — extends the upstream `Symbolics.substitute` with a method
  that rewrites `val`, `err`, and (when set) `dof` via the
  replacement dictionary. Silently ignores extra keys
  (REQ-122), supports partial substitution, preserves
  `dof === nothing`, and does **not** re-apply the REQ-005
  negativity guard (Clarifications Q3). Traces REQ-120 /
  REQ-122 / REQ-123 / REQ-142.
- `Base.show(io::IO, ::MIME"text/latex", m::SymbolicMeasurement)`
  — emits `$val \pm err$` with inline math delimiters included
  (Clarifications Q1), so Jupyter and Pluto render the output
  as math without caller effort. A minimal in-library
  formatter handles concrete numerics via `string(raw)` and
  falls back to `Base.string(expr)` for symbolic expressions.
  Traces REQ-112.
- Runtime `@warn` on division-by-zero (REQ-140) when the
  denominator's `.val` cannot be proven nonzero via the
  `Symbolics.value + isa Real` rule (Clarifications Q2).
  Wired into the M1 `Base.:/` binary operator; mixed-mode
  `/` dispatches through the same path; propagate-path
  coverage via a syntactic walker in `src/safety.jl`
  (`_warn_unsafe_ops_in`).
- Runtime `@warn` on `sqrt`, `log`, `log2`, `log10` applied to
  a measurement whose `.val` cannot be proven strictly
  positive (REQ-141). Wired into the M2 elementary-function
  overloads in `src/math.jl`; propagate-path coverage reuses
  the same syntactic walker.
- Safety helpers `_has_provable_value`, `_warn_division_by_zero`,
  `_warn_domain`, and `_warn_unsafe_ops_in` in `src/safety.jl`
  (internal, not exported).
- New documentation page `docs/src/display-substitute-safety.md`
  covering `substitute`, the LaTeX rendering, the two safety
  warnings, the three silencing options, and the upstream
  `Symbolics.jl` assumptions-API gap recorded in
  `upstream-bugs.md` UB-003.
- `upstream-bugs.md` UB-003 — records the `Symbolics.jl`
  ecosystem gap (no `assume` / `additionally` framework for
  positivity queries) that drives the conservative
  over-warning behaviour of the REQ-140 / REQ-141 checks.
- `Symbolics.substitute` extension is **not** exported from
  `SymbolicUncertainties` — the exported public surface remains
  thirteen names (unchanged from M3). Users call it via
  `using Symbolics; substitute(m, dict)`, matching the
  standard convention for extending an upstream function.
- Zero new mandatory runtime dependencies — all functionality
  built on the existing `Symbolics.jl` API (`substitute`,
  `value`, `toexpr`, `unwrap`, `SymbolicUtils.iscall`,
  `SymbolicUtils.operation`, `SymbolicUtils.arguments`).

### Behavioural changes (pre-1.0 MINOR, documented)

- The M1 `Base.:/(SymbolicMeasurement, SymbolicMeasurement)`
  and the M2 `sqrt` / `log` / `log2` / `log10` overloads now
  emit informational `@warn`s when their operand's `.val`
  cannot be proven safe at build time. The returned
  `SymbolicMeasurement` is unchanged — the warnings are
  non-halting. Downstream tests that happened to divide by or
  apply these functions to plain-symbolic operands will now
  see warnings on their stderr; they do not fail unless wrapped
  in `Test.@test_nowarn` or `Test.@test_logs` that assert the
  absence of warnings.

### Added — Milestone M3 (uncertainty budget, expanded uncertainty, and Welch-Satterthwaite)

- `sensitivity_coefficient(m, xᵢ)` — symbolic
  `cᵢ = ∂(m.val)/∂xᵢ` per JCGM 100:2008 §5.1.3 equation (11b)
  (REQ-040). Returns `Num(0)` for a variable absent from the
  measurand; propagates the REQ-021 `ArgumentError` when the
  symbolic engine cannot resolve a closed-form derivative.
- `uncertainty_contribution(m, xᵢ, σᵢ)` — symbolic
  `|cᵢ|·σᵢ` per JCGM 100:2008 §5.1.3 equation (11a) (REQ-041).
- `relative_sensitivity(m, xᵢ, σᵢ)` — fractional variance
  contribution `(cᵢ·σᵢ)² / u_c²(y)` per JCGM 100:2008 §5.1.6;
  EA-4/02 §7.3 "percentage-of-variance" column (REQ-042). Sums
  to `1` over the full input set for uncorrelated inputs —
  the M3 variance-decomposition invariant (REQ-045 / REQ-152).
- `uncertainty_budget(m, variables, sigmas)` — one-call
  EA-4/02 §7.3 budget table returning `Vector{NamedTuple}` with
  row schema `(variable, sigma, sensitivity, contribution,
  relative)` (REQ-044).
- `expanded_uncertainty(m, k=2)` — JCGM 100:2008 §6.2 equation
  (18) expanded uncertainty with EA-4/02's default coverage
  factor `k = 2` (REQ-050). Preserves `val` and `dof`; negative
  numeric `k` raises `ArgumentError`.
- `expanded_uncertainty(m; coverage_probability)` — derives `k`
  from `m.dof` via an internal Student-t quantile table (GUM
  100:2008 Table G.2 verbatim) for
  `coverage_probability ∈ {0.68, 0.90, 0.95, 0.99}` (REQ-051,
  REQ-174). Emits the REQ-175 runtime `@warn` when a numeric
  `ν_eff < 30` triggers the t-quantile path, and diagnostic
  `@info` when `m.dof` is `nothing` or symbolic and the
  normal-quantile fallback is used.
- `welch_satterthwaite(contributions, dofs)` — effective degrees
  of freedom per JCGM 100:2008 §G.4 equation (G.2b) (REQ-052,
  REQ-174). `DimensionMismatch` on length mismatch.
- `dominant_source(m, variables, sigmas; values=nothing)` —
  EA-4/02 §7.3 convenience returning the dominant variance
  contributor as a `NamedTuple`. Symbolic path returns the first
  variable with an `@info` about order-dependence; numeric path
  runs `argmax` on the substituted contributions (REQ-043).
- Two new documentation pages, `docs/src/uncertainty-budget.md`
  and `docs/src/expanded-uncertainty.md`, covering all seven
  new exports with worked examples on the voltage-divider case
  (REQ-161 rows "Uncertainty Budget" and "Expanded Uncertainty").
  The `expanded_uncertainty` and `welch_satterthwaite` docstrings
  include the REQ-174 `!!! warning "Coverage factor assumptions"`
  admonition block.
- Zero new mandatory runtime dependencies — the Student-t
  quantile lookup table is internal to `src/expanded.jl` and
  only occupies four 30-row `Dict{Int, Float64}`s.
- Exported public surface grows from six names (at M2.5) to
  thirteen at M3 exit.

### Added — Milestone M2.5 (Giac CAS extension)

- Package extension `SymbolicUncertaintiesGiacExt` that activates when
  [`Giac.jl`](https://github.com/PhysicsGroup/Giac.jl) is loaded. It
  overloads the internal `_simplify_for_report` hook (introduced at
  the end of M2) to route the simplification of propagated `err`
  fields through Giac's CAS via the
  `Symbolics → Giac → simplify → Symbolics` round-trip
  (REQ-131 row 6).
- Giac declared in `[weakdeps]` + `[extensions]` in `Project.toml`;
  no impact on users who do not load Giac.
- Defensive fallback: if Giac raises or returns something the
  round-trip cannot reconvert, `Symbolics.simplify` is used instead,
  so every pre-existing assertion remains valid.
- New documentation section in **Sensitivity Analysis** describing
  the optional integration, including the `-tan(x) + sin(x)/cos(x)`
  trigonometric identity reduction as a worked example.
- Regression: all 170 M0/M1/M2 tests remain green with Giac loaded;
  8 new Giac-specific tests bring the total to 178/178.

### Added — Milestone M2 (math functions and multi-variable propagation)

- Sixteen elementary mathematical functions overloaded for
  `SymbolicMeasurement` arguments (`sin`, `cos`, `tan`, `asin`,
  `acos`, `atan`, `sinh`, `cosh`, `tanh`, `exp`, `log`, `log2`,
  `log10`, `sqrt`, `abs`, `inv`), each propagating uncertainty via
  the GUM §5.1.2 sensitivity-coefficient formula
  `u(f(x)) = |∂f/∂x| · u(x)` with the partial derivative obtained
  from `Symbolics.derivative` (REQ-020).
- `apply(f, m::SymbolicMeasurement; derivative = nothing)` —
  escape hatch for functions whose derivative the symbolic engine
  cannot find. With no `derivative` keyword, delegates to
  `propagate(f, [m])`. With an explicit `derivative` (a symbolic
  expression in `m.val`), uses it directly (REQ-021, REQ-022).
- `propagate(f, ms)` — multi-variable closed-form propagation
  for uncorrelated inputs, implementing JCGM 100:2008 §5.1.2
  equation (10) for an arbitrary user function `f` of any number
  of `SymbolicMeasurement` arguments (REQ-030).
- `propagate(f, ms, Σ)` — second method overload accepting a
  symbolic covariance matrix, implementing the correlated form of
  the law of propagation, JCGM 100:2008 §5.2.2 equation (13),
  including all cross-covariance terms. Validates `Σ` shape and
  raises `DimensionMismatch` on bad input (REQ-031, REQ-032).
- `propagate_vector(f, ms)` — vector-valued multi-output
  propagation following JCGM 102:2011 (GUM Supplement 2). Returns
  a `Vector{SymbolicMeasurement}` with marginal `err` derived
  from the symbolic Jacobian. Cross-output covariance is not
  exposed at M2 and is reserved for a follow-up milestone
  (REQ-033).
- New **Sensitivity Analysis** documentation page walking through
  `apply`, `propagate`, and `propagate_vector` with the
  voltage-divider worked example (REQ-161 row "Sensitivity
  Analysis").
- Shared `AsFloat` `@testsnippet` factored out of M1 test files
  for symbolic-to-numeric evaluation in equivalence assertions.

### Fixed

- The M1 binary-operator identity-tracking limitation
  (`upstream-bugs.md` UB-002) is now resolvable by routing repeated
  operands through `propagate(f, [m])`. `propagate(x -> x - x, [m])`
  returns `0 ± 0`, `propagate(x -> x / x, [m])` returns `1 ± 0`,
  and `propagate(x -> x*x*x - x^3, [m])` returns `0 ± 0`. The M1
  binary operators are unchanged; the documentation now points
  users at `propagate` for any expression with repeated inputs.

### Added — Milestone M1 (carried over)

- `SymbolicMeasurement` type with `val`, `err`, and optional `dof`
  fields (REQ-001, REQ-002, REQ-006).
- Infix constructor `±` for any combination of `Symbolics.Num` and
  `Number` operands, and a two-argument numeric constructor that
  promotes plain literals to `Num` (REQ-003, REQ-004).
- Negative-uncertainty guard on the numeric constructor that raises
  `ArgumentError` citing GUM §4.3.1 (REQ-005).
- Binary arithmetic operators `+`, `-`, `*`, `/`, `^` on two
  `SymbolicMeasurement`s, implementing the GUM §5.1
  uncorrelated-propagation formulas with `Symbolics.simplify`
  applied to the `err` field after each operation (REQ-010..REQ-014,
  REQ-110).
- Mixed-mode binary arithmetic between a `SymbolicMeasurement` and a
  plain `Number` or bare `Symbolics.Num`, via zero-uncertainty
  wrapping (REQ-015).
- `Base.show` method producing `val ± err` in Unicode, with an ASCII
  `val +/- err` fallback under `IOContext(io, :unicode => false)`
  (REQ-111).
- Getting Started documentation page walking through construction,
  the five binary operators, and the Ohm's-law worked example
  (`R = V/I`) — the milestone's exit gate (REQ-161 row 1,
  ROADMAP M1 exit criterion).

## [0.0.1] — 2026-04-15

### Added

- Project scaffolding for Milestone **M0 — Project bootstrap**
  per [`ROADMAP.md`](ROADMAP.md) and
  [`specs/001-project-bootstrap/`](specs/001-project-bootstrap/).
- `Project.toml` declaring `Symbolics.jl` as the sole mandatory
  runtime dependency and requiring Julia ≥ 1.10 (REQ-130, REQ-156).
- `src/SymbolicUncertainties.jl` module skeleton and `src/docstrings.jl`
  with `DocStringExtensions` templates reserving slots for JCGM,
  IEC, and EA references (REQ-160 groundwork).
- Test harness wired to `TestItemRunner.jl` with smoke and
  package-hygiene items (`Aqua`, `JuliaFormatter`, `Documenter`
  doctest).
- `docs/` skeleton built with `Documenter.jl`; warning-free `make.jl`
  and a registered table of contents (`docs/pages.jl`). Includes
  `docs/src/index.md` with the regulated-use disclaimer and a
  `docs/src/limitations.md` stub covering the REQ-173 topics.
- GitHub Actions workflows:
  - `CI.yml` — test matrix on Julia 1.10 (LTS) and latest stable on
    Ubuntu, with Codecov upload (REQ-157).
  - `Documentation.yml` — Documenter build + GitHub Pages deploy on
    pushes to `main` and on tagged releases (REQ-158).
  - `TagBot.yml` — automatic release tagging via
    `JuliaRegistries/TagBot` (REQ-159).
- `LICENSE.md` combining the MIT Licence with the verbatim REQ-170
  non-warranty clause.
- `.JuliaFormatter.toml` pinning an 80-column margin and disabling
  trailing whitespace; `.pre-commit-config.yaml` for local
  formatter / whitespace enforcement.
- `README.md` with the regulated-use disclaimer, a contributor
  quickstart, and placeholders for CI / docs / coverage badges.
- Project constitution at `.specify/memory/constitution.md` (v1.0.0)
  codifying the five core principles — Test-First, Standards
  Traceability, Purely Symbolic Computation, Documentation as Code,
  and Semantic Versioning & Reproducible Releases.

### Notes

- **No user-facing API** is exposed in this release. The public
  symbol surface is intentionally empty and is enforced by the
  smoke test item; the first exported symbols land in M1 per
  `ROADMAP.md`.

[Unreleased]: https://github.com/s-celles/SymbolicUncertainties.jl/compare/v0.0.1...HEAD
n### Added
- **CausalGraphs.jl Integration**: `SymbolicUncertaintiesCausalGraphsExt` weak dependency extension providing `parse_measurement_model` (Scaffolding Mode) and `evaluate_measurement_model` (Full-Auto Mode) for generating uncertainty budgets directly from causal graphs/Ishikawa diagrams.
[0.0.1]: https://github.com/s-celles/SymbolicUncertainties.jl/releases/tag/v0.0.1
