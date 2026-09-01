@testitem "latex(m): M8 Latexify extension replaces the M7 stub" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify
    using Test

    # With Latexify loaded (test env), the M8
    # SymbolicUncertaintiesLatexifyExt takes over — the M7 stub's
    # ArgumentError no longer fires, and latex(m) returns a
    # String. This test asserts the extension replacement works.
    @variables x σx
    m = x ± σx

    result = latex(m)
    @test result isa AbstractString
    @test occursin("\\pm", result)
end

@testitem "latex(m): works on numeric measurement" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify

    m = 5.0 ± 0.1
    result = latex(m)
    @test result isa AbstractString
    @test occursin("\\pm", result)
end

@testitem "latex(m): the extension adds a method, never overwrites" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify
    using Test

    # Julia >= 1.12 turns method overwriting during module
    # precompilation into an ERROR, so the M7 stub MUST be
    # strictly more general than the M8 extension method: the
    # extension has to *add* a method rather than replace one.
    # This is the pattern `src/mtk_stubs.jl` already uses for
    # `propagate_ode` / `uncertainty_ode`; `latex` regressed
    # from it by declaring the exact `::SymbolicMeasurement`
    # signature in both places.
    ms = methods(SymbolicUncertainties.latex)

    # The invariant is about the `SymbolicMeasurement` path. The
    # package also renders a `CalibrationCertificate`, which is a
    # different type on a different path and needs no extension, so it
    # is excluded rather than allowed to inflate the count.
    cert_sig = Tuple{
        typeof(SymbolicUncertainties.latex),
        SymbolicUncertainties.CalibrationCertificate,
    }
    in_pkg = filter(
        m ->
            parentmodule(m) === SymbolicUncertainties && m.sig !== cert_sig,
        ms,
    )
    in_ext = filter(m -> parentmodule(m) !== SymbolicUncertainties, ms)

    # Both must coexist: a generic fallback in the package and
    # the concrete implementation in the extension.
    @test length(in_pkg) == 1
    @test length(in_ext) == 1

    # The package-level fallback must NOT be the concrete
    # signature the extension defines — that is exactly the
    # overwrite that breaks precompilation.
    concrete = Tuple{
        typeof(SymbolicUncertainties.latex),
        SymbolicUncertainties.SymbolicMeasurement,
    }
    @test only(in_pkg).sig !== concrete

    # Dispatch on a measurement must land in the extension.
    target = which(
        SymbolicUncertainties.latex,
        Tuple{SymbolicUncertainties.SymbolicMeasurement},
    )
    @test parentmodule(target) !== SymbolicUncertainties
end

@testitem "latex: fallback still raises on unsupported input" begin
    using SymbolicUncertainties
    using Symbolics
    using Latexify
    using Test

    # The generic fallback keeps the actionable M7 message for
    # anything the extension does not implement.
    @test_throws ArgumentError SymbolicUncertainties.latex(42)
end
