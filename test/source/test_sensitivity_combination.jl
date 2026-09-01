@testitem "REQ-201: repeated source contributions combine before variance" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using SymbolicUncertainties:
        SourceId, Source, _add_term!, _combined_uncertainty
    using Symbolics
    using Test

    @variables u

    sid = SourceId(1)
    srcs = Dict(sid => Source(u, nothing, :s))

    # Two contributions of the SAME source must add as sensitivities
    # (2 + 3 = 5) before being squared — not be squared separately
    # and summed (2² + 3² = 13). This is the difference between
    # 5u and sqrt(13)u, and it is exactly why x - x currently fails.
    terms = Dict{SourceId,Symbolics.Num}()
    _add_term!(terms, sid, Symbolics.Num(2))
    _add_term!(terms, sid, Symbolics.Num(3))

    @test length(terms) == 1
    @test isequal(Symbolics.simplify(terms[sid] - 5), 0)

    uc = _combined_uncertainty(
        terms,
        srcs,
        Dict{Tuple{SourceId,SourceId},Symbolics.Num}(),
    )
    dict = Dict(u => 0.4)
    @test isapprox(_as_float(uc, dict), 5 * 0.4; atol = 1e-12)

    # Opposite sensitivities must cancel, not accumulate.
    cancel = Dict{SourceId,Symbolics.Num}()
    _add_term!(cancel, sid, Symbolics.Num(1))
    _add_term!(cancel, sid, Symbolics.Num(-1))
    uc0 = _combined_uncertainty(
        cancel,
        srcs,
        Dict{Tuple{SourceId,SourceId},Symbolics.Num}(),
    )
    @test isapprox(_as_float(uc0, dict), 0.0; atol = 1e-12)
end
