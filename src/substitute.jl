# Symbolic → numeric bridge — JCGM 100:2008 §5.1 measurement
# model substitution step; §7.2.2 transition to the single-line
# calibration-certificate result.
#
# Extends `Symbolics.substitute` with a `SymbolicMeasurement`
# method rather than introducing a new exported name. This
# matches the Julia convention of extending the upstream
# function that already owns the concept, and avoids the name
# clash with `Symbolics.substitute` / `DynamicPolynomials.substitute`
# / `ExproniconLite.substitute`. Users call it the same way they
# call it on any Symbolics expression:
#
#     using Symbolics, SymbolicUncertainties
#     result = substitute(m, Dict(x => 5.0, σx => 0.1))
#
# See `specs/006-display-substitute-safety/` for the full
# contract and Clarifications Q3 rationale.

"""
    Symbolics.substitute(m::SymbolicMeasurement, dict::AbstractDict)

Rewrite each of `m.val`, `m.err`, and `m.dof` (when not
`nothing`) by applying `Symbolics.substitute` with the
user-supplied replacement dictionary.

Behaviour:

- Extra dict keys not present in any of the three fields are
  silently ignored (REQ-122).
- Partial substitution is supported — unsubstituted variables
  remain symbolic in the returned measurement.
- `m.dof === nothing` is preserved (not upgraded to a
  substituted zero).
- No simplification pass is applied after substitution; users
  who want Giac-level canonicalisation should call
  `Symbolics.simplify` on the returned fields themselves.
- The REQ-005 negativity guard on the numeric constructor is
  **not** re-applied. A substituted `err` that simplifies to a
  concrete negative `Real` is returned silently — `substitute`
  is a rewriting operation, not a constructor.

Implements the methodology of JCGM 100:2008 §5.1 (the
measurement-model substitution step) and §7.2.2 (the
transition to the calibration-certificate result). Traces
REQ-120, REQ-122, REQ-123, REQ-142.
"""
function Symbolics.substitute(m::SymbolicMeasurement, dict::AbstractDict)
    # Substitution reaches the source structure directly. This is the
    # reason phase 0 rejected a module-level registry: with the source
    # uncertainties held in global state there would be nothing local
    # to substitute into, and a fully substituted measurement would
    # not yield a number (REQ-120, REQ-123, M4 exit criterion).
    new_val = Symbolics.substitute(m.val, dict)

    new_terms = _Terms()
    for (sid, c) in terms_of(m)
        new_terms[sid] = Symbolics.substitute(c, dict)
    end

    new_sources = _Sources()
    for (sid, src) in sources_of(m)
        new_sources[sid] = Source(
            Symbolics.substitute(src.u, dict),
            src.dof === nothing ? nothing : Symbolics.substitute(src.dof, dict),
            src.name,
            # The variable is a provenance label, not a value: a
            # substituted measurement must still say which input each
            # contribution came from.
            src.variable,
        )
    end

    new_cov = _Cov()
    for (k, v) in cov_of(m)
        new_cov[k] = Symbolics.substitute(v, dict)
    end

    # Source identities are preserved: substituting numbers into a
    # quantity must not turn one measurement into an unrelated one.
    return SymbolicMeasurement(new_val, new_terms, new_sources, new_cov)
end
