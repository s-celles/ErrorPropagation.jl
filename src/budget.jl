# EA-4/02 §7.3 uncertainty-budget table — the user-visible
# reporting layer.
#
# The row schema mirrors the EA-4/02 §7.3 column layout: the source,
# its standard uncertainty, the sensitivity coefficient, the
# contribution and the relative variance fraction.
#
# M3 returned a bare `Vector{NamedTuple}`, which avoided an optional
# dependency but could not carry what a budget is *about*: a table of
# contributions says nothing about which measurand they decompose,
# what `u_c` they recombine into, or whether a declared correlation
# makes the percentage column stop summing to 1. `UncertaintyBudget`
# holds those three facts beside the rows and stays an
# `AbstractVector{BudgetRow}`, so every consumer that iterates,
# indexes or measures a budget is untouched (REQ-209).
#
# Internal helper `_uncertainty_budget_rows` is extracted in the
# M8 refactor so the `SymbolicUncertaintiesDataFramesExt` extension can
# overload the public `uncertainty_budget` to return a DataFrame
# without duplicating the row-construction logic. See
# `specs/010-package-extensions/research.md` R4.

"""
    BudgetRow

One line of an [`UncertaintyBudget`](@ref): the EA-4/02 §7.3 columns
for a single contribution.

- `source` — the [`SourceId`](@ref) of the independent measurement
  this row decomposes, or `nothing` for a row produced by the
  variable-filtered form.
- `variable` — the input variable `xᵢ` this row decomposes, when the
  source was built from a bare input variable. It is `nothing` for a
  source built from a numeric or derived estimate, which has no input
  symbol to name — which is why `source` and `variable` cannot be one
  field.
- `name` — the source's display name.
- `sigma` — its standard uncertainty `u(xᵢ)` (JCGM 100:2008 §4.1.5).
- `sensitivity` — `cᵢ = ∂f/∂xᵢ` (§5.1.3 equation (11b)).
- `contribution` — `uᵢ(y) = |cᵢ|·u(xᵢ)` (§5.1.3 equation (11a)).
- `relative` — `uᵢ²(y)/u_c²(y)`, the EA-4/02 §7.3
  percentage-of-variance column.

Traces REQ-209.
"""
struct BudgetRow
    source::Union{SourceId,Nothing}
    variable::Union{Symbolics.Num,Nothing}
    name::Symbol
    sigma::Symbolics.Num
    sensitivity::Symbolics.Num
    contribution::Symbolics.Num
    relative::Symbolics.Num
end

"""
    UncertaintyBudget <: AbstractVector{BudgetRow}

The EA-4/02 §7.3 uncertainty budget of a measurand: its rows, plus
the three facts a bare vector of rows cannot carry.

- `measurand` — the estimate `y` the rows decompose.
- `uc` — the combined standard uncertainty they recombine into
  (JCGM 100:2008 §5.1.2).
- `rows` — one [`BudgetRow`](@ref) per contribution.
- `correlated` — whether the quantity carries declared covariances.
  It matters for reading the table: under §5.2.2 equation (13) the
  cross terms belong to no single row, so the `relative` column stops
  summing to 1 and a negative cross term can push one row past 100 %.

A budget indexes and iterates as a vector of its rows, so it drops
into `DataFrames`, `PrettyTables` or a plain `for` loop unchanged.

Traces REQ-209, REQ-044, REQ-206.
"""
struct UncertaintyBudget <: AbstractVector{BudgetRow}
    measurand::Symbolics.Num
    uc::Symbolics.Num
    rows::Vector{BudgetRow}
    correlated::Bool
end

Base.size(b::UncertaintyBudget) = size(getfield(b, :rows))
Base.getindex(b::UncertaintyBudget, i::Int) = getfield(b, :rows)[i]
Base.IndexStyle(::Type{UncertaintyBudget}) = IndexLinear()

