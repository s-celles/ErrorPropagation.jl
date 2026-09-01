```@meta
CurrentModule = SymbolicUncertainties
```

# Calibration Certificate

!!! danger "Every certificate this package produces is a specimen"
    `SymbolicUncertainties.jl` is not an calibration
    laboratory. Documents produced here carry a watermark saying so on
    every page, in the header, and across the diagonal. **The watermark
    cannot be switched off** — only reworded, for a laboratory that
    works in another language.

    Issuing a calibration certificate is an act performed by a body
    holding accreditation, under its own quality system. This page produces a
    document in the *shape* the standard requires, which is a drafting
    aid and a checklist — not a certificate.

[`report`](@ref) renders a result. A certificate is the document that
result travels in, and ISO/IEC 17025:2017 §7.8 is prescriptive about
what it must carry.

## Building one

```@example certificate
using SymbolicUncertainties

result = report(99.98, 0.014; symbol = "R", unit = "Ω",
                k = 2, coverage_probability = 0.95)

cert = certificate(
    result;
    identifier = "CAL-2026-0417",
    laboratory = "Laboratoire d'essais, 12 rue de la Mesure, Poitiers",
    location = "Permanent facility, Poitiers",
    customer = "Atelier Dupont & Fils",
    method = "Comparison against a calibrated reference (MP-04)",
    item = "Standard resistor, 100 Ω, s/n 4471-C",
    date_received = "2026-09-01",
    date_performed = "2026-09-03",
    date_issued = "2026-09-05",
    authorised_by = "S. Celles, technical manager",
    conditions = "(23.0 ± 0.5) °C, (45 ± 10) % RH",
    traceability = "Traceable to the SI through reference standard " *
                   "R-118, calibrated by LNE, certificate 2026-3391",
    model = "R = V / I",
    conformity = ConformityStatement(
        "R at 23 °C",
        "Nominal 100 Ω ± 0.1 %",
        :pass;
        decision_rule = "Simple acceptance, guard band w = 0 " *
                        "(ILAC-G8:2019 §4.2.1)",
    ),
)
```

## Missing clauses are printed on the document

A certificate lacking its traceability statement is defective. The
failure mode of a separate checking function is that nobody calls it,
so unmet clauses are rendered **in place**:

```@example certificate
certificate(result; identifier = "DRAFT-1")
```

That turns the type into a working checklist against §7.8. The clauses
it tracks are §7.8.2.1 b), c), e), f), g), h), i), j) and o); §7.8.4.1
b), c) and d); §7.8.6.2 c); and §7.8.4.3.

An empty `cert.findings` means every clause this package can *see* is
filled. Nothing here checks that a traceability statement is true, only
that one was made.

## Two clauses worth knowing about

**§7.8.6.2 c) — a statement of conformity must name its decision
rule.** The rule is what makes a pass/fail statement mean anything: it
fixes how the measurement uncertainty is set against the tolerance
(ILAC-G8). A pass declared without one is not interpretable, so
omitting it produces a finding:

```@example certificate
certificate(
    result;
    identifier = "DRAFT-2",
    conformity = ConformityStatement(
        "R at 23 °C", "Nominal 100 Ω ± 0.1 %", :pass,
    ),
).findings
```

**§7.8.4.3 — a calibration certificate shall not recommend a
calibration interval** unless that was agreed with the customer or is
required by law. The interval depends on how the instrument is used and
on the customer's own risk, which the calibrating laboratory does not
know. Stating one records a finding unless `interval_agreed = true`.

## From a model, with units

With `DynamicQuantities` loaded, the result and its unit are derived
from the measurement model:

```@example certificate
using Symbolics, DynamicQuantities

@variables V I σV σI
R = (V ± σV) / (I ± σI)

readings = Dict(
    V => 10.000us"V", σV => 1e-3us"V",
    I => 0.10002us"A", σI => 1e-5us"A",
)

certificate(
    R, readings;
    symbol = "R", k = 2, coverage_probability = 0.95,
    identifier = "CAL-2026-0418",
    laboratory = "Laboratoire d'essais, Poitiers",
    traceability = "SI via LNE certificate 2026-3391",
    model = "R = V / I",
).result
```

## LaTeX

`latex(cert)` returns a complete document — `\documentclass` through
`\end{document}` — that compiles with `pdflatex` and no package
installation beyond a standard TeX distribution:

```julia
write("certificate.tex", latex(cert))
# pdflatex certificate.tex
```

The watermark is applied with `eso-pic` to every shipped page, sized
against the paper rather than by a fixed factor, so a longer wording
does not run off the edge. Each page carries the certificate number and
`Page n of m` (§7.8.2.1 d), and the document ends with an explicit
*End of certificate*.

LaTeX-special characters in the fields you supply are escaped, and so
are the ones metrology actually writes: `Ω`, `µ`, `°`, `±`, and unit
exponents like `A⁻¹` or `m²`. `pdflatex` rejects every one of those
even under `utf8` input encoding, and a certificate that does not
compile is worse than one that does not exist — the failure surfaces at
the worst possible moment. The test suite compiles a document
containing all of them whenever a TeX engine is available.

## What this does not do

- It does not check that your traceability statement is true, that your
  method is fit for purpose, or that your laboratory is competent.
  Those are what accreditation assesses.
- It does not compute a conformity verdict. You supply the verdict and
  the decision rule; ILAC-G8 gives several, and choosing between them
  is a risk decision belonging to the laboratory and its customer.
- It does not include the uncertainty budget in the document. Build one
  with [`uncertainty_budget`](@ref) and add it alongside if your
  quality system calls for it.

## API reference

```@docs
certificate
CalibrationCertificate
ConformityStatement
CertificateFinding
latex(::CalibrationCertificate)
```
