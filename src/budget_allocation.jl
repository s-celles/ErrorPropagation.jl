# Protocol-optimisation budget allocation — JCGM 100:2008 §5.2.2
# minimised under a linear budget constraint.
#
# For a measurement with sensitivity coefficients cᵢ = ∂f/∂xᵢ
# and a linear budget constraint Σᵢ σᵢ = total_budget, the
# Lagrange-optimal allocation that minimises `m.err =
# sqrt(Σ (cᵢ·σᵢ)²)` is (research R5):
#
#     σᵢ* = total_budget · (1/cᵢ²) / Σⱼ (1/cⱼ²)
#
# This closed form covers every case where M3's
# `sensitivity_coefficient` succeeds. No general-purpose solver
# is required.

"""
    budget_allocation(m, variables, sigmas, total_budget) -> Dict{Num, Num}

Return the Lagrange-multiplier optimal allocation of a fixed
total uncertainty budget across inputs: the `σᵢ*` values that
minimise `m.err` subject to the linear constraint
`Σᵢ σᵢ = total_budget`.

Uses the closed-form inverse-sensitivity-squared weighting
(research R5):

```
σᵢ* = total_budget · (1 / cᵢ²) / Σⱼ (1 / cⱼ²)
```

where `cᵢ = sensitivity_coefficient(m, xᵢ)`.

Errors:

- `length(variables) != length(sigmas)` → `DimensionMismatch`.
- Numeric `total_budget < 0` → `ArgumentError`.
- Every `cᵢ` symbolically zero (the measurand is independent
  of every supplied input) → `ArgumentError` per REQ-091.
- Per-variable `sensitivity_coefficient` failure propagates
  the standard M2 REQ-021 `ArgumentError`.

Invariant: summing the returned values and simplifying gives
`total_budget` (the budget constraint).

Implements the methodology of JCGM 100:2008 §5.2.2 squared
and minimised under the linear budget constraint. Traces
REQ-061, REQ-062.
"""
function budget_allocation(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num},
    sigmas::AbstractVector{<:Symbolics.Num},
    total_budget,
)
    if length(variables) != length(sigmas)
        throw(
            DimensionMismatch(
                "budget_allocation: length(variables)=" *
                "$(length(variables)), length(sigmas)=$(length(sigmas))",
            ),
        )
    end
    if total_budget isa Real &&
       !(total_budget isa Symbolics.Num) &&
       total_budget < 0
        throw(
            ArgumentError(
                "budget_allocation: `total_budget` must be " *
                "non-negative; got $total_budget.",
            ),
        )
    end

    # Compute per-variable sensitivity coefficients.
    coeffs = [sensitivity_coefficient(m, xᵢ) for xᵢ in variables]

    # Detect the degenerate all-zero case: every cᵢ simplifies to 0.
    all_zero = all(c -> Symbolics.isequal(Symbolics.simplify(c), 0), coeffs)
    if all_zero
        throw(
            ArgumentError(
                "budget_allocation: all sensitivity coefficients " *
                "are zero — the measurand is independent of every " *
                "supplied input. No meaningful allocation exists. " *
                "(REQ-091)",
            ),
        )
    end

    B = Symbolics.Num(total_budget)

    # Inverse-sensitivity-squared weights.
    inv_sq = [1 / c^2 for c in coeffs]
    total_inv_sq = sum(inv_sq)

    result = Dict{Symbolics.Num,Symbolics.Num}()
    for (σᵢ, w) in zip(sigmas, inv_sq)
        result[σᵢ] = B * w / total_inv_sq
    end
    return result
end