function Base.show(io::IO, b::UncertaintyBudget)
    print(
        io,
        "UncertaintyBudget(",
        length(b),
        " source",
        length(b) == 1 ? "" : "s",
        b.correlated ? ", correlated" : "",
        ")",
    )
    return nothing
end

function Base.show(io::IO, ::MIME"text/plain", b::UncertaintyBudget)
    println(io, "Uncertainty budget (EA-4/02 §7.3) for y = ", b.measurand)
    for r in b
        label = r.variable === nothing ? string(r.name) : string(r.variable)
        println(
            io,
            "  ",
            label,
            ":  u = ",
            r.sigma,
            "   c = ",
            r.sensitivity,
            "   |c|u = ",
            r.contribution,
        )
    end
    print(io, "  u_c = ", b.uc)
    b.correlated && print(
        io,
        "\n  (correlated sources declared — the relative column is not a ",
        "variance decomposition; JCGM 100:2008 §5.2.2 eq. (13))",
    )
    return nothing
end

# Internal helper — computes the Vector{NamedTuple} row set.
# The public `uncertainty_budget` wraps this; the M8 DataFrames
# extension calls the helper directly and wraps the result in a
# DataFrame.
# Source-derived budget rows — M11 phase 4, REQ-206.
#
# The quantity knows which independent sources it derives from and
# with what sensitivity, so the rows follow from `terms`. Requiring
# the caller to restate `variables` and `sigmas` asked for
# information the object already holds — and could not express a
# source that has no user-facing symbol.
#
# Cancelled sources are absent from `terms` by construction, so they
# produce no zero rows.
function _uncertainty_budget_rows(m::SymbolicMeasurement)
    terms = terms_of(m)
    srcs = sources_of(m)
    uc = m.err
    ids = sort!(collect(keys(terms)); by = s -> s.id)

    # A source of zero standard uncertainty is not a source of
    # uncertainty, and a budget row for one is noise: it has a zero
    # contribution and a zero variance fraction by construction.
    #
    # `_wrap` mints one for every constant operand, so a model written
    # with literal coefficients — `a₁·T + a₂·T²`, a calibration
    # polynomial, anything with a unit conversion in it — produced a
    # budget in which the real inputs were outnumbered by empty rows.
    # The rule already applied when forming the variance and in the
    # Monte Carlo extension; it belongs here too.
    filter!(sid -> !isequal(Symbolics.value(srcs[sid].u), 0), ids)

    return [
        BudgetRow(
            sid,
            # The source knows which input it perturbs, when that
            # input was a bare variable, so a source-derived row can
            # name it exactly as a variable-filtered one does.
            srcs[sid].variable,
            srcs[sid].name,
            srcs[sid].u,
            terms[sid],
            abs(terms[sid]) * srcs[sid].u,
            (terms[sid] * srcs[sid].u)^2 / uc^2,
        ) for sid in ids
    ]
end

function _uncertainty_budget_rows(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num},
    sigmas::AbstractVector{<:Symbolics.Num},
)
    if length(variables) != length(sigmas)
        throw(
            DimensionMismatch(
                "uncertainty_budget: length(variables)=$(length(variables)), " *
                "length(sigmas)=$(length(sigmas))",
            ),
        )
    end

    rows = map(zip(variables, sigmas)) do (xᵢ, σᵢ)
        c = sensitivity_coefficient(m, xᵢ)
        BudgetRow(
            nothing,
            xᵢ,
            Symbol(string(xᵢ)),
            σᵢ,
            c,
            abs(c) * σᵢ,
            (c * σᵢ)^2 / m.err^2,
        )
    end

    return collect(rows)
end

