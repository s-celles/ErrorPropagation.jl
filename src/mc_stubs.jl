# Monte Carlo cross-validation — the package side of the extension.
#
# `monte_carlo` and its result type live here so that the name exists
# without `MonteCarloMeasurements.jl`, and so that calling it without
# that package says which one to load rather than raising
# `UndefVarError` on a name the documentation mentions.
#
# The stub is declared with a signature strictly more general than the
# extension's, so the extension ADDS a method rather than overwriting
# one: method overwriting during precompilation is a hard error on
# Julia ≥ 1.12, which is how the Latexify stub broke once already.
#
# Traces REQ-230.

"""
    MonteCarloComparison

The result of cross-checking a first-order GUM propagation against a
Monte Carlo propagation of the same measurement model
(JCGM 101:2008 §8).

- `n` — total number of Monte Carlo trials.
- `blocks` — how many blocks of trials the adaptive procedure of
  JCGM 101:2008 §7.9 drew; `1` for a single non-adaptive run.
- `converged` — whether that procedure stabilised. It is `false` for a
  single run because nothing checked, which is not the same as
  checked and failed; the two are distinguished by `blocks`.
- `estimate_gum`, `u_gum` — the first-order estimate and combined
  standard uncertainty, JCGM 100:2008 §5.1.2.
- `estimate_mc`, `u_mc` — the mean and standard deviation of the
  sampled output distribution, JCGM 101:2008 §7.6.
- `interval_gum`, `interval_mc` — the coverage intervals compared by
  the §8.2 validation test, at `coverage_probability`.
- `ndig` — the number of significant digits of `u_gum` regarded as
  meaningful, which fixes the numerical tolerance of that test.
- `validated` — whether the first-order result passes it.

A Monte Carlo run never changes the symbolic result (REQ-234): this
is a check on the framework, not a correction to it.

Traces REQ-230, REQ-233.
"""
struct MonteCarloComparison
    n::Int
    blocks::Int
    converged::Bool
    estimate_gum::Float64
    u_gum::Float64
    estimate_mc::Float64
    u_mc::Float64
    interval_gum::Tuple{Float64,Float64}
    interval_mc::Tuple{Float64,Float64}
    coverage_probability::Float64
    ndig::Int
    tolerance::Float64
    validated::Bool
end

function Base.show(io::IO, ::MIME"text/plain", c::MonteCarloComparison)
    println(io, "Monte Carlo cross-validation (JCGM 101:2008 §8.2)")
    println(
        io,
        "  trials              : ",
        c.n,
        c.blocks > 1 ?
        " ($(c.blocks) blocks, " *
        (c.converged ? "stabilised" : "NOT stabilised") *
        ")" : "",
    )
    println(io, "  GUM   y ± u_c       : ", c.estimate_gum, " ± ", c.u_gum)
    println(io, "  MC    y ± u_c       : ", c.estimate_mc, " ± ", c.u_mc)
    println(io, "  coverage probability: ", c.coverage_probability)
    println(io, "  GUM interval        : ", c.interval_gum)
    println(io, "  MC  interval        : ", c.interval_mc)
    println(io, "  tolerance (", c.ndig, " digits) : ", c.tolerance)
    print(
        io,
        "  ",
        c.validated ? "VALIDATED — the first-order result agrees" :
        "NOT VALIDATED — the linearisation is inadequate here",
    )
    return nothing
end

Base.show(io::IO, c::MonteCarloComparison) = print(
    io,
    "MonteCarloComparison(",
    c.validated ? "validated" : "not validated",
    ", n=",
    c.n,
    ")",
)

"""
    monte_carlo(m::SymbolicMeasurement, distributions; kwargs...)

Propagate `m`'s measurement model by a Monte Carlo method and compare
the result against the first-order one (JCGM 101:2008 §8).

Requires `MonteCarloMeasurements.jl` to be loaded; the distributions
are `Distributions.jl` objects, one per input variable.

The distribution of each input is **supplied by the caller and never
defaulted** (REQ-231). A standard uncertainty is not a distribution:
JCGM 101 §6.4 assigns a rectangular density to a Type B evaluation
stated as a half-width and a normal one to a Type A evaluation, and
the choice changes the answer. Defaulting to normal would also make
the validation circular, since a run that assumes normality cannot
detect that normality was the wrong assumption.

Traces REQ-230, REQ-231.
"""
function monte_carlo(args...; kwargs...)
    throw(
        ArgumentError(
            "monte_carlo requires both `MonteCarloMeasurements.jl` " *
            "and `Distributions.jl` to be loaded — the first samples, " *
            "the second describes each input's density. Add " *
            "`using MonteCarloMeasurements, Distributions` to " *
            "activate the SymbolicUncertaintiesMonteCarloExt package " *
            "extension.",
        ),
    )
end
