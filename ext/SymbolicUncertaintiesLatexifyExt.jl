module SymbolicUncertaintiesLatexifyExt

# Full LaTeX rendering — replaces the M7 stub with a
# `Latexify.latexify`-backed implementation when Latexify.jl is
# loaded. See `specs/010-package-extensions/contracts/ext_latexify.md`.

import SymbolicUncertainties
import Latexify

function SymbolicUncertainties.latex(
    m::SymbolicUncertainties.SymbolicMeasurement,
)
    val_s = Latexify.latexify(m.val)
    err_s = Latexify.latexify(m.err)
    return "$(val_s) \\pm $(err_s)"
end

end
