```@meta
CurrentModule = SymbolicUncertainties
```

# Uncertainty Sources

A `SymbolicMeasurement` records **which
independent measurements it derives from, and with what sensitivity**,
rather than carrying a bare uncertainty number. Every combined
uncertainty, sensitivity coefficient, budget and covariance is derived
from that one structure.

This page documents the representation. It is the foundation the
propagation operators are being migrated onto; until that migration
completes, the binary operators keep their earlier behaviour.

## Why provenance is recorded

An uncertainty number alone cannot tell you where it came from. Two
consequences follow, and both are visible to users:

- `x - x` cannot be known to be exactly zero, because the two operands
  are indistinguishable once reduced to a pair of numbers;
- two quantities that are correlated *because they derive from a
  common upstream measurement* cannot be recognised as such, which is
  precisely the case where a user cannot supply a covariance matrix by
  hand.

Recording the sources answers both from the same structure.

## Sources are carried, not registered

The source descriptors and any declared covariances live **in the
quantity**, not in module-level state.

This is deliberate. With a global registry, `Symbolics.substitute`
would have nothing local to substitute into: replacing `σx` with `0.7`
would have to reach shared state, and without that a fully substituted
measurement would no longer yield a number. Carrying the descriptors
keeps substitution purely local — the estimate, each sensitivity, each
source uncertainty, each covariance.

The only global state is a counter that hands out fresh identifiers,
which makes `±` impure in exactly the way `gensym` is: bounded, with
no leakage between sessions, and safe to call from several threads.

```@example uncertainty-sources
using Symbolics, SymbolicUncertainties
@variables V σV

m = V ± σV
SymbolicUncertainties.terms_of(m)     # one source, sensitivity 1
SymbolicUncertainties.sources_of(m)   # its standard uncertainty: σV
```

Each `±` mints a **fresh** source. Two syntactically identical
constructions are two independent measurements — the same `σ` symbol
may perfectly well describe two different resistors of equal
tolerance.

!!! warning "Write each input once, then reuse it"
    The flip side of that rule is a trap. Identity comes from the
    **measurement object**, never from the symbol name, so writing
    `R2 ± σR2` twice in one model declares *two* independent
    resistors that happen to share a tolerance symbol — not one
    resistor used twice.

    ```@example uncertainty-sources
    @variables Vin σVin R1 σR1 R2 σR2

    # WRONG: `R2 ± σR2` appears twice, so R2 is two sources
    wrong = (Vin ± σVin) * (R2 ± σR2) / ((R1 ± σR1) + (R2 ± σR2))
    length(uncertainty_budget(wrong))
    ```

    ```@example uncertainty-sources
    # RIGHT: one object per physical input, reused
    v, r1, r2 = Vin ± σVin, R1 ± σR1, R2 ± σR2
    right = v * r2 / (r1 + r2)
    length(uncertainty_budget(right))
    ```

    Four budget rows for three inputs is the visible symptom. The
    invisible one is the number: at `Vin = 5 V`, `R1 = 1 kΩ`,
    `R2 = 3 kΩ` with `u = (0.01, 10, 20)`, the first form reports
    `u_c = 0.0335 V` and the second `0.0135 V`. The correct value is
    `0.0135` — the first double-counts R2 instead of combining its two
    sensitivities, and nothing warns, because two sources sharing a
    standard uncertainty is exactly what two nominally identical
    instruments look like.

    The rule is one line: **bind each physical input to a variable
    once, then use that variable everywhere it appears in the model.**

## Combined standard uncertainty

The combined standard uncertainty is the quadratic form over the
source covariance structure. With independent sources it reduces to
JCGM 100:2008 §5.1.2 equation (10); when covariances are declared, the
cross terms of §5.2.2 equation (13) appear. The two GUM formulas are
two regimes of a single expression rather than two code paths.

`m.err` is therefore a **computed property**, not a stored field:

```@example uncertainty-sources
m.err     # σV
```

## Correlation

Two quantities that derive from a **common source** are correlated,
and that correlation is propagated with no matrix supplied by anyone:

```@example uncertainty-sources
@variables V σV R σR
v = V ± σV
r = R ± σR

p = v * v / r    # power
i = v / r        # current

p / i            # exactly V ± σV — R cancels, V behaves correctly
```

This is the case that matters in practice, and the one a
user-supplied covariance matrix serves worst: the correlation exists
*because* both quantities descend from the same voltage measurement,
so the person writing the model is precisely the person who does not
know the covariance.

Correlation between sources that are **not** shared — two instruments
sharing a reference standard, say — is declared explicitly:

```@example uncertainty-sources
@variables x σx y σy ρ
a = x ± σx
b = y ± σy

a2, b2 = declare_correlated(a, b, ρ)
(a2 + b2).err        # carries the 2ρσₓσᵧ cross term of eq. (13)
```

`declare_correlated` returns new quantities and mutates nothing, so
two models in the same session can carry different and equally valid
hypotheses. The declared covariance enters as the cross term of
JCGM 100:2008 §5.2.2 equation (13); with `ρ = 0` it collapses onto
equation (10). There is one implementation, with two regimes.

## Covariance between measurands

Two quantities that share sources have a covariance fixed by their
linear forms, which JCGM 102:2011 §6 requires for a vector-valued
measurand — a user combining two outputs further needs to know how
they move together:

```@example uncertainty-sources
covariance(a2, b2)
correlation(a2, b2)
```

This once could not be answered: `propagate_vector` returned
marginal uncertainties and left cross-output covariance out of scope,
because nothing recorded which inputs an output derived from.

## API

```@docs
SourceId
Source
terms_of
sources_of
cov_of
declare_correlated
covariance
correlation
```
