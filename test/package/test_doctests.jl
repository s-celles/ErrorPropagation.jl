@testitem "Documenter doctests" begin
    using Documenter
    using SymbolicUncertainties

    # Documenter.doctest evaluates `@meta` and `@docs` blocks in Main,
    # not in the calling module. In a @testitem sandbox, `using
    # SymbolicUncertainties` only binds the module in the testitem's own
    # namespace. We must therefore explicitly inject SymbolicUncertainties
    # and Symbolics into Main so that `CurrentModule = SymbolicUncertainties`
    # and signature references like `::Symbolics.Num` in the
    # getting-started page resolve correctly.
    @eval Main using SymbolicUncertainties
    @eval Main using Symbolics

    Documenter.doctest(SymbolicUncertainties; fix = false)
end
