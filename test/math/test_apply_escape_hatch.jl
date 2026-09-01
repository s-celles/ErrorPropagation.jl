@testitem "apply with no derivative kwarg matches direct call" setup = [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @variables x σx
    m = x ± σx

    direct = sin(m)
    via_apply = apply(sin, m)

    @test via_apply isa SymbolicMeasurement

    dict = Dict(x => 0.5, σx => 0.01)
    @test isapprox(
        _as_float(direct.err, dict),
        _as_float(via_apply.err, dict);
        atol = 1e-12,
    )
end

@testitem "apply with explicit derivative uses caller-supplied expression" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    # Declare a function whose derivative Symbolics cannot find.
    @register_symbolic _undifferentiable_test_fn(x)

    @variables x σx
    m = x ± σx

    # Supply an explicit derivative expression.
    my_df = 2 * x
    result = apply(_undifferentiable_test_fn, m; derivative = my_df)

    @test result isa SymbolicMeasurement

    # u(f) = |df| · σx; at x = 1.0, σx = 0.01 → 2.0 · 0.01 = 0.02
    dict = Dict(x => 1.0, σx => 0.01)
    @test isapprox(_as_float(result.err, dict), 0.02; atol = 1e-12)
end

@testitem "propagate raises ArgumentError on un-differentiable function" setup =
    [AsFloat] begin
    using SymbolicUncertainties
    using Symbolics

    @register_symbolic _undifferentiable_test_fn2(x)

    @variables x σx
    m = x ± σx

    let caught = nothing
        try
            propagate(_undifferentiable_test_fn2, [m])
        catch e
            caught = e
        end

        @test caught isa ArgumentError
        msg = sprint(showerror, caught)
        # The message now names the operation that failed to
        # dispatch. "cannot compute closed-form derivative" was a
        # diagnosis the code could not actually make: the only thing
        # it observes is a MethodError, and unary minus raised the
        # same one for years while its derivative was -1 throughout.
        @test occursin("_undifferentiable_test_fn2", msg)
        @test occursin("does not overload", msg)
        @test occursin("apply", msg)
        @test occursin("derivative", msg)
    end
end
