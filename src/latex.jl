# LaTeX display for `SymbolicMeasurement` — JCGM 100:2008 §7.2.2
# textual presentation convention, extended to rich-display
# consumers (Jupyter, Pluto, VS Code notebooks).
#
# The output includes surrounding `$...$` inline math delimiters
# per Clarifications Q1 so notebooks render the output as math
# without caller intervention. The formatter itself is
# intentionally minimal (research R3) — it defers to
# `Base.string(expr)` for the fragment content. Users who want
# production-grade LaTeX can load `Latexify.jl` and call it on
# `m.val` / `m.err` themselves; a future milestone may
# introduce an optional `SymbolicUncertaintiesLatexifyExt.jl`
# extension for automatic upgrade.

# `Base.show` specialisation for MIME"text/latex" — emits
# `$val \pm err$` with inline math delimiters included per
# Clarifications Q1. See `docs/src/display-substitute-safety.md`
# for the full user-facing documentation. Traces REQ-112
# (JCGM 100:2008 §7.2.2).
function Base.show(io::IO, ::MIME"text/latex", m::SymbolicMeasurement)
    val_s = _latex_fragment(m.val)
    err_s = _latex_fragment(m.err)
    print(io, "\$", val_s, " \\pm ", err_s, "\$")
end

# Minimal LaTeX fragment for a `Symbolics.Num`. Uses a concrete
# numeric rendering when the value unwraps to a plain `Real`, and
# falls back to `Base.string(expr)` otherwise. The fallback is
# intentional — complex expressions render as a plain-text form
# which some LaTeX engines accept and others render verbatim; the
# M4 scope is the `MIME"text/latex"` plumbing, not a full
# symbolic-to-LaTeX formatter.
function _latex_fragment(expr::Symbolics.Num)
    raw = Symbolics.value(expr)
    if raw isa Real && !(raw isa Symbolics.Num)
        return string(raw)
    end
    return string(expr)
end
