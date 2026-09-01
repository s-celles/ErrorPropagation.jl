# Welch-Satterthwaite effective degrees of freedom — JCGM 100:2008
# §G.4 equation (G.2b):
#
#   ν_eff = (Σᵢ uᵢ²)² / Σᵢ (uᵢ⁴ / νᵢ)
#
# The expression is left symbolic; no numeric evaluation is
# performed. An all-zero-contributions input returns the formal
# `0/0` symbolic expression unchanged — see
# `specs/005-budget-and-expanded/research.md` R10.

"""
    welch_satterthwaite(contributions, dofs) -> Num

!!! warning "Coverage factor assumptions"
    The Welch-Satterthwaite effective degrees of freedom support
    the Student-t pathway of `expanded_uncertainty(m;
    coverage_probability)`. The `k = 2` shortcut of
    `expanded_uncertainty(m, 2)` assumes `ν_eff ≥ 30`; below that
    threshold, JCGM 100:2008 §6.3.3 requires the t-quantile path
    this function enables.

Return the symbolic effective degrees of freedom `ν_eff` per
JCGM 100:2008 §G.4 equation (G.2b):

```
ν_eff = (Σᵢ uᵢ²)² / Σᵢ (uᵢ⁴ / νᵢ)
```

where `uᵢ` are the per-variable uncertainty contributions
(typically from `uncertainty_contribution`) and `νᵢ` the
associated degrees of freedom.

Raises `DimensionMismatch` when the two lists differ in length.

Edge case: empty lists or all-zero contributions produce the
formal `0/0` symbolic expression unchanged — no special-case
substitution to `Inf`.

Implements the methodology of JCGM 100:2008 §G.4. Traces
REQ-052, REQ-174.
"""
function welch_satterthwaite(
    contributions::AbstractVector{<:Symbolics.Num},
    dofs::AbstractVector{<:Symbolics.Num},
)
    if length(contributions) != length(dofs)
        throw(
            DimensionMismatch(
                "welch_satterthwaite: length(contributions)=" *
                "$(length(contributions)), length(dofs)=$(length(dofs))",
            ),
        )
    end

    numerator = sum(u^2 for u in contributions; init = Symbolics.Num(0))
    denominator = sum(
        u^4 / ν for (u, ν) in zip(contributions, dofs);
        init = Symbolics.Num(0),
    )

    return numerator^2 / denominator
end
