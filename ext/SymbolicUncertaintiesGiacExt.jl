module SymbolicUncertaintiesGiacExt

# Package extension: enhances `SymbolicUncertainties._simplify_for_report`
# with Giac.jl's CAS-grade symbolic simplification.
#
# Loaded automatically when both `SymbolicUncertainties` and `Giac` are
# present. The override is strictly additive: it only ever returns an
# expression mathematically equal to the Symbolics default, but may
# collapse identities the default engine leaves unreduced (e.g.
# `-tan(x) + sin(x)/cos(x) → 0`).

import SymbolicUncertainties
import Symbolics
import Giac

const _SymNum = Symbolics.Num

function _giac_simplify(expr::_SymNum)
    giac_in = Giac.to_giac(expr)
    giac_out = Giac.Commands.simplify(giac_in)
    return Giac.to_symbolics(giac_out)
end

# The fallback is deliberate — a CAS that cannot parse one expression
# must not take down a propagation — but it must not be SILENT: a
# swallowed failure turns "Giac is loaded" into a claim the package
# cannot honour, with no way for the user to tell. Giac's parser
# writes its own diagnostics to stderr (see `upstream-bugs.md`
# UB-005), so the `@debug` records which expression was dropped.
function SymbolicUncertainties._simplify_for_report(expr::_SymNum)
    try
        result = _giac_simplify(expr)
        # `to_symbolics` can return a raw number when Giac reduces to a
        # constant; re-wrap as Num so downstream callers get a uniform
        # type.
        return result isa _SymNum ? result : _SymNum(result)
    catch err
        @debug "Giac simplification failed; falling back to Symbolics" expr err
        return Symbolics.simplify(expr)
    end
end

end # module SymbolicUncertaintiesGiacExt
