```@meta
CurrentModule = SymbolicUncertainties
```

# Power & Resistance Measurement: a Metrology Walkthrough

This tutorial is a full metrological worked example of
measuring the electrical power dissipated in a precision
resistor and assessing conformity of the resistor against
its nominal value. It ties GUM methodology (JCGM 100:2008)
to VIM vocabulary (JCGM 200:2012) and shows how the
`SymbolicUncertainties.jl` API fits the calibration-certificate
workflow end-to-end.

Unlike the single-section summaries in [Worked Examples](worked-examples.md),
this page walks through a complete uncertainty budget,
coverage-interval construction, conformity assessment, and
reporting — the sequence a calibration lab would follow in
practice.

## VIM terms used in this tutorial

| VIM § | Term | Role here |
|-------|------|-----------|
| 2.3 | **Measurand** | The quantities we want — `R` (resistance of the device under test) and `P` (power dissipated). |
| 2.10 | **Measured quantity value** | The numerical result of the measurement — `R_meas`, `P_meas`. |
| 2.11 | **Nominal quantity value** | The rated / stamped value `R₀ = 100 Ω` (E96 series). |
| 2.16 | **Measurement error** | `R_meas − R₀` (unknown exactly; bounded by uncertainty). |
| 2.26 | **Measurement uncertainty** `u(y)` | Standard uncertainty on the result. |
| 2.35 | **Coverage probability** | Here `p = 0.95`, i.e. 95 % confidence. |
| 2.36 | **Coverage interval** | The interval `y ± U`, where `U = k · u(y)`. |
| 2.37 | **Coverage factor** | `k = 2` for `p ≈ 0.95` under a normal distribution (GUM §6.3.3). |
| 4.17 | **Conformity assessment** | Decision: is the device within its specification limits? |
| 4.18 | **Calibration certificate** | The reporting artifact — see final section. |

For full VIM definitions see JCGM 200:2012; this tutorial
paraphrases only.

## Scenario

A calibration lab receives a **precision resistor** rated
at `R₀ = 100 Ω` (an E96 series value) with a manufacturer
tolerance of ±0.1 %. The lab applies a stable voltage
source and measures both voltage across and current through
the resistor using calibrated instruments:

- **Voltmeter** across the resistor — reading `V = 10.000 V`
  with `σV = 0.001 V` (1 mV standard uncertainty).
- **Ammeter** in series — reading `I = 0.100 02 A` with
  `σI = 1.0 × 10⁻⁵ A` (10 μA standard uncertainty).

The lab needs to deliver:

1. `P` — power dissipated, with uncertainty `u(P)`.
2. `R_meas` — resistance inferred from Ohm's law, with
   uncertainty `u(R)`.
3. A **conformity assessment** — is `R_meas` consistent
   with `R₀ = 100 Ω` at 95 % coverage?

Inputs are treated as independent (no correlated drift
between the voltmeter and ammeter readings) — a standard
JCGM 100:2008 §5.1.2 eq (10) setup.

## Build the measurement models

```@example power-resistance-metrology
using SymbolicUncertainties
using SymbolicUncertainties: ±
using Symbolics
using DynamicQuantities

# Symbolic inputs — values and standard uncertainties
@variables V I σV σI

# Model 1: power P = V · I
P = propagate((v, i) -> v * i, [V ± σV, I ± σI])
# P.val = V * I
# P.err = sqrt((I·σV)² + (V·σI)²)   — uncorrelated-inputs form

# Model 2: resistance R = V / I
R = propagate((v, i) -> v / i, [V ± σV, I ± σI])
# R.val = V / I
# R.err = sqrt((σV/I)² + (V·σI/I²)²)
```

`propagate` is used (rather than the binary `*` / `/`
operators) because the underlying sensitivity analysis is
explicit and the result is guaranteed to collapse
repeated symbolic-variable occurrences — see
[Sensitivity Analysis](sensitivity-analysis.md).

## Power budget

```@example power-resistance-metrology
P_rows = uncertainty_budget(P, [V, I], [σV, σI])
# An UncertaintyBudget of 2 rows — one per input.
# Columns: variable, sigma, sensitivity, contribution,
#          relative (fraction of variance).
```

Each row follows the GUM §5.1.6 / EA-4/02 §7.3 schema.
Substituting numerics:

```@example power-resistance-metrology
readings = Dict(
    V => 10.000us"V", σV => 1e-3us"V",
    I => 0.10002us"A", σI => 1e-5us"A",
)

# Several calls below rank or substitute plain numbers, so the same
# readings are also kept stripped.
dict = Dict(k => ustrip(v) for (k, v) in readings)

# The unit of the answer is derived from the model, not asserted:
# volts times amperes is watts, and nothing here had to say so.
evaluate(P, readings)
```

**Dominant source**:

```@example power-resistance-metrology
dominant = dominant_source(P, [V, I], [σV, σI];
                           values = dict)
# → returns `V` or `I`; in this setup they contribute
#   nearly equally (1.00e-8 each), so the dominant source
#   depends on tie-breaking.
```

This is a **balanced budget** — a deliberate choice in
the scenario design. Real calibration work usually
reveals one dominant source on which to focus
improvements.

## Resistance budget

```@example power-resistance-metrology
R_rows = uncertainty_budget(R, [V, I], [σV, σI])

# Volts over amperes is ohms — again derived, not stated:
evaluate(R, readings)
```

## Coverage interval (VIM §2.36)

Expand `u(R)` to a coverage interval with `k = 2`
(p ≈ 0.95, assuming approximate normality per GUM §6.3.3):

