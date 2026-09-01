using Documenter
using DocumenterLandingPage
using SymbolicUncertainties

include("pages.jl")

# Doctests run with these bindings in scope, so a `jldoctest` block
# does not have to repeat its imports.
DocMeta.setdocmeta!(
    SymbolicUncertainties,
    :DocTestSetup,
    :(using SymbolicUncertainties, Symbolics);
    recursive = true,
)

makedocs(;
    modules = [SymbolicUncertainties],
    authors = "Sébastien Celles <s.celles@gmail.com>",
    sitename = "SymbolicUncertainties.jl",
    format = Documenter.HTML(;
        canonical = "https://s-celles.github.io/SymbolicUncertainties.jl",
        edit_link = "main",
        assets = String[],
        # A symbolic uncertainty library emits large expressions by
        # nature; the default 200 KiB page budget is tuned for prose.
        size_threshold = 500_000,
        size_threshold_warn = 400_000,
    ),
    pages = pages,
    plugins = [LandingPage()],
    warnonly = false,
)

if get(ENV, "GITHUB_ACTIONS", "") == "true"
    deploydocs(;
        repo = "github.com/s-celles/SymbolicUncertainties.jl.git",
        devbranch = "main",
        push_preview = true,
    )
end
