# Build-time safety helpers — JCGM 100:2008 §5.1 assumption that
# the measurand function is differentiable at the input estimate.
# Purely internal module (no exports): the helpers are called from
# the M1 binary operators, the M2 elementary-function overloads,
# and the M2 `propagate` pre-run walker.
#
# Rationale for the simple "concrete Real in `.val`" rule: Symbolics.jl
# has no `assume` / `additionally` framework for positivity queries.
# See `upstream-bugs.md` UB-003. The rule errs on the side of
# over-warning rather than silently skipping a genuine domain
# violation.

# Return `true` iff `val` unwraps to a plain Julia `Real` (not a
# `Symbolics.Num`, not a `BasicSymbolicImpl`). Used by both
# division-by-zero and sqrt/log domain checks.
function _has_provable_value(val)
    raw = Symbolics.value(val)
    return raw isa Real && !(raw isa Symbolics.Num)
end

# Emit a REQ-140 `@warn` when the denominator cannot be proven
# nonzero. Non-halting — the caller proceeds to the division.
function _warn_division_by_zero(y::SymbolicMeasurement)
    if !_has_provable_value(y.val)
        @warn (
            "Division by `y` whose `.val` is symbolic — the denominator " *
            "cannot be proven nonzero at build time " *
            "(JCGM 100:2008 §5.1, REQ-140). The returned measurement " *
            "is still valid; verify the denominator at substitution time."
        )
        return
    end
    raw = Symbolics.value(y.val)
    if iszero(raw)
        @warn (
            "Division by `y = $(raw) ± …` — the denominator is provably " *
            "zero (JCGM 100:2008 §5.1, REQ-140)."
        )
    end
end

# Emit a REQ-141 `@warn` when the argument of `sqrt` / `log` /
# `log2` / `log10` cannot be proven strictly positive. Non-halting.
function _warn_domain(fname::Symbol, m::SymbolicMeasurement)
    if !_has_provable_value(m.val)
        @warn (
            "$fname applied to a measurement whose `.val` is symbolic " *
            "— the argument cannot be proven strictly positive at build " *
            "time (JCGM 100:2008 §5.1, REQ-141). The returned " *
            "measurement is still valid; verify the argument at " *
            "substitution time."
        )
        return
    end
    raw = Symbolics.value(m.val)
    if raw <= 0
        @warn (
            "$fname applied to `m = $(raw) ± …` — the argument is " *
            "provably non-positive (JCGM 100:2008 §5.1, REQ-141)."
        )
    end
end

# Syntactic walker used by `propagate` — scan an expression tree
# for `/`, `sqrt`, `log`, `log2`, `log10` operations whose
# operand argument cannot be proven safe (denominator nonzero,
# sqrt/log argument strictly positive). Emits one `@warn` per
# detected site. Used only from `src/propagate.jl`.
function _warn_unsafe_ops_in(expr)
    w = Symbolics.unwrap(expr)
    _walk_unsafe_ops(w)
    return
end

const _DOMAIN_FUNCS = (sqrt, log, log2, log10)

function _walk_unsafe_ops(expr_w)
    if !(expr_w isa Symbolics.SymbolicUtils.BasicSymbolic)
        return
    end
    if Symbolics.SymbolicUtils.iscall(expr_w)
        op = Symbolics.SymbolicUtils.operation(expr_w)
        args = Symbolics.SymbolicUtils.arguments(expr_w)
        if op === Base.:/ && length(args) == 2
            denom = args[2]
            if !_walker_safe(denom)
                @warn (
                    "Division detected inside `propagate` whose " *
                    "denominator is symbolic at build time " *
                    "(JCGM 100:2008 §5.1, REQ-140)."
                )
            end
        elseif op in _DOMAIN_FUNCS && length(args) == 1
            arg = args[1]
            if !_walker_safe_positive(arg)
                fname = Symbol(op)
                @warn (
                    "$fname detected inside `propagate` whose " *
                    "argument is not provably positive at build time " *
                    "(JCGM 100:2008 §5.1, REQ-141)."
                )
            end
        end
        for a in args
            _walk_unsafe_ops(a)
        end
    end
    return
end

function _walker_safe(arg)
    v = arg isa Real ? arg : Symbolics.value(arg)
    return v isa Real && !iszero(v)
end

function _walker_safe_positive(arg)
    v = arg isa Real ? arg : Symbolics.value(arg)
    return v isa Real && v > 0
end

# Emit a warning when the phase `atan(y, x)` is evaluated where the
# origin cannot be excluded. Both sensitivity coefficients carry
# `x² + y²` in the denominator, so the linear model has nothing to say
# there — the same situation as a division by an unprovable
# denominator (REQ-140), and treated the same way: warn, proceed.
function _warn_undefined_phase(d::Symbolics.Num)
    if !_has_provable_value(d)
        @warn (
            "atan(y, x) where `x² + y²` cannot be proven nonzero at " *
            "build time — the phase is undefined at the origin and " *
            "both sensitivity coefficients diverge there " *
            "(JCGM 100:2008 §5.1, REQ-140). The returned measurement " *
            "is valid wherever the model is; verify at substitution " *
            "time."
        )
        return
    end
    iszero(Symbolics.value(d)) && @warn (
        "atan(y, x) at the origin: the phase is undefined and its " *
        "sensitivity coefficients diverge (JCGM 100:2008 §5.1)."
    )
end