"""
    uncertainty_budget(m; as = :budget) -> UncertaintyBudget
    uncertainty_budget(m, variables, sigmas; as = :budget)

Produce the EA-4/02 §7.3 uncertainty-budget table for the
measurement `m`.

The one-argument form derives its rows from the quantity's own
sources: `m` knows which independent measurements it descends from
and with what sensitivity, so restating them would ask for
information it already holds — and could not express a source with no
user-facing symbol (REQ-206). A source that cancelled produces no row
at all.

The three-argument form is a **filter**, kept for the case where only
some inputs are of interest: rows follow `variables`, and a variable
absent from `m.val` yields a zero row rather than an error.

Each [`BudgetRow`](@ref) carries the EA-4/02 §7.3 columns:

- `sigma` — the standard uncertainty `u(xᵢ)`.
- `sensitivity` — `cᵢ = ∂f/∂xᵢ` (JCGM 100:2008 §5.1.3 eq. (11b)).
- `contribution` — `uᵢ(y) = |cᵢ|·u(xᵢ)` (§5.1.3 eq. (11a)).
- `relative` — `uᵢ²(y)/u_c²(y)`, the percentage-of-variance column.

The [`UncertaintyBudget`](@ref) returned also carries the measurand,
its `u_c` and whether declared correlations are in play; it indexes
and iterates as a vector of rows.

Invariants:

- For independent sources `sum(row.relative for row in budget)`
  simplifies to `1` (REQ-045 / REQ-152). Under declared correlation
  it does not, and `budget.correlated` says so: the §5.2.2 eq. (13)
  cross terms belong to no single row.

Errors:

- `length(variables) != length(sigmas)` raises `DimensionMismatch`.
- An unresolved symbolic differential in a per-row sensitivity
  propagates the REQ-021 `ArgumentError` from
  `sensitivity_coefficient`.

Pass `as = :dataframe` to render the same budget as a `DataFrame`;
that requires `DataFrames.jl` to be loaded (REQ-044).

Implements the methodology of JCGM 100:2008 §5.1.3 and the
layout of EA-4/02 §7.3. Traces REQ-044, REQ-206, REQ-209.
"""
function uncertainty_budget(m::SymbolicMeasurement; as::Symbol = :budget)
    return _dispatch_budget(_budget(m, _uncertainty_budget_rows(m)), as)
end

function uncertainty_budget(
    m::SymbolicMeasurement,
    variables::AbstractVector{<:Symbolics.Num},
    sigmas::AbstractVector{<:Symbolics.Num};
    as::Symbol = :budget,
)
    return _dispatch_budget(
        _budget(m, _uncertainty_budget_rows(m, variables, sigmas)),
        as,
    )
end

# Wrap rows with what they decompose. `correlated` is a property of
# the quantity, not of the rows: a declared covariance changes how the
# relative column must be read even when it appears in no single row.
_budget(m::SymbolicMeasurement, rows::Vector{BudgetRow}) =
    UncertaintyBudget(m.val, m.err, rows, !isempty(cov_of(m)))

# Rendering dispatch, shared by both `uncertainty_budget` methods.
# `:budget` is the value itself; `:dataframe` is one rendering of it,
# which is why the DataFrames extension is a renderer rather than a
# second implementation.
function _dispatch_budget(budget::UncertaintyBudget, as::Symbol)
    if as === :budget
        return budget
    elseif as === :dataframe
        # Requires the M8 DataFrames extension to be loaded.
        ext =
            Base.get_extension(@__MODULE__, :SymbolicUncertaintiesDataFramesExt)
        if ext === nothing
            throw(
                ArgumentError(
                    "uncertainty_budget(...; as = :dataframe) requires " *
                    "`DataFrames.jl` to be loaded. Add `using DataFrames` " *
                    "to your session to activate the M8 " *
                    "`SymbolicUncertaintiesDataFramesExt` package extension.",
                ),
            )
        end
        return ext._budget_as_dataframe(budget)
    else
        throw(
            ArgumentError(
                "uncertainty_budget: `as` must be `:budget` (default) " *
                "or `:dataframe`; got $as. The `:namedtuple` rendering " *
                "was replaced by the `UncertaintyBudget` value itself, " *
                "which still indexes and iterates as a vector of rows.",
            ),
        )
    end
end
