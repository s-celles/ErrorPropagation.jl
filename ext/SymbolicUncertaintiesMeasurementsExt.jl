module SymbolicUncertaintiesMeasurementsExt

# `Measurements.Measurement(m)` converter for fully-numeric
# `SymbolicMeasurement` values. See
# `specs/010-package-extensions/contracts/ext_measurements.md`
# and research R2 / R8.

import SymbolicUncertainties
import Symbolics
import Measurements

function _numeric(x::Symbolics.Num)
    raw = Symbolics.value(x)
    if raw isa Real && !(raw isa Symbolics.Num)
        return Float64(raw)
    end
    # Try the toexpr + eval fallback (M4 UB-001 workaround).
    try
        return Float64(eval(Symbolics.toexpr(x)))
    catch
        return nothing
    end
end

function Measurements.Measurement(m::SymbolicUncertainties.SymbolicMeasurement)
    v = _numeric(m.val)
    e = _numeric(m.err)
    if v === nothing || e === nothing
        throw(
            ArgumentError(
                "Measurement(m): `m.val` and `m.err` must reduce to " *
                "numeric constants before conversion. Call " *
                "`substitute(m, Dict(...))` first to fully reduce " *
                "the symbolic measurement.",
            ),
        )
    end
    return Measurements.measurement(v, e)
end

end