```@example power-resistance-metrology
R_expanded = expanded_uncertainty(R, 2)
# R_expanded.val = R.val        (unchanged)
# R_expanded.U = 2 · R.err

R_exp_num = Symbolics.substitute(R_expanded, dict)
# R_exp_num.val ≈ 99.98  Ω
# R_exp_num.U ≈ 2 · 14 mΩ ≈ 28 mΩ
```

The **coverage interval** is therefore
`[99.98 − 0.028, 99.98 + 0.028] Ω = [99.952, 100.008] Ω`.

## Conformity assessment (VIM §4.17)

**Question**: is `R_meas = 99.98 Ω` consistent with
`R₀ = 100 Ω` at 95 % coverage?

```julia
R₀ = 100.0
lower = R_exp_num.val - R_exp_num.U
upper = R_exp_num.val + R_exp_num.U
pass = lower ≤ R₀ ≤ upper
# → true : R₀ = 100 ∈ [99.952, 100.008]  ✓
```

**Result**: `R₀` lies inside the 95 % coverage interval,
so the resistor is **consistent with its nominal value**
at the 95 % level. The calibration certificate reports
`R = 99.98 Ω ± 0.028 Ω (k = 2, p ≈ 0.95)` and the
conformity status PASS.

### Counter-example — a failing conformity check

Suppose instead the ammeter reading had been
`I = 0.10050 A` (a 0.48 % drift):

```julia
dict_fail = Dict(k => ustrip(v) for (k, v) in Dict(
    V => 10.000us"V", σV => 1e-3us"V",
    I => 0.10050us"A", σI => 1e-5us"A",
))

R_fail = Symbolics.substitute(R_expanded, dict_fail)
# R_fail.val ≈ 99.502 Ω
# R_fail.U ≈ 28 mΩ   (roughly unchanged)
# coverage interval: [99.474, 99.530]

lower_f = R_fail.val - R_fail.U
upper_f = R_fail.val + R_fail.U
pass_f = lower_f ≤ R₀ ≤ upper_f
# → false : R₀ = 100 ∉ [99.474, 99.530]  ✗
```

**Result**: the measured resistance is **inconsistent
with the nominal value** at 95 % coverage. The
certificate reports NON-CONFORM and the device is
tagged for adjustment or rejection.

## Reporting (GUM §7 + VIM §4.18)

A calibration-certificate-ready summary block:

```julia
function report(label, m, k)
    v = Symbolics.value(Symbolics.substitute(m.val, Dict()))
    u = Symbolics.value(Symbolics.substitute(m.err, Dict()))
    # (in practice m is already fully substituted — the
    # `substitute(_, Dict())` round-trip is just defensive)
    println(label, " = ", round(v, sigdigits = 5),
            " ± ", round(k*u, sigdigits = 3),
            "  (k = ", k, ", coverage ≈ ",
            k == 2 ? "95 %" : "…", ")")
end

report("P", P_num, 2)
# P = 1.0002 ± 2.83e-4  (k = 2, coverage ≈ 95 %)

report("R", R_num, 2)
# R = 99.98 ± 2.83e-2   (k = 2, coverage ≈ 95 %)
```

**Certificate excerpt** (human-readable):

> **Device under test**: precision resistor, nominal
> `R₀ = 100.000 Ω` (E96 series).
>
> **Conditions**: `T = 23.0 °C`, applied voltage
> `V_applied ≈ 10 V`.
>
> **Result**:
> - `R = 99.98 Ω ± 0.028 Ω` (`k = 2`, coverage ≈ 95 %).
> - `P = 1.0002 W ± 0.00028 W` (`k = 2`, coverage ≈ 95 %).
>
> **Dominant uncertainty sources**: voltmeter reading
> and ammeter reading contribute approximately equally
> (~50 % each).
>
> **Conformity**: PASS — `R₀ = 100 Ω` lies within the
> 95 % coverage interval `[99.952, 100.008] Ω`.
>
> **Method**: JCGM 100:2008 §5.1.2 eq (10), uncorrelated
> inputs; software implementation:
> `SymbolicUncertainties.jl` v0.10.0.

## What this tutorial demonstrates

- **Symbolic propagation is calibration-ready.** Every
  intermediate expression in this walkthrough is
  symbolic until the final `Symbolics.substitute`,
  giving the lab a traceable derivation of the final
  number.
- **VIM vocabulary maps cleanly to the API**: measurand
  → `SymbolicMeasurement.val`, measurement uncertainty
  → `.err`, coverage interval →
  `expanded_uncertainty(m, k)`, dominant source →
  `dominant_source(...)`.
- **Conformity assessment is a downstream consumer** of
  the coverage interval — the library provides the
  interval; the decision logic (`R₀ ∈ [y-U, y+U]`) is
  two lines of user code.
- **Paraphrase-only** — no normative JCGM / VIM text is
  reproduced in the library or this tutorial. Section
  numbers are cited to anchor the methodology; the
  authoritative document is JCGM 100:2008 / JCGM
  200:2012 itself.

## References

- **JCGM 100:2008** — *Evaluation of measurement data
  — Guide to the expression of uncertainty in
  measurement (GUM)*. BIPM. See `CITATION.bib` at the
  repository root for the BibTeX entry.
- **JCGM 200:2012** — *International vocabulary of
  metrology — Basic and general concepts and
  associated terms (VIM)*, 3rd edition. BIPM.
- **EA-4/02 M:2022** — *Evaluation of the Uncertainty
  of Measurement in Calibration*. European
  co-operation for Accreditation.
- For the full methodology reference of every
  `SymbolicUncertainties.jl` export, see
  [Methodology Reference](methodology-reference.md).
- For the six quick worked examples (Ohm, voltage
  divider, RC time constant, dissipated power, RLC
  resonance, RC-charge ODE), see
  [Worked Examples](worked-examples.md).
