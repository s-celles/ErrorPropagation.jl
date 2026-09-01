# `latex(m)` — M7 stub. Full LaTeX rendering via
# `SymbolicUncertaintiesLatexifyExt` lands in M8 (see
# `specs/009-code-gen-and-latex/contracts/latex_stub.md` and
# research R6).
#
# Until then, calling `latex(m)` raises `ArgumentError`
# with an actionable message pointing at `Latexify.jl` and
# the M4 `Base.show(io, MIME"text/latex", m)` alternative.
#
# The fallback is declared `(args...; kwargs...)` — strictly
# more general than the extension's `::SymbolicMeasurement`
# method — so that loading `Latexify.jl` *adds* a method
# instead of overwriting this one. Julia >= 1.12 makes method
# overwriting during module precompilation a hard ERROR, which
# broke `SymbolicUncertaintiesLatexifyExt` precompilation while the
# stub still declared the concrete signature. This mirrors the
# M9 `src/mtk_stubs.jl` pattern.

"""
    latex(m::SymbolicMeasurement) -> String

!!! note "M7 stub"
    The full `latex(m)` implementation ships as an
    `SymbolicUncertaintiesLatexifyExt` package extension in
    Milestone **M8**. Until then, this function raises
    `ArgumentError` with a message pointing at
    [`Latexify.jl`](https://github.com/korsbo/Latexify.jl)
    and the M4
    [`Base.show(io, MIME\"text/latex\", m)`](@ref) method as
    the current notebook-rendering alternative.

Return a LaTeX-formatted `String` representation of the
measurement suitable for direct inclusion in a calibration
certificate (planned M8 behaviour). Matches the reporting
posture of JCGM 100:2008 §7 (reporting uncertainty).

Traces REQ-072 (deferred to M8).
"""
function latex(args...; kwargs...)
    throw(
        ArgumentError(
            "latex(m): full LaTeX rendering requires " *
            "`Latexify.jl`. Load it via `using Latexify` — " *
            "the M8 `SymbolicUncertaintiesLatexifyExt` will " *
            "provide the closed-form implementation. For " *
            "immediate LaTeX output, use the M4 " *
            "`Base.show(io, MIME\"text/latex\", m)` method " *
            "which emits `\$val \\pm err\$` via the minimal " *
            "in-library formatter (REQ-072 deferred to M8).",
        ),
    )
end
