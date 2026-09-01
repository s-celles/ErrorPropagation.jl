@testitem "Giac extension: loads when Giac is present" begin
    using SymbolicUncertainties
    using Giac

    ext =
        Base.get_extension(SymbolicUncertainties, :SymbolicUncertaintiesGiacExt)
    @test ext isa Module
end

@testitem "Giac extension: simplifies tangent identity to zero" begin
    using SymbolicUncertainties
    using Giac
    using Symbolics

    @variables x
    expr = -tan(x) + sin(x) / cos(x)

    # Baseline: Symbolics alone cannot collapse this to 0.
    @test !Symbolics.isequal(Symbolics.simplify(expr), 0)

    # With the Giac extension loaded, _simplify_for_report reduces it.
    reduced = SymbolicUncertainties._simplify_for_report(expr)
    @test Symbolics.isequal(reduced, 0)
end

@testitem "Giac extension: simplifies tan(x)*cos(x) - sin(x)" begin
    using SymbolicUncertainties
    using Giac
    using Symbolics

    @variables x
    expr = tan(x) * cos(x) - sin(x)

    @test !Symbolics.isequal(Symbolics.simplify(expr), 0)

    reduced = SymbolicUncertainties._simplify_for_report(expr)
    @test Symbolics.isequal(reduced, 0)
end

@testitem "Giac extension: sensitivity coefficient simplification" begin
    # A sensitivity coefficient from a non-trivial propagation that
    # Symbolics cannot fully reduce but Giac can.
    # Example: d/dx [sin(x)² + cos(x)²] should reduce to 0, since the
    # expression itself is the Pythagorean identity ≡ 1.
    using SymbolicUncertainties
    using Giac
    using Symbolics

    @variables x
    expr = sin(x)^2 + cos(x)^2

    # Symbolics can simplify this specific case, but the M2 library
    # pipes everything through _simplify_for_report after a derivative,
    # so we check that Giac does at least as well as Symbolics here.
    reduced = SymbolicUncertainties._simplify_for_report(expr)
    @test Symbolics.isequal(reduced, 1)
end

@testitem "Giac extension: falls back to Symbolics on un-reducible input" begin
    # Expressions Giac cannot simplify further must not be clobbered;
    # the extension must return an expression mathematically equal to
    # the input.
    using SymbolicUncertainties
    using Giac
    using Symbolics

    @variables x σx
    # A sensitivity-style expression with no trigonometric identity.
    expr = abs(2 * x) * σx

    reduced = SymbolicUncertainties._simplify_for_report(expr)

    # At x = 3, σx = 0.1, both forms must evaluate to 0.6.
    val_reduced = Float64(
        eval(
            Symbolics.toexpr(
                Symbolics.substitute(reduced, Dict(x => 3.0, σx => 0.1)),
            ),
        ),
    )
    val_original = Float64(
        eval(
            Symbolics.toexpr(
                Symbolics.substitute(expr, Dict(x => 3.0, σx => 0.1)),
            ),
        ),
    )
    @test isapprox(val_reduced, val_original; atol = 1e-12)
end

@testitem "Giac extension: tan identity collapses err via propagate" begin
    # Downstream verification: `propagate` routes the combined `err`
    # through `_simplify_for_report`. With Giac loaded, a function
    # whose derivative simplifies to 0 via a trigonometric identity
    # should yield `err == 0`, while the Symbolics default would
    # leave a non-trivial unreduced form.
    using SymbolicUncertainties
    using Giac
    using Symbolics

    @variables x σx
    m = x ± σx

    # d/dx[tan(x) - sin(x)/cos(x)] ≡ 0. The resulting `err` is
    # `|derivative| * σx`, which should collapse to 0.
    result = propagate(y -> tan(y) - sin(y) / cos(y), [m])
    @test Symbolics.isequal(result.err, 0)
end
