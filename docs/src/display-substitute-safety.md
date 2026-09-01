```@meta
CurrentModule = SymbolicUncertainties
```

# Display, Substitution, and Safety

Three layers sit on top of the symbolic pipeline: a one-call
bridge from symbolic measurements to numeric values, LaTeX
rendering for Jupyter and Pluto notebooks, and two runtime
safety warnings (division-by-zero and `sqrt`/`log` domain).

## `substitute(m, dict)` — the symbolic-to-numeric bridge

`SymbolicUncertainties.jl` extends `Symbolics.substitute` with a
method that accepts a `SymbolicMeasurement` and a replacement
dictionary. Every field (`val`, `err`, and — when set —
`dof`) is rewritten via the underlying `Symbolics.substitute`
engine:

```@example display-substitute-safety
using Symbolics
using DynamicQuantities
using SymbolicUncertainties

@variables Vin σVin R1 σR1 R2 σR2
Vout = propagate(
    (vin, r1, r2) -> vin * r2 / (r1 + r2),
    [Vin ± σVin, R1 ± σR1, R2 ± σR2],
)

divider = Dict(
    Vin => 5.0us"V", σVin => 0.01us"V",
    R1 => 1_000.0us"Ω", σR1 => 1.0us"Ω",
    R2 => 3_000.0us"Ω", σR2 => 1.0us"Ω",
)

# `substitute` works on plain numbers, so the values are stripped here;
# [`evaluate`](@ref) is the call that keeps the units all the way to the
# answer.
Vout_numeric = substitute(Vout, Dict(k => ustrip(v) for (k, v) in divider))
```

Behaviour:

- **Silent ignore of extra keys** — any `Dict` key that does
  not appear in any of the three fields is silently dropped
  (REQ-122).
- **Partial substitution** — a `Dict` covering only a subset of
  variables leaves the rest symbolic in the returned
  measurement.
- **`dof === nothing` preserved** — no accidental upgrade to a
  substituted zero.
- **No simplification pass** — users who want Giac-level
  canonicalisation should call `Symbolics.simplify` on the
  returned fields themselves.
- **No REQ-005 re-check** — a substituted `err` that simplifies
  to a concrete negative `Real` is returned silently. The
  REQ-005 negativity guard lives in the numeric constructor;
  `substitute` is a rewriting operation, not a construction.

### Extracting numeric values

`Symbolics.substitute` does not numerically evaluate
expressions like `sqrt(0.05)` — they remain symbolic
(documented upstream and mirrored in `upstream-bugs.md` UB-001).
To obtain a concrete `Float64`, use the standard
`toexpr` + `eval` round-trip:

```@example display-substitute-safety
val_float = Float64(eval(Symbolics.toexpr(Vout_numeric.val)))
err_float = Float64(eval(Symbolics.toexpr(Vout_numeric.err)))
```

The same pattern lives in the `AsFloat` snippet the test
suite uses throughout.

## LaTeX rendering for Jupyter / Pluto

`Base.show(io, MIME"text/latex", m)` emits a LaTeX-math
representation wrapped in inline math delimiters `$...$`:

```text
$3.75 \pm 0.00625$
```

Jupyter and Pluto recognise the `text/latex` MIME type and
render the output as math automatically — no caller-side
wrapping required. The plain-text `text/plain` display
(`val ± err` in Unicode) is what every REPL and
non-notebook consumer sees.

The in-library formatter is intentionally minimal: for
concrete numeric values it prints the `Float64` directly; for
symbolic expressions it defers to `Base.string(expr)`. Users
who need production-grade LaTeX for complex expressions should
load [`Latexify.jl`](https://github.com/korsbo/Latexify.jl)
and call `latexify` on the individual `m.val` / `m.err`
fields. A dedicated `SymbolicUncertaintiesLatexifyExt` package
extension may land in a later milestone.

## Safety warnings (division-by-zero and `sqrt` / `log` domain)

Two runtime warnings surface potential correctness issues at
build time:

- **Division-by-zero** (REQ-140) fires when a division's
  denominator cannot be proven nonzero, i.e. when the
  denominator's `.val` is not a concrete numeric `Real`.
- **Domain** (REQ-141) fires when `sqrt`, `log`, `log2`, or
  `log10` is applied to a measurement whose `.val` cannot be
  proven strictly positive.

Both fire uniformly, through the binary operators and
through `propagate` alike. Neither halts the computation —
the returned `SymbolicMeasurement` is valid.

```@example display-substitute-safety
@variables a σa b σb
a_m = a ± σa
b_m = b ± σb

a_m / b_m
# ┌ Warning: Division by `y` whose `.val` is symbolic — the
# │ denominator cannot be proven nonzero at build time
# │ (JCGM 100:2008 §5.1, REQ-140). ...
# └

sqrt(a_m)
# ┌ Warning: sqrt applied to a measurement whose `.val` is
# │ symbolic — the argument cannot be proven strictly positive
# │ at build time (JCGM 100:2008 §5.1, REQ-141). ...
# └

propagate((x, y) -> x / y, [a_m, b_m])
# Fires REQ-140 via the propagate syntactic walker.

propagate((x,) -> log(x), [a_m])
# Fires REQ-141 via the same walker.
```

### When no warning fires

The library uses a simple, deterministic rule: a value is
"provably safe" iff its `.val` unwraps via `Symbolics.value`
to a plain Julia `Real` passing the appropriate test
(nonzero for division, strictly positive for
`sqrt`/`log`/`log2`/`log10`).

The quantities here are deliberately dimensionless: the guard tests
the *number* in `.val`, and a ratio scaling a signal or the argument of
a square root carries no unit of its own.

```@example display-substitute-safety
one_m = 1.0 ± 0.0
a_m / one_m          # no warning — denominator is provably 1.0

four_m = 4.0 ± 0.1
SymbolicUncertainties._warn_domain(:sqrt, four_m)
                     # no warning — argument is provably 4.0 > 0
```

### Why the library errs on the side of over-warning

`Symbolics.jl` does **not** expose an assumptions framework
(`assume` / `additionally`) — see
[`upstream-bugs.md` UB-003](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/upstream-bugs.md).
Without an upstream way to declare "this symbol is known to be
positive", the library cannot distinguish a user who *knows*
`σ > 0` from one who genuinely allows any sign. The
conservative choice is to warn whenever the value cannot be
proven safe, rather than silently skip a genuine domain
violation. An in-library `assume_positive!` /
`assume_nonzero!` layer is recorded in UB-003 as the
long-term fix; it is not implemented.

### Silencing the warnings

Three supported options:

1. **Substitute first.** Call `substitute(m, Dict(...))` with
   concrete numeric values for the problematic variables; the
   `.val` then unwraps to a `Real` and the warning does not
   fire on subsequent operations.
2. **Julia stdlib toggle.** In a REPL or notebook session,
   `import Logging; Logging.disable_logging(Logging.Warn)`
   suppresses all warnings, not only this package's.
3. **Test context.** Wrap the offending call in
   `Test.@test_logs (:warn, r"REQ-140") expr` (or `REQ-141`)
   to assert the warning is expected. This is how the
   package's own test suite captures the warnings it emits.

There is no in-library global silencing switch by design —
the constitution's purely-symbolic principle and the
Julia-ecosystem aversion to mutable global state make a toggle
discouraged.

## API reference

```@docs
Symbolics.substitute(m::SymbolicMeasurement, dict::AbstractDict)
```
