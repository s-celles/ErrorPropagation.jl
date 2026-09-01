```@meta
CurrentModule = SymbolicUncertainties
```

# Code Generation

This is where the symbolic pipeline becomes **deployable**:
compiled Julia evaluators for hot-loop Monte Carlo and
calibration-batch workflows, and C source strings for
embedded metrology systems.

| Function               | Purpose                                             |
|------------------------|-----------------------------------------------------|
| `build_evaluator`      | Compile `(val, err)` to a Julia callable or C source |
| `to_expr`              | Extract the `(val, err)` tuple for downstream symbolic tooling |
| `latex`                | LaTeX rendering; requires `Latexify.jl` to be loaded |

## `build_evaluator` — Julia target

```@example code-generation
using Symbolics, SymbolicUncertainties, DynamicQuantities

@variables V I σV σI
R_m = (V ± σV) / (I ± σI)

ohm = Dict(V => 5.0us"V", σV => 0.01us"V", I => 0.5us"A", σI => 0.001us"A")

g = build_evaluator(R_m, [V, I, σV, σI])

# A compiled evaluator takes plain numbers — that is what compiling it
# is for, and a unit check has no place in an inner loop. The unit of
# what it returns still belongs to the model, so it is taken from
# [`evaluate`](@ref) once, outside the loop, rather than asserted here.
unit_R = oneunit(evaluate(R_m, ohm).val)

val, err = g(5.0, 0.5, 0.01, 0.001)   # volts, amperes
(val * unit_R, err * unit_R)
```

The returned callable is compiled via
`Symbolics.build_function` with `expression = Val{false}` —
runtime-compiled, sub-100 ns per call on typical GUM
measurements. Use it in Monte Carlo loops, calibration-
batch processing, and laboratory-automation inner loops
where the `substitute + toexpr + eval` round-trip is too
slow.

### Empty-variables fast path

For fully-numeric measurements, pass an empty variable
vector:

```@example code-generation
# A reference resistor: 5.000 Ω with u_c = 0.1 Ω.
m = 5.0 ± 0.1
g = build_evaluator(m, Symbolics.Num[])
g() .* us"Ω"
```

## `build_evaluator` — C source for embedded deployment

```@example code-generation
c_source = build_evaluator(
    R_m,
    [V, I, σV, σI];
    target = CTarget(),
    fname = :ohms_law_evaluator,
)

write("ohms_law.c", c_source)
```

Writes a C file containing:

```c
#include <math.h>
void ohms_law_evaluator(double *du,
    const double V, const double I,
    const double σV, const double σI)
{
    du[0] = V / I;
    du[1] = hypot(σV / I, (V * σI) / (I * I));
}
```

Compile it into firmware, PLC toolchains, or regulated-
industry deployment builds where the audit trail requires
the GUM formula in an approved artefact.

### Why the emitted code says `hypot`, not `sqrt`

The symbolic form of `u_c` is a square root of a sum of
squares — the form every GUM text writes, and the readable
one. Evaluated in double precision it is fragile: the
squares overflow once a contribution passes about `1e154`
and underflow to zero below about `1e-150`, so `u_c` comes
back as `Inf` or `0` where `hypot` returns the right number.
`hypot` is in `math.h` and in Julia's `Base`, so the fix
costs nothing.

Only the emitted code changes; `m.err` keeps its `sqrt`
form. The rewrite applies exactly when every addend under
the root is a square, which is the uncorrelated regime.
Under a declared correlation the variance carries
`2·cᵢcⱼ·u(xᵢ,xⱼ)` (JCGM 100:2008 eq. 13) — not a square, and
possibly negative — and `hypot` has nowhere to put it, so
the emitter falls back to `sqrt` rather than dropping the
cross term.

### Scope note — `FortranTarget` is not supported

EARS REQ-071 mentions "CTarget or FortranTarget when
available". **Symbolics 7 does not export `FortranTarget`**
— see
[`upstream-bugs.md` UB-004](https://github.com/s-celles/SymbolicUncertainties.jl/blob/main/upstream-bugs.md).
Only `JuliaTarget()` and `CTarget()` are supported. Requests
for other targets raise `ArgumentError` listing the
supported set.

Users who need Fortran bindings can wrap the C output via
`iso_c_binding` or translate the emitted source manually.

## `to_expr` — escape hatch for downstream pipelines

```@example code-generation
(v, e) = to_expr(R_m)
# v, e are Symbolics.Num — pipe to ModelingToolkit.jl, a
# hand-written LaTeX template, or your own code generator.
```

`to_expr` returns the `(m.val, m.err)` pair. The `m.dof`
field is **not** included — users who need it read
`m.dof` directly.

## `latex(m)`

`latex(m)` renders a measurement for a calibration
certificate. It is provided by the
`SymbolicUncertaintiesLatexifyExt` package extension, so it
needs `Latexify.jl` in the session:

```julia
using Latexify
latex(R_m)
```

Called without `Latexify.jl` loaded it raises an
`ArgumentError` naming the package to load, rather than an
`UndefVarError` on a name that would otherwise not exist.

Two alternatives need no extension at all:

- [`Base.show(io, MIME"text/latex", m)`](display-substitute-safety.md)
  — emits `$val \pm err$` automatically in Jupyter / Pluto.
- `to_expr(m)` plus a handwritten LaTeX template.

## Calibration-certificate snippet (hand-rolled example)

```@example code-generation
@variables V I σV σI
R = (V ± σV) / (I ± σI)

# building blocks:
(v, e) = to_expr(R)
g_compiled = build_evaluator(R, [V, I, σV, σI])
c_source = build_evaluator(R, [V, I, σV, σI]; target = CTarget())

# Hand-rolled certificate line:
certificate_line = "\\[ R = $(v) \\pm $(e) \\]"
# (with Latexify.jl loaded: certificate_line = latex(R))
```

## Performance

The compiled Julia evaluator achieves sub-100 ns per call
on typical GUM measurements — at least two orders of
magnitude faster than the `substitute + toexpr + eval`
path. The speedup is documented but not CI-gated; users
verify with `@btime` from `BenchmarkTools.jl`.

## Error paths

- **Unsupported target** (e.g. `:bogus` or `FortranTarget`)
  → `ArgumentError` listing `JuliaTarget` / `CTarget` and
  noting the FortranTarget deferral per UB-004.
- **Empty variables + non-numeric measurement** →
  `Symbolics.build_function` error propagates.
- **`latex(m)` called without Latexify.jl** →
  `ArgumentError` naming the package to load.

## API reference

```@docs
build_evaluator
to_expr
latex
```
