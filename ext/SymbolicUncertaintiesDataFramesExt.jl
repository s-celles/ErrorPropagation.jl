module SymbolicUncertaintiesDataFramesExt

# `uncertainty_budget` DataFrames upgrade — provides a
# `_budget_as_dataframe` hook that the base
# `uncertainty_budget` in `src/budget.jl` calls via
# `Base.get_extension`. See
# `specs/010-package-extensions/contracts/ext_dataframes.md`
# and research R4.
#
# This indirection avoids the Julia precompilation rule
# against same-signature method overwriting in extensions.

import SymbolicUncertainties
import Symbolics
import DataFrames

# One rendering of an `UncertaintyBudget`, not a second budget
# implementation: the rows are built once in `src/budget.jl` and this
# lays them out. Source-derived rows have no `variable` and
# variable-filtered rows have no `source`, so the column set follows
# the rows rather than being fixed.
function _budget_as_dataframe(budget::AbstractVector)
    rows = collect(budget)
    if isempty(rows)
        return DataFrames.DataFrame(
            variable = Symbolics.Num[],
            sigma = Symbolics.Num[],
            sensitivity = Symbolics.Num[],
            contribution = Symbolics.Num[],
            relative = Symbolics.Num[],
        )
    end

    common = (
        sigma = [r.sigma for r in rows],
        sensitivity = [r.sensitivity for r in rows],
        contribution = [r.contribution for r in rows],
        relative = [r.relative for r in rows],
    )

    if all(r -> r.variable !== nothing, rows)
        return DataFrames.DataFrame(;
            variable = [r.variable for r in rows],
            common...,
        )
    end
    return DataFrames.DataFrame(; source = [r.name for r in rows], common...)
end

end
