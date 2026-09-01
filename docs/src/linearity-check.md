```@meta
CurrentModule = SymbolicUncertainties
```

# Linearity Check

The GUM §5.1.1 note reminds the user that the law of
propagation of uncertainty is a **first-order Taylor
approximation** valid when higher-order terms are
negligible. `check_linearity` surfaces that assumption
actively: it returns a per-variable
dimensionless nonlinearity indicator

```math
\eta_i = \frac{\partial^2 f / \partial x_i^2 \cdot \sigma_i^2}
              {2 \cdot \partial f / \partial x_i \cdot \sigma_i}
```

— the ratio of the neglected second-order Taylor term to
the retained first-order term. `|ηᵢ| ≪ 1` means the linear
propagation is safe; `|ηᵢ| > 0.1` signals a regime where
**Monte Carlo methods** (JCGM 101:2008,
[`MonteCarloMeasurements.jl`](https://github.com/baggepinnen/MonteCarloMeasurements.jl))
should be used instead.

## The two signalling behaviours

### Symbolic indicator

```@example linearity-check
using Symbolics, SymbolicUncertainties

@variables x σx
η = check_linearity(a -> exp(a), [x ± σx])
# η[σx] is the symbolic expression for ηᵢ.
```

For any `SymbolicMeasurement`-producing function, the
diagonal `∂²f/∂xᵢ²` and the first derivative `∂f/∂xᵢ` are
computed via `Symbolics.derivative`, through the same
guarded helper the elementary functions use. A per-input `σᵢ` key in the
returned `Dict{Num, Num}` maps to the symbolic `ηᵢ`.

!!! note "Why there are no units on this page"
    The argument of `exp`, like that of every transcendental function,
    must be dimensionless — `exp(1 V)` is not a quantity. The `x` below
    is therefore a genuinely dimensionless input, and annotating it
    with a unit would be a physical error rather than an improvement.
    The nonlinearity indicator `η` is dimensionless for the same
    reason: it compares a second-order term with a first-order one, and
    a ratio of two quantities of the same dimension has none.

### Runtime threshold `@warn`

```@example linearity-check
check_linearity(
    a -> exp(a),
    [x ± σx];
    values = Dict(x => 1.0, σx => 0.5),
)
# ┌ Warning: check_linearity: |η| = 0.25 exceeds the GUM
# │ §5.1.1 linearity threshold of 0.1 for variable `σx`.
# │ The first-order propagation formula may be inadequate
# │ — consider Monte Carlo methods
# │ (MonteCarloMeasurements.jl / JCGM 101:2008). (REQ-181)
# └
```

The `values` keyword triggers a **numeric threshold check**:
for each `ηᵢ` that evaluates to a concrete `Float64`
exceeding `0.1`, a runtime `@warn` fires per REQ-181.
Entries with partial / un-substituted `values` are silently
skipped (the indicator in the returned dict is still
symbolic for manual inspection).

### No warning at low nonlinearity

```@example linearity-check
check_linearity(
    a -> exp(a),
    [x ± σx];
    values = Dict(x => 1.0, σx => 0.1),
)
# η = 0.05 — below threshold → no warning.
```

## Worked example — linear vs nonlinear contrast

```@example linearity-check
@variables x σx
η_lin = check_linearity(a -> 2a + 3, [x ± σx])
# η_lin[σx] simplifies to 0 — exact linearisation.

η_nl = check_linearity(a -> exp(a), [x ± σx])
# η_nl[σx] = σx / 2 — grows with σx.
```

This is the REQ-155 acceptance criterion.

## No silent higher-order correction (REQ-182)

`check_linearity` is a **pure observer**: running it does
**not** change any propagation output.
Before-and-after comparisons of `propagate(f, [m])` are
bit-identical irrespective of whether `check_linearity` has
been called.

```@example linearity-check
y1 = propagate(a -> exp(a), [x ± σx])
check_linearity(a -> exp(a), [x ± σx])     # no side effect
y2 = propagate(a -> exp(a), [x ± σx])
# y1.val == y2.val and y1.err == y2.err symbolically.
```

Asserted by `test/linearity/test_no_higher_order_correction.jl`.

## Scope — diagonal only

`check_linearity` tracks the **diagonal** second derivative
`∂²f/∂xᵢ²` only, not the mixed partials `∂²f/∂xᵢ∂xⱼ`. For a
measurand whose nonlinearity lives in the cross terms this
indicator under-reports it — a product is the extreme case,
since every `∂²(ab)/∂xᵢ²` is zero while all of its
nonlinearity sits in `∂²(ab)/∂a∂b`.

[`linearisation_bound`](@ref) includes the mixed partials
and returns a rigorous bound rather than an indicator; use
it when the diagonal is not enough.

## Error paths

- **Unresolved second derivative** → `ArgumentError`
  noting that there is no `derivative_2` override — no
  analogue of the `apply(f, m; derivative = ...)` escape
  hatch exists for second derivatives.
- **Empty input list** → empty dict, no error, no `f` call.

## Silencing the safety-warning chatter

The `ηᵢ` formula contains a division by `2·cᵢ·σᵢ`, which
is usually symbolic, so the REQ-140 `@warn` fires from
within `check_linearity`. In tests and REPLs this is
typically silenced via:

```@example linearity-check
using Logging
Logging.with_logger(Logging.NullLogger()) do
    check_linearity(a -> exp(a), [x ± σx])
end
```

The test suite uses exactly this pattern.

## API reference

## From indicator to bound

`check_linearity` is a heuristic: it evaluates a second-derivative
ratio at a point and warns past `|η| > 0.1`. It is also
**diagonal-only** — it looks at `∂²f/∂xᵢ²` and ignores the mixed
partials. That gap is not academic:

```@example bound
using Symbolics
using SymbolicUncertainties
@variables a σa b σb

check_linearity(*, [a ± σa, b ± σb])   # η = 0 for both inputs
```

A product's Hessian has a zero diagonal, so the indicator calls `a·b`
linear. It is not: all of its nonlinearity sits in `∂²(ab)/∂a∂b = 1`.

`linearisation_bound` answers the question the indicator only gestures
at — *by how much can the first-order result be wrong?* — and answers
it rigorously:

The true worst error over that region is 0.0582, so the bound
contains it and stays tight:

```@example bound
linearisation_bound(exp, [a ± σa]; coverage_factor = 2,
                    values = Dict(a => 1.0, σa => 0.1))
```

Taylor's theorem with the Lagrange remainder bounds the error by
`½ Σᵢⱼ max|Hᵢⱼ| · (k·uᵢ)(k·uⱼ)`, with each `Hᵢⱼ` bounded by interval
arithmetic over the coverage region. Mixed partials included.

The claim this supports is stronger than a Monte Carlo check's. JCGM
101:2008 validates the linearisation by sampling, so it can only speak
for the points it drew; a bounded symbolic Hessian certifies the
entire region at once.

The bound is **reported, never applied**. REQ-182 stands: no
higher-order correction is folded into `u_c` behind your back. And
where no rigorous bound exists — a denominator whose interval spans
zero, a `log` reaching zero, an operation with no interval extension —
it raises rather than returning a number that cannot be trusted. An
unsound bound is worse than none.

## Correcting the estimate — Amendment 1:2026

`linearisation_bound` bounds the error the first-order law makes in
`u_c`. A separate question is whether the **estimate** itself needs a
correction, and JCGM 100:2008/Amd.1:2026 answers it: where the
nonlinearity of `f` is significant, either use a Monte Carlo method
or include the higher-order term

```math
\tfrac{1}{2} \sum_i \frac{\partial^2 f}{\partial x_i^2} u^2(x_i)
```

in the expression for `y`, with equation (H.10) generalising it to
non-independent inputs.

```@example bound
second_order_correction(x -> x^2, [a ± σa])
```

For `f = x²` the correction is exactly `u²(x)`, which is the familiar
`E[X²] = μ² + σ²`. For a product of *independent* inputs it is zero —
the Hessian diagonal vanishes — while for correlated inputs it is
`cov(a, b)`, since `E[AB] − E[A]E[B]` is precisely the covariance.

The two functions answer different questions and a model may need one
without the other: that same product has an exact estimate and an
inexact combined uncertainty.

The correction is **returned, never applied**. `val` stays the
first-order estimate until you add it yourself — REQ-182 forbids
silent higher-order corrections, and the amendment asks for the term
to be included knowingly.

```@docs
check_linearity
linearisation_bound
second_order_correction
```
