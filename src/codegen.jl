# Code generation — JCGM 100:2008 §7 / §9 deployment
# pathway.
#
# `build_evaluator(m, variables; target, fname)` compiles
# the `(m.val, m.err)` computation to a Julia callable or
# Common-subexpression elimination is on for the Julia target (M12).
# The sensitivity coefficients of a measurand share most of their
# structure — for a product, each one is the product of all the OTHER
# inputs — so without CSE the emitted code recomputes them once per
# source and the redundancy grows quadratically in the number of
# sources.
#
# The C target does not accept `cse`: Symbolics' `_build_function`
# for `CTarget` has no such keyword. C compilers do their own common
# subexpression elimination, so the loss is on emitted source size
# rather than on runtime.
#
# emits C source, via `Symbolics.build_function`. See
# `specs/009-code-gen-and-latex/research.md` R1–R4.
#
# `to_expr(m)` extracts the `(m.val, m.err)` tuple for
# downstream symbolic pipelines (REQ-073).

# `sqrt(Σ (cᵢuᵢ)²)` is exact in algebra and fragile in floating point:
# it overflows once any `cᵢuᵢ` exceeds about 1e154 and underflows to
# zero below about 1e-150, where `hypot` — `math.h` in C, Base in
# Julia — returns the right answer. The symbolic form is left alone,
# because `sqrt` of a sum of squares is the readable one and the one
# every GUM text writes; only the emitted code changes.
#
# The rewrite applies exactly when every addend is a square, which is
# the uncorrelated regime. Under a declared correlation the variance
# carries `2·cᵢcⱼ·u(xᵢ,xⱼ)` (JCGM 100:2008 eq. 13) — not a square, and
# possibly negative — so the walk bails out and `sqrt` is emitted
# rather than a term being silently dropped.
#
# Traces REQ-074, REQ-216.
const _SU = Symbolics.SymbolicUtils

# The exact square root of a product of even powers, or `nothing`.
function _exact_sqrt(t)
    v = Symbolics.value(t)
    if v isa Real && !(v isa Symbolics.Num)
        v < 0 && return nothing
        r = sqrt(float(v))
        return isinteger(r) ? Symbolics.Num(Int(r)) : nothing
    end
    (v isa _SU.BasicSymbolic && _SU.iscall(v)) || return nothing

    op = _SU.operation(v)
    args = _SU.arguments(v)
    if op === (^)
        length(args) == 2 || return nothing
        e = Symbolics.value(args[2])
        (e isa Integer && iseven(e)) || return nothing
        return Symbolics.Num(args[1])^(e ÷ 2)
    elseif op === (*)
        acc = Symbolics.Num(1)
        for a in args
            r = _exact_sqrt(a)
            r === nothing && return nothing
            acc = acc * r
        end
        return acc
    end
    return nothing
end

# Rewrite `sqrt(t₁² + … + tₙ²)` as nested binary `hypot`. Binary
# because C has no variadic `hypot`.
function _hypot_form(expr::Symbolics.Num)
    v = Symbolics.value(expr)
    (v isa _SU.BasicSymbolic && _SU.iscall(v)) || return expr
    _SU.operation(v) === sqrt || return expr

    inner = _SU.arguments(v)[1]
    addends =
        (
            inner isa _SU.BasicSymbolic &&
            _SU.iscall(inner) &&
            _SU.operation(inner) === (+)
        ) ? _SU.arguments(inner) : [inner]
    length(addends) < 2 && return expr

    roots = Symbolics.Num[]
    for a in addends
        r = _exact_sqrt(a)
        r === nothing && return expr
        push!(roots, r)
    end

    acc = roots[1]
    for r in roots[2:end]
        acc = hypot(acc, r)
    end
    return acc
end

"""
    build_evaluator(m, variables; target = JuliaTarget(), fname = :evaluate_measurement)

Compile the `(m.val, m.err)` computation of the
`SymbolicMeasurement` `m` into a Julia callable (default) or
emit C source as a `String`, depending on `target`.

# Arguments

- `m::SymbolicMeasurement` — the measurement to compile.
- `variables::AbstractVector{<:Num}` — the symbolic input
  variables in positional order.
- `target` (keyword, default `JuliaTarget()`) — code-
  generation target. Supported: `JuliaTarget()`,
  `CTarget()`. Any other value raises `ArgumentError`.
- `fname` (keyword, default `:evaluate_measurement`) —
  name of the generated C function. Ignored for
  `JuliaTarget`.

# Returns

- `target = JuliaTarget()` — a Julia callable
  `g(args...) -> Tuple{Float64, Float64}` accepting the
  variable values positionally and returning `(val, err)`.
  Runtime-compiled (`expression = Val{false}`), sub-100 ns
  per call on typical GUM measurements.
- `target = CTarget()` — a `String` containing a C
  function definition. Begins with `#include <math.h>` and
  defines `void <fname>(double *out, const double arg1, …)`.

# Special cases

- When `variables` is empty and `m` is fully numeric (both
  `m.val` and `m.err` unwrap to a plain `Real`), returns a
  zero-argument closure yielding the numeric
  `(val, err)` pair.

# Errors

- Unsupported `target` (including `FortranTarget` —
  Symbolics.jl 7 does not export it, see
  `upstream-bugs.md` UB-004) → `ArgumentError` listing
  supported targets.
- `Symbolics.build_function` errors (e.g. variables
  missing from the expression) are re-raised unchanged.

Implements the deployment pathway of JCGM 100:2008 §9.
Traces REQ-070 (Julia target) and REQ-071 (C target).
"""
function build_evaluator(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num};
    target = Symbolics.JuliaTarget(),
    fname::Symbol = :evaluate_measurement,
)
    # Empty-variables fast path for fully-numeric measurements.
    if isempty(variables)
        val_raw = Symbolics.value(m.val)
        err_raw = Symbolics.value(m.err)
        if val_raw isa Real &&
           !(val_raw isa Symbolics.Num) &&
           err_raw isa Real &&
           !(err_raw isa Symbolics.Num)
            v, e = Float64(val_raw), Float64(err_raw)
            return () -> (v, e)
        end
    end

    if target isa Symbolics.JuliaTarget
        f_vec = first(
            Symbolics.build_function(
                [m.val, _hypot_form(m.err)],
                variables...;
                expression = Val{false},
                cse = true,
            ),
        )
        return (args...) -> begin
            out = f_vec(args...)
            (Float64(out[1]), Float64(out[2]))
        end
    elseif target isa Symbolics.CTarget
        return Symbolics.build_function(
            [m.val, _hypot_form(m.err)],
            variables...;
            target = Symbolics.CTarget(),
            fname = fname,
        )
    else
        throw(
            ArgumentError(
                "build_evaluator: unsupported `target = $(target)`. " *
                "M7 supports `JuliaTarget()` and `CTarget()`. " *
                "`FortranTarget` is not exported by Symbolics.jl 7 " *
                "(see `upstream-bugs.md` UB-004).",
            ),
        )
    end
end

"""
    to_expr(m::SymbolicMeasurement) -> Tuple{Num, Num}

Return the `(m.val, m.err)` pair for downstream symbolic
manipulation. Destructurable via `(v, e) = to_expr(m)`.

The `m.dof` field is **not** included — users who need it
read `m.dof` directly. Export utility for downstream
reporting per JCGM 100:2008 §7.

Traces REQ-073.
"""
to_expr(m::SymbolicMeasurement) = (m.val, m.err)
