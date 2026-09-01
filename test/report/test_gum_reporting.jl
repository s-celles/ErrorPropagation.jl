@testitem "REQ-239: the four §7.2.2 forms, on the GUM's own worked example" begin
    using SymbolicUncertainties
    using Test

    # JCGM 100:2008 §7.2.2 reports a 100 g mass standard as
    #   m_S = 100.02147 g,  u_c = 0.35 mg
    # and gives four acceptable textual forms for it. Using the
    # standard's own numbers means the test fails if the formatting
    # drifts from what a calibration certificate may say.
    r = report(100.02147, 0.00035; symbol = "m_S", unit = "g")

    @test r.forms[1] == "m_S = 100.02147 g with u_c = 0.00035 g"
    @test r.forms[2] == "m_S = 100.02147(35) g"
    @test r.forms[3] == "m_S = 100.02147(0.00035) g"
    @test r.forms[4] == "m_S = (100.02147 ± 0.00035) g"

    # §7.2.6: u_c is quoted to two significant digits by default, and
    # the estimate is rounded to that same last significant place.
    # Feeding more digits than the uncertainty can support must not
    # change what is reported.
    r2 = report(100.021473829, 0.000351119; symbol = "m_S", unit = "g")
    @test r2.forms[2] == "m_S = 100.02147(35) g"

    # The rounding is on significant digits of u_c, not decimals: a
    # coarse uncertainty must coarsen the estimate with it.
    r3 = report(1234.5678, 12.0; symbol = "y", unit = "m")
    @test r3.forms[4] == "y = (1235 ± 12) m"

    # §7.2.4 — expanded uncertainty is a different statement, and it
    # must name k and the coverage probability, since `± U` without
    # them is exactly the ambiguity §7.2.2 warns about.
    e = report(
        100.02147,
        0.00035;
        symbol = "m_S",
        unit = "g",
        k = 2.26,
        coverage_probability = 0.95,
        dof = 9,
    )
    @test occursin("m_S = (100.02147 ± 0.00079) g", e.expanded)
    @test occursin("k = 2.26", e.expanded)
    @test occursin("95", e.expanded)
    @test occursin("9 degrees of freedom", e.expanded)

    # Without a coverage factor there is no expanded statement to make.
    @test r.expanded === nothing
end
