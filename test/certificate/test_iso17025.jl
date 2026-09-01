@testitem "REQ-241: a calibration certificate carries the ISO/IEC 17025 §7.8 clauses" begin
    using SymbolicUncertainties
    using Test

    result = report(
        99.98,
        0.014;
        symbol = "R",
        unit = "Ω",
        k = 2,
        coverage_probability = 0.95,
    )

    full = certificate(
        result;
        identifier = "CAL-2026-0417",
        laboratory = "Laboratoire d'essais — 12 rue de la Mesure, Poitiers",
        location = "Permanent facility, Poitiers",
        customer = "Atelier Dupont & Fils",
        method = "Comparison against a calibrated reference (internal method MP-04)",
        item = "Standard resistor, 100 Ω, s/n 4471-C",
        date_received = "2026-09-01",
        date_performed = "2026-09-03",
        date_issued = "2026-09-05",
        authorised_by = "S. Celles, technical manager",
        conditions = "(23.0 ± 0.5) °C, (45 ± 10) % RH",
        traceability = "Traceable to the SI through reference standard R-118, " *
                       "calibrated by LNE, certificate 2026-3391",
        model = "R = V / I",
    )

    txt = sprint(show, MIME"text/plain"(), full)

    # §7.8.2.1 — the general clauses must appear on the document.
    for required in (
        "CAL-2026-0417",
        "Poitiers",
        "Atelier Dupont & Fils",
        "MP-04",
        "4471-C",
        "2026-09-01",
        "2026-09-03",
        "2026-09-05",
        "S. Celles",
    )
        @test occursin(required, txt)
    end

    # §7.8.2.1 l) — results relate only to the item calibrated.
    @test occursin("relate only to the item", txt)

    # §7.8.4.1 a) — the uncertainty, in the unit of the measurand.
    @test occursin("99.980(14) Ω", txt)
    # §7.8.4.1 c) — the traceability statement is not optional.
    @test occursin("LNE", txt)

    # The watermark is structural, appears more than once, and says
    # what it means.
    @test count(_ -> true, eachmatch(r"SPECIMEN", txt)) >= 2
    @test occursin("NOT AN OFFICIAL", uppercase(txt))

    # A complete certificate has nothing outstanding.
    @test isempty(full.findings)

    # A certificate missing mandatory clauses says so ON THE DOCUMENT,
    # rather than leaving the omission to be noticed later.
    bare = certificate(result; identifier = "X-1")
    @test !isempty(bare.findings)
    bare_txt = sprint(show, MIME"text/plain"(), bare)
    @test occursin("7.8.4.1", bare_txt)          # traceability is missing
    @test occursin("incomplete", lowercase(bare_txt))

    # §7.8.6.2 — a conformity statement must name its decision rule.
    no_rule = certificate(
        result;
        identifier = "X-2",
        conformity = ConformityStatement(
            "R at 23 °C",
            "Nominal 100 Ω ± 0.1 %",
            :pass;
            decision_rule = nothing,
        ),
    )
    @test any(f -> occursin("7.8.6", f.clause), no_rule.findings)

    with_rule = ConformityStatement(
        "R at 23 °C",
        "Nominal 100 Ω ± 0.1 %",
        :pass;
        decision_rule = "Simple acceptance, guard band w = 0 (ILAC-G8:2019 §4.2.1)",
    )
    ok = certificate(result; identifier = "X-3", conformity = with_rule)
    @test !any(f -> occursin("7.8.6", f.clause), ok.findings)
    @test occursin("ILAC-G8", sprint(show, MIME"text/plain"(), ok))

    # §7.8.4.3 — no calibration interval unless it was agreed.
    unagreed = certificate(
        result;
        identifier = "X-4",
        calibration_interval = "12 months",
    )
    @test any(f -> occursin("7.8.4.3", f.clause), unagreed.findings)
    agreed = certificate(
        result;
        identifier = "X-5",
        calibration_interval = "12 months",
        interval_agreed = true,
    )
    @test !any(f -> occursin("7.8.4.3", f.clause), agreed.findings)
end

