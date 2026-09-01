# Upstream / Cross-Cutting Issues

This file records issues that surface during `SymbolicUncertainties.jl`
development but whose root cause lives outside the immediate code
under development — either in an upstream dependency, in an
upstream specification, or in a deliberate design decision of this
package that future contributors should be aware of.

Each entry follows the same shape:

- **Identifier**, **discovered in**, **status**, and a free-form
  body explaining the problem, the workaround, and the proposed
  fix or escalation path.

Entries are added in chronological order with the newest at the
top.

---

## UB-008 — `Symbolics.simplify` overflows `Int64` on a `Rational` coefficient with a large denominator

- **Discovered in**: post-M14 documentation build, on the gauge R&R
  example's `combined.dof`.
- **Status**: **filed upstream** —
  [SymbolicUtils.jl#1051](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1051),
  opened 2026-09-04. Reproduced on Symbolics 7.39.0 +
  SymbolicUtils 4.46.1, Julia 1.12.7.

### Symptoms

```julia
julia> using Symbolics, SymbolicUncertainties

julia> @variables sr σsr so σso sc σsc sres σsres;

julia> combined =
           SymbolicMeasurement(sr, σsr, Symbolics.Num(30.0)) +
           SymbolicMeasurement(so, σso, Symbolics.Num(2.0)) +
           SymbolicMeasurement(sc, σsc, Symbolics.Num(1.0e12)) +
           SymbolicMeasurement(sres, σsres, Symbolics.Num(1.0e12));

julia> combined.dof
ERROR: OverflowError: 299999999991 * -99999999997 overflowed for type Int64
```

The stack trace puts it in `DynamicPolynomials`:

```
checked_mul                                   checked.jl:297
*(::Rational{Int64}, ::Rational{Int64})       rational.jl:408
_mul(::Type{Rational{Int64}}, p::Polynomial{…, Rational{Int64}}, q::…)
                                              DynamicPolynomials mult.jl:125
```

A degrees-of-freedom count of `1e12` becomes the coefficient
`1//1000000000000` — the reciprocal, so the large value lands in the
*denominator* — and putting it over a common denominator with ordinary
coefficients like `1//30` overflows `typemax(Int64)` on a checked
multiplication.

The overflow itself is in `*(::Rational{Int64}, ::Rational{Int64})`
(`rational.jl:408`), which multiplies denominators through
`checked_mul` with no promotion. It is *not* a property of the
polynomial's coefficient type: this package's expression reaches it
through a polynomial over `Rational{Int64}`, while the minimal
reproducer below reaches the same line through one over `Number`.

The `1//…` coefficients are exact rationals, not floats: the raw
Welch-Satterthwaite expression this package builds already carries
`1//30`, `1//2` and `1//1000000000000` before simplification is
attempted. A float-coefficient version of the same shape simplifies
cleanly, which is why the reduction below uses `Rational` literals.

### Minimal reproducer

Reduced away from this package entirely — the coefficients that matter
are exact `Rational`s, not floats, and a float-coefficient version of
the same shape simplifies cleanly:

```julia
julia> using Symbolics

julia> @variables a b;

julia> simplify(((1//3)*a + (1//1000000000000)*b)^2 / (a + b))
ERROR: OverflowError: 1000000000000 * 1000000000000 overflowed for type Int64

julia> simplify(((1//3)*a + (1//7)*b)^2 / (a + b))   # small denominators: fine
(((1//3)*a + (1//7)*b)^2) / (a + b)
```

### Trigger

A `Rational` coefficient whose denominator is large enough to overflow
when multiplied by another. Nothing unusual is required: `1e12` is the idiomatic
way to write "effectively infinite degrees of freedom" for a Type B
component whose standard uncertainty is itself well known
(JCGM 100:2008 §G.4.2), and the Welch-Satterthwaite denominator then
multiplies such coefficients together.

Note this is the *opposite* end of the same conversion from UB-007,
which loses information when coefficients are very small. Coefficients
of ordinary magnitude are handled correctly at both ends.

### Impact on this package

`m.dof` — a plain property access — threw. Simplification is only a
presentation step here, so an exception from it aborted a computation
whose result was already correct and available. The documentation
build failed on the gauge R&R example for this reason.

As with UB-007, the Giac extension masks it: `_simplify_for_report` is
overloaded there and Giac does not share the defect, so the same model
raised in a docs build and passed in the test suite, where another
file had loaded Giac.

### Workaround

`_simplify_for_report` no longer propagates exceptions. On failure it
returns the unsimplified expression, which prints less tidily and
carries exactly the same value. This also covers UB-006, whose
`BoundsError` reached users by the same route.

---

## UB-007 — `simplify_fractions` returns a numerically wrong result for a small-coefficient polynomial over a square root

- **Discovered in**: post-M14 gallery work, tracing an uncertainty
  source that disappeared from the thermocouple cold-junction model.
- **Status**: **filed upstream** —
  [SymbolicUtils.jl#1050](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1050),
  opened 2026-09-04. Reproduced on Symbolics 7.39.0 +
  SymbolicUtils 4.46.1.
- **Severity**: this is a **wrong answer**, not a missed
  simplification. Unlike UB-003 and UB-006, the simplifier does not
  give up or throw — it silently returns an expression with a
  different value.

### Symptoms

`SymbolicUtils.simplify_fractions` drops the constant term of a
numerator polynomial when the coefficients are small in absolute
terms:

```julia
julia> using Symbolics

julia> @variables x
1-element Vector{Num}:
 x

julia> e = 1e-9 * (3.0 + 5.0x) / sqrt(1 + x)
(1.0e-9(3.0 + 5.0x)) / sqrt(1 + x)

julia> simplify(e)
5.0e-9sqrt(1 + x)
```

The returned expression equals `1e-9(5 + 5x)/sqrt(1 + x)`: the
constant term `3.0` has been replaced by the coefficient of `x`.
Substituting `x = 2` gives `7.5056e-9` for the original and
`8.6603e-9` for the "simplified" form — a relative error of `0.1538`.

The defect has a worse form on the expressions that first exposed it.
On a reduced thermocouple-shaped variant, `simplify` returns
`2.22784e-15sqrt(1.0 + x)`, wrong by a relative `0.9964` at `x = 2`:

```julia
julia> simplify(9.44e-8 * (3.945e-5 + 4.72e-8x) / (2sqrt(1.0 + x)))
2.22784e-15sqrt(1.0 + x)
```

and on the full sensitivity in the model itself it returns exactly
`0` — the whole term gone, a relative error of `1`.

`SymbolicUtils.simplify_fractions` reproduces it alone, and
`simplify(e; expand = false)` does not avoid it, so the defect sits in
the fraction-cancellation pass rather than in `expand`.

### Trigger

The threshold is **absolute**, not relative — the same expression
scaled up is handled correctly:

```
a * (3.0 + 5.0x) / sqrt(1 + x)      a = 1e-8  → correct
                                    a = 1e-9  → wrong
```

This is consistent with dividing the numerator by `(1 + x)` and
discarding the remainder (`3a - 5a = -2a`) when its magnitude falls
under a fixed tolerance, rather than one relative to the coefficients
involved. Expressions whose coefficients are all of comparable
magnitude are never affected, which is why the defect is invisible in
ordinary algebra and immediate in metrology, where a sensitivity
coefficient of `1e-12` is unremarkable.

### Impact on this package

Severe, and it was live: `_chain` deleted an uncertainty source whose
simplified sensitivity compared equal to zero. A wrong zero therefore
removed a real contribution from the linear form and **understated the
combined standard uncertainty** with no diagnostic. In the JCGM-shaped
thermocouple model `T = (-a₁ + sqrt(a₁² + 4a₂(E + a₁T_cj + a₂T_cj²)))/(2a₂)`
the cold-junction source vanished at the `sqrt` step.

### Why the test suite did not catch it

`_simplify_for_report` defaults to `Symbolics.simplify` and is
overloaded by the Giac extension. Giac does not share the defect, so
the thermocouple model kept its cold-junction source whenever the Giac
extension happened to be loaded — which it was in a full `Pkg.test()`
run, because another test file loads it — and lost it when the same
test ran alone. Correctness depended on extension load order, which is
why the failure looked intermittent and unreproducible before the
cause was found. The guard below is backend-agnostic for that reason:
it re-checks whatever `_simplify_for_report` returned, rather than
trusting one backend over another.

### Workaround

`_chain` no longer trusts a simplified zero. Simplification is treated
as a presentation step that may never delete a source: when
`simplify` reports zero, `_vanishes` re-checks the *unsimplified*
sensitivity numerically, against the scale of the contributions it was
summed from, and the term is dropped only if that confirms it. Where
the two disagree the unsimplified form is kept — less readable, and
correct. Anything that cannot be evaluated keeps the term, because
reporting a source that cancels costs a `0·u` budget row while
dropping one that does not is a metrological error.

---

## UB-006 — `Symbolics.simplify` throws a `BoundsError` on an even power of a negated symbol

- **Discovered in**: post-M13 audit, reducing the unsimplified
  `(-U)^2` forms seen in propagated expressions.
- **Status**: **filed upstream** —
  [SymbolicUtils.jl#1044](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1044),
  opened 2026-09-02. Reproduced on the current releases of both
  packages: Julia 1.12.7, SymbolicUtils 4.46.2 alone (no Symbolics
  loaded) and Symbolics 7.39.0 + SymbolicUtils 4.46.2. Not the same
  defect as
  [Symbolics.jl#1773](https://github.com/JuliaSymbolics/Symbolics.jl/issues/1773),
  though it shares a root — see *Relation to other issues* below.

### Symptoms

```julia
julia> using Symbolics

julia> @variables U
1-element Vector{Num}:
 U

julia> (-U)^2          # prints as if already folded
(U^2)

julia> isequal((-U)^2, U^2)
false

julia> simplify((-U)^2)
ERROR: BoundsError: attempt to access 1-element ReadOnlyVector{…} at index [1:2]
```

`expand` is the workaround and normalises the node:

```julia
julia> expand((-U)^2)
U^2

julia> isequal(expand((-U)^2), U^2)
true

julia> simplify(expand((-U)^2))   # fine
U^2
```

### Root cause

`(-U)^2` builds a **degenerate `Mul` node carrying a single factor**:

```julia
julia> e = Symbolics.value((-U)^2);

julia> operation(e), length(arguments(e))
(*, 1)
```

`SymbolicUtils`' associative-commutative rule machinery
(`rule.jl:667`, `ACRule`) then takes a `view` over `1:2` of that
node's arguments to try a two-factor match, without checking that the
term has two factors. One argument, index range `1:2`, `BoundsError`.

Two consequences beyond the crash:

- the value **prints as `(U^2)`** — the parentheses are the only
  visible difference from `U^2` — while `isequal` says it is not
  `U^2`. Any equality-based test comparing a propagated expression
  against a hand-written one can therefore fail while the two display
  identically.
- the crash needs exactly **one** factor. `(-U*V)^2` has two and
  simplifies fine, which is why the failure looks arbitrary.

### Relation to other issues

The same node is a concrete instance of
[SymbolicUtils.jl#1023](https://github.com/JuliaSymbolics/SymbolicUtils.jl/issues/1023)
(TermInterface contract violated): `iscall((-U)^2)` is `true` while
`isexpr` is `false`, `head` and `children` raise `MethodError`, and
rebuilding the node from its own `operation` and `arguments` through
`maketerm` yields the well-formed `U^2`, which is **not** `isequal` to
the original. A node that cannot round-trip through its own interface
is the same defect seen from the interface side.

[Symbolics.jl#1768](https://github.com/JuliaSymbolics/Symbolics.jl/issues/1768)
(useless parentheses) is adjacent but distinct: its `-(b^2)` carries
two arguments, `-1` and `b^2`, is well formed and merely prints with
parentheses. Here the parentheses are the visible tell of a malformed
node.


[#1773](https://github.com/JuliaSymbolics/Symbolics.jl/issues/1773)
("A fraction with negative numerator and negative denominator should
be simplified", open since 2026-01-24) reports that
`(-V1)/(-1 - R1*C1*s)` is returned unchanged by both `simplify` and
`expand`. Same origin — unary minus is represented as a `Mul` with a
`-1` coefficient, and nothing normalises the sign — but a different
failure mode: #1773 is a **missed rewrite** that returns a correct if
ugly expression, whereas this entry is a **crash**. A sign-normalising
pass over `Mul` would plausibly fix both; neither is fixed by the
other's workaround, since `expand` clears this one and does nothing
for #1773.

### Exposure in this package

`_simplify_for_report` is `Symbolics.simplify` when `Giac.jl` is not
loaded, and it has no guard:

```julia
julia> SymbolicUncertainties._simplify_for_report((-σx)^2)
ERROR: BoundsError
```

No current propagation path reaches it — a difference of two
quantities yields `sqrt(σx^2 + σy^2)`, whose square terms are built
with two factors — so no test fails today. It is one user expression
away: any measurement whose combined uncertainty reduces to the square
of a single negated symbol would take the propagation down. With
`Giac` loaded the extension's `catch` swallows it silently, which is
the UB-005 pathology on top.

### Escalation path

File upstream against `SymbolicUtils.jl` with the three-line
reproducer, pointing at the unguarded `view(arguments(term), 1:arity)`
in `ACRule`. The narrow fix is a length check before the view; the
broad one is to stop constructing single-factor `Mul` nodes at all,
which would also settle the `isequal` / display mismatch.

---

## UB-005 — Giac.jl emits a parse error on a mangled identifier, silently disabling CAS simplification

- **Discovered in**: post-M13 audit of a full `Pkg.test()` log.
- **Status**: **open, symptom recorded** — root cause not yet
  isolated to Giac.jl or to the expression handed to it. Not a
  correctness defect in this package: the fallback returns a
  mathematically equal expression.

### Symptoms

The first four calls into the Giac extension in a test run print, on
stderr, four lines of the shape

```
:1: syntax error  line 1 col 6 at u_ in <non-printable bytes>
```

The identifier prefix is stable (`u_`) and what follows it differs
every run and is not valid UTF-8 — the signature of a string that is
read past its end rather than of a genuinely malformed expression.
No test fails, because `_simplify_for_report` catches the failure and
falls back to `Symbolics.simplify`.

### Consequence

The consequence is not a wrong answer but a **silently withdrawn
capability**: with `Giac` loaded the package advertises CAS-grade
simplification, and for the affected expressions it quietly does not
deliver it. Before M13 the extension's `catch` was bare, so nothing
recorded that the fallback had been taken.

### Workaround

`ext/SymbolicUncertaintiesGiacExt.jl` now logs the failing expression
and the exception at `@debug` level before falling back. Run with
`JULIA_DEBUG=SymbolicUncertaintiesGiacExt` to see which expressions
Giac refuses.

### Escalation path

Reduce to a minimal `Giac.to_giac` / `Giac.Commands.simplify`
round-trip on an expression carrying a `u_`-prefixed symbol, confirm
the truncation happens inside the Giac.jl wrapper rather than in the
expression handed to it, and file upstream with that reproducer. The
parse error text comes from Giac's own parser, so the string it
received is already damaged by the time it gets there.

---

## UB-004 — Symbolics.jl 7 lacks `FortranTarget` export required by EARS REQ-071

- **Discovered in**: Milestone M7 (v0.7.0) planning phase —
  `/speckit.plan` research R2 probed `isdefined(Symbolics,
  :FortranTarget)` in Symbolics 7.18.1 on Julia 1.12.6.
- **Status**: **scope-narrowed in M7** — `build_evaluator`
  supports `JuliaTarget` + `CTarget` only. Requests for
  `FortranTarget` raise `ArgumentError` listing the
  supported set.

### Symptoms

```julia
julia> using Symbolics

julia> isdefined(Symbolics, :CTarget)
true

julia> isdefined(Symbolics, :FortranTarget)
false
```

### Root cause

Upstream `Symbolics.jl` exports `JuliaTarget`, `CTarget`,
`StanTarget`, and `MATLABTarget` via its
`BuildTargets` infrastructure, but a Fortran emitter has
never landed in the 7.x series. The EARS spec
(`specification/ears.md` REQ-071) was written against the
"when Symbolics.jl's CTarget or FortranTarget is
available" wording that acknowledges this possibility.

### Workaround

M7 ships `build_evaluator(m, vs; target = CTarget())` as
the only non-Julia target. The `target` keyword dispatch
table explicitly raises `ArgumentError` for unsupported
targets (including any Symbolics-provided target that the
M7 implementation does not yet wrap).

Users who need Fortran bindings can either (a) use the
C-source output via `CTarget()` and wrap it with an
`iso_c_binding` Fortran shim, or (b) translate the emitted
C manually.

### Upstream escalation path

A `JuliaSymbolics/Symbolics.jl` issue titled roughly
"Add a FortranTarget emitter alongside CTarget" would be
the right ecosystem-level ask. No such issue is currently
filed by this project. If a M9+ milestone reintroduces
Fortran emission as a first-class deliverable, the M7
`build_evaluator` dispatch table is a one-line addition.

### References

- `Symbolics.jl` 7.18.1 runtime probe (see
  `specs/009-code-gen-and-latex/research.md` R2).
- EARS spec REQ-071 — "when Symbolics.jl's CTarget or
  FortranTarget is available" conditional.
- `specs/009-code-gen-and-latex/contracts/build_evaluator.md`
  — the M7 `ArgumentError` branch for unsupported targets.

---

## UB-003 — Symbolics.jl has no assumptions framework (`assume` / positivity queries)

- **Discovered in**: Milestone M4 (v0.4.0) design, during the
  `/speckit.clarify` clarification pass for the division-by-zero
  (REQ-140) and `sqrt`/`log` domain (REQ-141) safety warnings.
- **Status**: **ecosystem gap, tracked upstream but dormant** —
  [JuliaSymbolics/Symbolics.jl#98 "Assumptions"](https://github.com/JuliaSymbolics/Symbolics.jl/issues/98),
  open since 2021-03-07, four comments, **no activity since
  2023-06-14**, unlabelled, no PR. It asks for exactly what is missing
  here (`x1 ∈ Real ∩ Positive`). The maintainer's reply in 2021 —
  *"This isn't all implemented yet, so it might be good to use this
  issue to start talking design"* — proposes representing domains with
  `DomainSets.jl`, for consistency with the ModelingToolkit
  `PDESystem` work, carried on Symbolics' **metadata system**; issue
  #97 is cited there for SymPy's branch elimination under assumptions.
  That design conversation never started. A user reopened the thread in
  2023 asking for SymPy's `positive=true` and received no reply.

  Symbolics' own parity checklist,
  [#59 "Feature Completeness Against SymPy"](https://github.com/JuliaSymbolics/Symbolics.jl/issues/59)
  — updated as recently as 2026-08-29 — does not list assumptions at
  all, so the gap is not even tracked as a parity item. Nothing is
  expected here in the short term.

  `SymbolicUncertainties.jl` M4 works around it by requiring a concrete
  numeric `Real` in `.val` to mark an operand "provably safe"; all
  purely-symbolic `.val` expressions trigger the warning even when
  the user knows by context that the value is positive/nonzero.

### Symptoms

Giac.jl provides a full assumptions framework so a downstream
package can write:

```julia
Giac.assume("σ > 0")
# later: Giac.is_positive(σ) → true
```

The equivalent does not exist in `Symbolics.jl`. Probing the
public API in Julia 1.12 / Symbolics 7.18 yields:

| Capability                            | Symbolics.jl | Giac.jl |
|---------------------------------------|--------------|---------|
| `assume(σ > 0)` on a symbol           | ❌           | ✅      |
| `additionally(σ ≠ 0)` refinement      | ❌           | ✅      |
| Query "provably nonzero"              | ❌           | ✅      |
| Query "provably strictly positive"    | ❌           | ✅      |
| Type annotation (`@variables x::Real`)| ✅ (only type hint, not positivity) | — |
| Generic metadata `getmetadata`/`setmetadata` | ✅ (hook only, no semantics) | — |

`SymbolicUtils.isnegative` exists but is a **printing helper**
restricted to `BasicSymbolic` terms (used to render negated
products nicely). It errors on concrete `Float64` and is not a
domain predicate.

### Root cause

`Symbolics.jl` intentionally separates structural rewriting (its
core competence) from semantic reasoning about the values a
symbol can take. The latter would require an SMT-like or CAS-like
decision procedure that the Symbolics team has not scoped.

### Workaround in M4

`SymbolicUncertainties._has_provable_value` uses the simplest possible
rule that is fully auditable against the spec:

```julia
function _has_provable_value(val)
    raw = Symbolics.value(val)
    return raw isa Real && !(raw isa Symbolics.Num)
end
```

A concrete `Float64` in `.val` counts as "known"; anything else
is "unknown" and conservatively triggers the REQ-140 /
REQ-141 warning. This means:

- `y.val = Num(5.0)` — `.val` unwraps to `Float64(5)` — safe.
- `y.val = σ` (plain symbol) — `.val` unwraps to a
  `BasicSymbolicImpl` — triggers warning.
- `y.val = 5σ` — `.val` unwraps to a `BasicSymbolicImpl` —
  triggers warning even though the user might know `σ > 0`.

The **false-positive warnings are accepted**. The library errs on
the side of over-warning rather than silently skipping a genuine
divide-by-zero or domain violation.

### Possible proper fix — in-library `assume` layer

If upstream `Symbolics.jl` continues not to expose an
assumptions API, `SymbolicUncertainties.jl` could build its own on top
of `Symbolics.setmetadata` / `getmetadata`:

```julia
SymbolicUncertainties.assume_positive!(σ)     # sets :ep_positive metadata
SymbolicUncertainties.assume_nonzero!(y)      # sets :ep_nonzero metadata
```

The safety helpers would then consult the metadata in addition
to the concrete-`Real` rule. This is a significant new API
surface (new exports, new docs page, new test suite) and is
deliberately **out of scope** for M4. Revisit around the
milestone that introduces `@register_symbolic`-driven user
functions if the false-positive rate becomes a documented
problem.

### Upstream escalation path

An issue on `JuliaSymbolics/Symbolics.jl` titled roughly
"Proposal: expose an assumptions framework for positivity /
nonzero queries" would be the right ecosystem-level ask. No
such issue is currently filed. A minimal public API would be:

```julia
Symbolics.assume(σ, :positive)
Symbolics.is_provably_nonzero(expr) :: Union{Bool, Nothing}
Symbolics.is_provably_positive(expr) :: Union{Bool, Nothing}
```

returning `true` / `false` for decidable cases and `nothing`
when the symbolic engine cannot decide — matching the standard
three-valued convention for partial decision procedures.

### References

- Giac.jl `assume` / `additionally` — the reference capability
  this package's upstream is missing.
- `SymbolicUtils.isnegative` at
  `~/.julia/packages/SymbolicUtils/*/src/printing.jl` — a
  printing-only helper, not a domain predicate.
- `SymbolicUncertainties.jl` M4 `src/safety.jl` (planned) — where
  the workaround will live.
- EARS REQ-140, REQ-141, REQ-142 — the safety requirements this
  gap affects.

---

## UB-001 — Symbolics 7 `substitute` does not numerically evaluate the result

- **Discovered in**: Milestone M1 (v0.1.0), test authoring
- **Source file**: every `test/arithmetic/test_*.jl` and
  `test/examples/test_ohms_law.jl`
- **Status**: **worked around in test helpers**, no upstream report
  filed (behaviour appears intentional)

### Symptoms

```julia
julia> using Symbolics

julia> @variables a b
2-element Vector{Num}:
 a
 b

julia> v = Symbolics.substitute(sqrt(a^2 + b^2), Dict(a => 3.0, b => 4.0))
sqrt(25.0)

julia> typeof(v)
Num

julia> Symbolics.value(v)
sqrt(25.0)                 # still a SymbolicUtils.BasicSymbolicImpl

julia> Float64(v)
ERROR: MethodError: no method matching Float64(::SymbolicUtils.BasicSymbolicImpl{...})
```

The `substitute` call does **not** simplify or evaluate the
resulting expression — it only rewrites the named variables.
`sqrt(25.0)` stays as a symbolic expression that resolves to
`Num`-of-`BasicSymbolicImpl`, not to a Julia `Float64`. As a
consequence, `isapprox(symbolic_form_1, symbolic_form_2;
atol = 1e-12)` errors with `MethodError` because there is no
`isapprox` method for `BasicSymbolicImpl`.

### Workaround

Inside each affected `@testitem`, define a small helper:

```julia
_as_float(expr, dict) =
    Float64(eval(Symbolics.toexpr(Symbolics.substitute(expr, dict))))
```

`Symbolics.toexpr` converts the (now numerically-substituted)
expression back to a plain Julia `Expr`, and `eval` then evaluates
it in the testitem's module context. The result is a `Float64`
which `isapprox` accepts.

### Status

This is **arguably the documented behaviour** of
`Symbolics.substitute`, which is a structural rewriter rather than
an evaluator. It is not strictly an upstream bug. The workaround
is acceptable for tests but should not propagate into user-facing
code.

If we ever expose a `substitute(::SymbolicMeasurement, ::Dict)`
method (planned for the EARS REQ-120 milestone — numerical
evaluation), it must use `Symbolics.value ∘ Symbolics.substitute`
followed by an explicit numeric evaluation step (or a
`build_function`-based path) so that downstream users get a clean
numeric result without having to understand `toexpr`/`eval`.

### References

- EARS spec REQ-120, REQ-121 (numerical evaluation milestone)
- `test/arithmetic/test_addition.jl` (and siblings) for the
  in-test workaround