@testitem "REQ-241: the LaTeX rendering is a whole document and keeps the watermark" begin
    using SymbolicUncertainties
    using Test

    result = report(99.98, 0.014; symbol = "R", unit = "Ω")
    cert = certificate(
        result;
        identifier = "CAL-2026-0417",
        laboratory = "Lab & Co — 50 % owned",   # LaTeX-hostile characters
        item = "Resistor_A",
        traceability = "SI via LNE",
    )

    tex = latex(cert)

    @test occursin("\\documentclass", tex)
    @test occursin("\\begin{document}", tex)
    @test occursin("\\end{document}", tex)

    # The watermark is on every shipped page, not just the first.
    @test occursin("eso-pic", tex)
    @test occursin("SPECIMEN", tex)

    # LaTeX-special characters are escaped, or the document will not
    # compile — and a certificate that does not compile is worse than
    # no certificate.
    @test occursin("Lab \\& Co", tex)
    @test occursin("50 \\% owned", tex)
    @test occursin("Resistor\\_A", tex)

    # `u_c` is the GUM's symbol for the combined standard uncertainty and
    # belongs in math with a roman subscript, not as a literal
    # underscore — it appears in the §7.2.2 forms and again in the
    # §7.2.4 statement, so getting it wrong is visible throughout.
    @test occursin("\\ensuremath{u_{\\mathrm{c}}}", tex)
    @test !occursin("u\\_c", tex)

    # The watermark cannot be turned off, only worded differently.
    custom = certificate(
        result;
        identifier = "X-6",
        watermark = "SPÉCIMEN — DOCUMENT NON OFFICIEL",
    )
    @test occursin("SPÉCIMEN", latex(custom))
    blanked = certificate(result; identifier = "X-7", watermark = "")
    @test occursin("SPECIMEN", latex(blanked))
end

@testitem "REQ-241: the LaTeX certificate actually compiles" begin
    using SymbolicUncertainties
    using Test

    # String assertions cannot tell whether a document builds. The
    # first version of this renderer passed every one of them and
    # failed on `Ω`, which `pdflatex` rejects even under `utf8` input
    # encoding — and metrology writes `Ω`, `µ`, `°C` and unit
    # exponents constantly. This runs the engine when the machine has
    # one, and is skipped when it does not.
    # A `@testitem` body runs at module top level, where `return` does
    # not interrupt anything — an early return here fell through to
    # building the command with `nothing`, which passed locally because
    # this machine has a TeX engine and failed on CI, which does not.
    engine = Sys.which("pdflatex")
    if engine === nothing
        @info "no pdflatex on this machine; skipping the compile check"
        @test true
    else
        result = report(
            99.98,
            0.014;
            symbol = "R",
            unit = "Ω",
            k = 2,
            coverage_probability = 0.95,
        )
        cert = certificate(
            result;
            identifier = "CAL-2026-0417",
            # Every hostile character at once: LaTeX specials, Greek,
            # superscripts, degree and micro signs, an em dash.
            laboratory = "Lab & Co — 50 % owned, 100_000 m²",
            location = "Poitiers",
            customer = "Atelier Dupont & Fils",
            method = "Method MP-04 #3",
            item = "Resistor_A ~ 100 Ω",
            date_received = "2026-09-01",
            date_performed = "2026-09-03",
            date_issued = "2026-09-05",
            authorised_by = "S. Celles",
            conditions = "(23.0 ± 0.5) °C, µ-strain < 1×10⁻⁶",
            traceability = "SI via LNE, σ ≈ 2 mΩ",
            model = "R = V / I",
            conformity = ConformityStatement(
                "R at 23 °C",
                "100 Ω ± 0.1 %",
                :pass;
                decision_rule = "Simple acceptance (ILAC-G8:2019 §4.2.1)",
            ),
        )

        mktempdir() do dir
            tex = joinpath(dir, "cert.tex")
            write(tex, latex(cert))
            ok = success(
                pipeline(
                    Cmd(
                        `$engine -interaction=nonstopmode -halt-on-error cert.tex`;
                        dir = dir,
                    );
                    stdout = devnull,
                    stderr = devnull,
                ),
            )
            @test ok
            @test isfile(joinpath(dir, "cert.pdf"))
        end
    end
end
