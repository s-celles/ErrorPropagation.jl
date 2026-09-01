# A calibration certificate — ISO/IEC 17025:2017 §7.8.
#
# `report` renders a *result*. A certificate is the document that
# result travels in, and the standard is prescriptive about what it
# must carry: sixteen general clauses in §7.8.2.1, six more specific
# to calibration in §7.8.4.1, and a statement of conformity in §7.8.6
# that must name its decision rule.
#
# Two design decisions worth stating.
#
# **Missing clauses are printed on the document, not returned by a
# separate checker.** A certificate lacking its traceability statement
# is defective, and the failure mode of a checker is that nobody calls
# it. Rendering the gaps in place makes the omission impossible to
# miss, and turns the type into a working checklist against the
# standard.
#
# **The watermark cannot be removed.** This package is not an accreditation holder
# and says so in `LICENSE.md`; a document it emits is a draft whatever
# the caller intends. The wording is configurable — a French
# laboratory will want its own — but a blank one falls back to the
# default rather than disappearing.
#
# Traces REQ-241.

const _DEFAULT_WATERMARK = "SPECIMEN — NOT AN OFFICIAL CALIBRATION CERTIFICATE"

"""
    ConformityStatement(applies_to, specification, verdict; decision_rule = nothing)

A statement of conformity, in the shape ISO/IEC 17025:2017 §7.8.6.2
requires: it must identify the results it applies to, the
specification met or not met, and the decision rule applied.

`verdict` is `:pass`, `:fail`, or `:conditional`.

`decision_rule` is optional only because §7.8.6.2 c) excuses it when
the rule is inherent in the requested specification. Leaving it out
otherwise produces a finding on the certificate — the rule is what
makes a pass/fail statement mean anything, since it fixes how the
measurement uncertainty is set against the tolerance (ILAC-G8).

Traces REQ-241.
"""
struct ConformityStatement
    applies_to::String
    specification::String
    verdict::Symbol
    decision_rule::Union{String,Nothing}
end

function ConformityStatement(
    applies_to::AbstractString,
    specification::AbstractString,
    verdict::Symbol;
    decision_rule::Union{AbstractString,Nothing} = nothing,
)
    verdict in (:pass, :fail, :conditional) || throw(
        ArgumentError(
            "ConformityStatement: `verdict` must be :pass, :fail or " *
            ":conditional; got :$(verdict).",
        ),
    )
    return ConformityStatement(
        String(applies_to),
        String(specification),
        verdict,
        decision_rule === nothing ? nothing : String(decision_rule),
    )
end

"""
    CertificateFinding

One clause of ISO/IEC 17025:2017 §7.8 that the certificate does not
satisfy. Carries the clause number and what it asks for.

Traces REQ-241.
"""
struct CertificateFinding
    clause::String
    requirement::String
end

"""
    CalibrationCertificate

A calibration certificate built by [`certificate`](@ref). Show it for
the text rendering; `latex(cert)` produces a compilable document.

`findings` lists the ISO/IEC 17025:2017 §7.8 clauses left unsatisfied.
An empty vector means every clause this package can check is filled;
it is not a claim that the certificate is fit to issue, which depends
on an accreditation this package does not have.

Traces REQ-241.
"""
struct CalibrationCertificate
    result::UncertaintyReport
    identifier::String
    laboratory::Union{String,Nothing}
    location::Union{String,Nothing}
    customer::Union{String,Nothing}
    method::Union{String,Nothing}
    item::Union{String,Nothing}
    date_received::Union{String,Nothing}
    date_performed::Union{String,Nothing}
    date_issued::Union{String,Nothing}
    authorised_by::Union{String,Nothing}
    conditions::Union{String,Nothing}
    traceability::Union{String,Nothing}
    adjustment::Union{String,Nothing}
    conformity::Union{ConformityStatement,Nothing}
    calibration_interval::Union{String,Nothing}
    interval_agreed::Bool
    model::Union{String,Nothing}
    notes::Vector{String}
    watermark::String
    findings::Vector{CertificateFinding}
end

_s(x) = x === nothing ? nothing : String(x)

# Which clauses are unmet. Only the ones a program can actually see:
# nothing here checks that the traceability statement is *true*, only
# that it was made.
function _iso_findings(c)
    f = CertificateFinding[]
    add(cl, r) = push!(f, CertificateFinding(cl, r))

    c.laboratory === nothing &&
        add("7.8.2.1 b)", "the name and address of the laboratory")
    c.location === nothing &&
        add("7.8.2.1 c)", "the location where the calibration was performed")
    c.customer === nothing && add("7.8.2.1 e)", "the name of the customer")
    c.method === nothing &&
        add("7.8.2.1 f)", "identification of the method used")
    c.item === nothing && add(
        "7.8.2.1 g)",
        "an unambiguous description and identification of the item",
    )
    c.date_received === nothing &&
        add("7.8.2.1 h)", "the date the item was received")
    c.date_performed === nothing &&
        add("7.8.2.1 i)", "the date the calibration was performed")
    c.date_issued === nothing &&
        add("7.8.2.1 j)", "the date the certificate was issued")
    c.authorised_by === nothing && add(
        "7.8.2.1 o)",
        "identification of the person authorising the certificate",
    )
    c.conditions === nothing && add(
        "7.8.4.1 b)",
        "the environmental conditions that influence the measurement result",
    )
    c.traceability === nothing && add(
        "7.8.4.1 c)",
        "a statement identifying how the measurements are metrologically traceable",
    )

    if c.conformity !== nothing && c.conformity.decision_rule === nothing
        add(
            "7.8.6.2 c)",
            "the decision rule applied, unless it is inherent in the requested " *
            "specification (see ILAC-G8)",
        )
    end
    if c.calibration_interval !== nothing && !c.interval_agreed
        add(
            "7.8.4.3",
            "a calibration certificate shall not recommend a calibration interval " *
            "unless agreed with the customer or required by law — pass " *
            "`interval_agreed = true` to record that agreement",
        )
    end
    return f
end

"""
    certificate(result::UncertaintyReport; identifier, kwargs...)
    certificate(m::SymbolicMeasurement, values::AbstractDict; identifier, kwargs...)

Build a [`CalibrationCertificate`](@ref) in the shape
ISO/IEC 17025:2017 §7.8 prescribes.

The second form needs `DynamicQuantities` loaded and takes the
measurement with unit-carrying values, deriving the result — and its
unit — from the model. Keywords not listed here are passed to
[`report`](@ref), so `k`, `coverage_probability`, `digits` and `unit`
work as they do there.

# Arguments

- `result` — the reported result, from [`report`](@ref).
- `identifier` (keyword, **required**) — the unique identification of
  the certificate, §7.8.2.1 d).
- `laboratory`, `location`, `customer`, `method`, `item`,
  `date_received`, `date_performed`, `date_issued`, `authorised_by`
  (keywords) — the general clauses of §7.8.2.1. Dates are strings, so
  a laboratory writes them in whatever form its accreditation expects.
- `conditions`, `traceability`, `adjustment` (keywords) — §7.8.4.1
  b), c) and d): the environmental conditions, the metrological
  traceability statement, and the results before and after any
  adjustment or repair.
- `conformity` (keyword) — a [`ConformityStatement`](@ref), §7.8.6.
- `calibration_interval`, `interval_agreed` (keywords) — §7.8.4.3
  forbids recommending an interval unless it was agreed with the
  customer; stating one without `interval_agreed = true` is recorded
  as a finding.
- `model`, `notes` (keywords) — the measurement model and any
  additional remarks.
- `watermark` (keyword) — the wording of the specimen watermark. It
  cannot be removed; an empty string restores the default.

# The findings

Unmet clauses are collected in `cert.findings` **and printed on the
document**. A certificate missing its traceability statement is
defective, and a checker nobody calls does not help.

An empty `findings` is not a claim that the certificate may be issued.
This package is not an accreditation holder — see `LICENSE.md` and
[Limitations](limitations.md) — which is why every rendering carries a specimen
watermark.

Traces REQ-241. Implements ISO/IEC 17025:2017 §7.8.
"""
function certificate(
    result::UncertaintyReport;
    identifier::AbstractString,
    laboratory = nothing,
    location = nothing,
    customer = nothing,
    method = nothing,
    item = nothing,
    date_received = nothing,
    date_performed = nothing,
    date_issued = nothing,
    authorised_by = nothing,
    conditions = nothing,
    traceability = nothing,
    adjustment = nothing,
    conformity::Union{ConformityStatement,Nothing} = nothing,
    calibration_interval = nothing,
    interval_agreed::Bool = false,
    model = nothing,
    notes::AbstractVector{<:AbstractString} = String[],
    watermark::AbstractString = _DEFAULT_WATERMARK,
)
    isempty(strip(identifier)) && throw(
        ArgumentError(
            "certificate: `identifier` is required — ISO/IEC 17025 §7.8.2.1 d) " *
            "asks for a unique identification of the certificate.",
        ),
    )

    mark = isempty(strip(watermark)) ? _DEFAULT_WATERMARK : String(watermark)

    c = CalibrationCertificate(
        result,
        String(identifier),
        _s(laboratory),
        _s(location),
        _s(customer),
        _s(method),
        _s(item),
        _s(date_received),
        _s(date_performed),
        _s(date_issued),
        _s(authorised_by),
        _s(conditions),
        _s(traceability),
        _s(adjustment),
        conformity,
        _s(calibration_interval),
        interval_agreed,
        _s(model),
        String[String(n) for n in notes],
        mark,
        CertificateFinding[],
    )
    append!(c.findings, _iso_findings(c))
    return c
end

# `certificate(m, values)` without DynamicQuantities. Typed on `::Any`
# so the extension adds a method rather than overwriting this one —
# method overwriting during precompilation is a hard error on
# Julia >= 1.12.
function certificate(::SymbolicMeasurement, ::Any; kwargs...)
    throw(
        ArgumentError(
            "certificate(m, values) requires `DynamicQuantities.jl`, which is " *
            "what carries the units. Add `using DynamicQuantities`, or build " *
            "the result with `report` first and pass that.",
        ),
    )
end

const _VERDICT_TEXT = Dict(
    :pass => "CONFORMS to the specification",
    :fail => "DOES NOT CONFORM to the specification",
    :conditional => "CONDITIONAL — see the decision rule",
)

_rule(io, label, value) =
    value === nothing ? nothing : println(io, rpad(label, 22), value)

function Base.show(io::IO, ::MIME"text/plain", c::CalibrationCertificate)
    bar = "═"^72
    println(io, bar)
    println(io, "  ", c.watermark)
    println(io, bar)
    println(io)
    println(io, "CALIBRATION CERTIFICATE")
    println(
        io,
        "Certificate No. ",
        c.identifier,
        "   (ISO/IEC 17025:2017 §7.8)",
    )
    println(io)

    _rule(io, "Laboratory", c.laboratory)
    _rule(io, "Location", c.location)
    _rule(io, "Customer", c.customer)
    _rule(io, "Item", c.item)
    _rule(io, "Method", c.method)
    _rule(io, "Received", c.date_received)
    _rule(io, "Calibrated", c.date_performed)
    _rule(io, "Issued", c.date_issued)
    _rule(io, "Conditions", c.conditions)
    println(io)

    if c.model !== nothing
        println(io, "Measurement model")
        println(io, "  ", c.model)
        println(io)
    end

    println(io, "Result (§7.8.4.1 a)")
    for f in c.result.forms
        println(io, "  ", f)
    end
    if c.result.expanded !== nothing
        println(io)
        println(io, "  ", c.result.expanded)
    end
    println(io)

    if c.traceability !== nothing
        println(io, "Metrological traceability (§7.8.4.1 c)")
        println(io, "  ", c.traceability)
        println(io)
    end
    if c.adjustment !== nothing
        println(io, "Before and after adjustment (§7.8.4.1 d)")
        println(io, "  ", c.adjustment)
        println(io)
    end
    if c.conformity !== nothing
        s = c.conformity
        println(io, "Statement of conformity (§7.8.6)")
        println(io, "  Applies to:    ", s.applies_to)
        println(io, "  Specification: ", s.specification)
        println(io, "  Result:        ", _VERDICT_TEXT[s.verdict])
        println(
            io,
            "  Decision rule: ",
            s.decision_rule === nothing ?
            "NOT STATED — required by §7.8.6.2 c)" : s.decision_rule,
        )
        println(io)
    end
    if c.calibration_interval !== nothing
        println(io, "Calibration interval")
        println(
            io,
            "  ",
            c.calibration_interval,
            c.interval_agreed ? " (agreed with the customer, §7.8.4.3)" :
            " — NOT recorded as agreed; §7.8.4.3 forbids this",
        )
        println(io)
    end
    if !isempty(c.notes)
        println(io, "Notes")
        for n in c.notes
            println(io, "  • ", n)
        end
        println(io)
    end

    println(io, "The results relate only to the item calibrated (§7.8.2.1 l).")
    println(io)

    # §7.8.2.1 o) — the person authorising the certificate. The LaTeX
    # rendering carried this from the start and the text one did not,
    # which is the sort of gap that only shows up when both are
    # checked against the same clause list.
    if c.authorised_by !== nothing
        println(io, "Authorised by (§7.8.2.1 o)")
        println(io, "  ", c.authorised_by)
        println(io)
    end

    println(io, "— End of certificate —")
    println(io)

    if !isempty(c.findings)
        println(io, "─"^72)
        println(
            io,
            "This certificate is incomplete. Clauses of ISO/IEC 17025:2017",
        )
        println(io, "§7.8 that are not satisfied:")
        for f in c.findings
            println(io, "  §", f.clause, "  ", f.requirement)
        end
        println(io, "─"^72)
        println(io)
    end

    println(io, bar)
    println(io, "  ", c.watermark)
    println(
        io,
        "  Produced by SymbolicUncertainties.jl, which holds no accreditation as a",
    )
    println(
        io,
        "  calibration laboratory and carries no warranty. See LICENSE.md.",
    )
    println(io, bar)
    return nothing
end

Base.show(io::IO, c::CalibrationCertificate) = print(
    io,
    "CalibrationCertificate(",
    c.identifier,
    ", ",
    length(c.findings),
    " findings)",
)

# LaTeX rendering.
#
# A whole document rather than a fragment: the point of the certificate
# is that it can be compiled and handed over. It needs no packages
# beyond `eso-pic`, `geometry` and `inputenc`-era defaults that every
# TeX distribution carries, so it compiles on a laboratory machine
# without a package install.

# Characters that end a LaTeX build. A laboratory name with an
# ampersand in it is not unusual, and an unescaped one is a document
# that does not compile — worse than a document that does not exist,
# because the failure surfaces at the worst moment.
#
# The second group is the reason this is longer than the usual five
# entries: metrology writes `Ω`, `µ`, `°C` and unit exponents like
# `A⁻¹` or `m²`, and `pdflatex` refuses every one of them even with
# `utf8` input encoding. Mapping them to commands keeps the document
# compiling on the engine a laboratory already has, rather than
# requiring `xelatex`. Accented Latin characters are left alone —
# `inputenc` handles those.
const _TEX_ESCAPES = Dict(
    '\\' => "\\textbackslash{}",
    '&' => "\\&",
    '%' => "\\%",
    '\$' => "\\\$",
    '#' => "\\#",
    '_' => "\\_",
    '{' => "\\{",
    '}' => "\\}",
    '~' => "\\textasciitilde{}",
    '^' => "\\textasciicircum{}",
    # Greek, as used for units and uncertainty symbols.
    'Ω' => "\\ensuremath{\\Omega}",
    'Δ' => "\\ensuremath{\\Delta}",
    'Σ' => "\\ensuremath{\\Sigma}",
    'α' => "\\ensuremath{\\alpha}",
    'β' => "\\ensuremath{\\beta}",
    'γ' => "\\ensuremath{\\gamma}",
    'δ' => "\\ensuremath{\\delta}",
    'ε' => "\\ensuremath{\\varepsilon}",
    'θ' => "\\ensuremath{\\theta}",
    'λ' => "\\ensuremath{\\lambda}",
    'μ' => "\\ensuremath{\\mu}",
    'µ' => "\\ensuremath{\\mu}",   # U+00B5, the micro sign
    'ν' => "\\ensuremath{\\nu}",
    'π' => "\\ensuremath{\\pi}",
    'ρ' => "\\ensuremath{\\rho}",
    'σ' => "\\ensuremath{\\sigma}",
    'τ' => "\\ensuremath{\\tau}",
    'φ' => "\\ensuremath{\\varphi}",
    'ω' => "\\ensuremath{\\omega}",
    # Unit exponents, which `DynamicQuantities` writes as superscripts.
    '⁰' => "\\ensuremath{^{0}}",
    '¹' => "\\ensuremath{^{1}}",
    '²' => "\\ensuremath{^{2}}",
    '³' => "\\ensuremath{^{3}}",
    '⁴' => "\\ensuremath{^{4}}",
    '⁵' => "\\ensuremath{^{5}}",
    '⁶' => "\\ensuremath{^{6}}",
    '⁷' => "\\ensuremath{^{7}}",
    '⁸' => "\\ensuremath{^{8}}",
    '⁹' => "\\ensuremath{^{9}}",
    '⁻' => "\\ensuremath{^{-}}",
    '⁺' => "\\ensuremath{^{+}}",
    # The rest of the metrological punctuation.
    '±' => "\\ensuremath{\\pm}",
    '°' => "\\ensuremath{^{\\circ}}",
    '·' => "\\ensuremath{\\cdot}",
    '×' => "\\ensuremath{\\times}",
    '≈' => "\\ensuremath{\\approx}",
    '≤' => "\\ensuremath{\\leq}",
    '≥' => "\\ensuremath{\\geq}",
    '≠' => "\\ensuremath{\\neq}",
    '√' => "\\ensuremath{\\surd}",
    '∞' => "\\ensuremath{\\infty}",
    '‰' => "\\textperthousand{}",
    '—' => "---",
    '–' => "--",
    '\u2019' => "'",
)

# `u_c` is the GUM's symbol for the combined standard uncertainty, and
# it runs through every reported result — the §7.2.2 forms and the
# §7.2.4 expanded statement both carry it. Escaping the underscore
# would print `u_c` literally, where the standard sets the `c` as a
# subscript. The plain-text rendering keeps `u_c`, which is the
# conventional ASCII spelling and the best text can do.
const _UC_SENTINEL = '\x01'

function _tex(s::AbstractString)
    io = IOBuffer()
    for ch in replace(s, "u_c" => _UC_SENTINEL)
        if ch == _UC_SENTINEL
            print(io, "\\ensuremath{u_{\\mathrm{c}}}")
        else
            print(io, get(_TEX_ESCAPES, ch, ch))
        end
    end
    return String(take!(io))
end

_tex(::Nothing) = nothing

function _tex_row(io, label, value)
    value === nothing && return nothing
    println(io, "\\textbf{", _tex(label), "} & ", _tex(value), " \\\\")
    return nothing
end

"""
    latex(c::CalibrationCertificate) -> String

Render a [`CalibrationCertificate`](@ref) as a complete, compilable
LaTeX document — `\\documentclass` through `\\end{document}`.

The specimen watermark is applied with `eso-pic` to **every** shipped
page, not only the first, and is repeated as text in the header and
the footer. It cannot be switched off.

Special characters in the supplied fields are escaped, so a
laboratory name containing `&` or `%` still compiles.

Traces REQ-241.
"""
function latex(c::CalibrationCertificate)
    io = IOBuffer()
    mark = _tex(c.watermark)
    # The running head has room for a label, not a sentence: the full
    # wording is already in the boxes and across the diagonal. Cut at
    # the dash a default watermark carries, and truncate otherwise, so
    # a custom wording cannot collide with the certificate number on
    # the other side of the header.
    _s0 = strip(first(split(c.watermark, '\u2014')))
    short = _tex(length(_s0) > 26 ? first(_s0, 26) : _s0)

    println(io, "\\documentclass[11pt,a4paper]{article}")
    println(io, "\\usepackage[T1]{fontenc}")
    println(io, "\\usepackage[utf8]{inputenc}")
    println(io, "\\usepackage[margin=25mm]{geometry}")
    println(io, "\\usepackage{eso-pic}")
    println(io, "\\usepackage{graphicx}")
    println(io, "\\usepackage{xcolor}")
    println(io, "\\usepackage{textcomp}")
    println(io, "\\usepackage{longtable}")
    println(io, "\\usepackage{fancyhdr}")
    println(io, "\\usepackage{lastpage}")
    println(io)
    println(io, "% The watermark goes on every shipped page. Sized against the")
    println(io, "% paper rather than by a fixed factor: the wording is")
    println(io, "% configurable, and a longer one would otherwise run off the")
    println(io, "% page — which is how a watermark stops being read.")
    println(io, "\\AddToShipoutPictureFG{%")
    println(io, "  \\AtPageCenter{%")
    println(io, "    \\makebox[0pt]{\\rotatebox[origin=c]{45}{%")
    println(io, "      \\resizebox{1.05\\paperwidth}{!}{%")
    println(io, "        \\color{red!25}\\bfseries ", mark, "}}}}}")
    println(io)
    println(
        io,
        "% ISO/IEC 17025 \\S7.8.2.1 d): every page must be recognisable",
    )
    println(io, "% as part of one complete report, and the end identified.")
    println(io, "\\pagestyle{fancy}")
    println(io, "\\fancyhf{}")
    println(
        io,
        "\\fancyhead[L]{\\footnotesize Certificate No.\\ \\texttt{",
        _tex(c.identifier),
        "}}",
    )
    println(
        io,
        "\\fancyhead[R]{\\footnotesize\\color{red}\\bfseries ",
        short,
        "}",
    )
    println(
        io,
        "\\fancyfoot[C]{\\footnotesize Page \\thepage\\ of \\pageref{LastPage}}",
    )
    println(io, "\\renewcommand{\\headrulewidth}{0.4pt}")
    println(io, "\\renewcommand{\\footrulewidth}{0.4pt}")
    println(io)
    println(io, "\\begin{document}")
    println(io)
    println(io, "\\begin{center}")
    println(
        io,
        "\\fbox{\\parbox{0.9\\textwidth}{\\centering\\bfseries\\color{red}",
    )
    println(io, mark, "\\\\[2pt]")
    println(io, "\\normalfont\\small This document was produced by ")
    println(
        io,
        "SymbolicUncertainties.jl, which holds no accreditation as a calibration ",
    )
    println(
        io,
        "laboratory. It carries no warranty and has no legal standing.}}",
    )
    println(io, "\\end{center}")
    println(io, "\\vspace{4mm}")
    println(io)
    println(io, "{\\centering\\LARGE\\bfseries Calibration Certificate\\par}")
    println(io, "\\vspace{2mm}")
    println(
        io,
        "{\\centering Certificate No.\\ \\texttt{",
        _tex(c.identifier),
        "} \\quad ISO/IEC 17025:2017 \\S7.8\\par}",
    )
    println(io, "\\vspace{4mm}")
    println(io)
    println(
        io,
        "\\begin{longtable}{@{}p{0.26\\textwidth}p{0.68\\textwidth}@{}}",
    )
    _tex_row(io, "Laboratory", c.laboratory)
    _tex_row(io, "Location", c.location)
    _tex_row(io, "Customer", c.customer)
    _tex_row(io, "Item", c.item)
    _tex_row(io, "Method", c.method)
    _tex_row(io, "Date received", c.date_received)
    _tex_row(io, "Date calibrated", c.date_performed)
    _tex_row(io, "Date issued", c.date_issued)
    _tex_row(io, "Conditions", c.conditions)
    _tex_row(io, "Model", c.model)
    println(io, "\\end{longtable}")
    println(io)

    println(io, "\\section*{Result}")
    println(io, "\\begin{itemize}")
    for f in c.result.forms
        println(io, "\\item ", _tex(f))
    end
    println(io, "\\end{itemize}")
    if c.result.expanded !== nothing
        println(io, "\\noindent ", _tex(c.result.expanded))
        println(io)
    end

    if c.traceability !== nothing
        println(io, "\\section*{Metrological traceability}")
        println(io, _tex(c.traceability))
        println(io)
    end
    if c.adjustment !== nothing
        println(io, "\\section*{Before and after adjustment}")
        println(io, _tex(c.adjustment))
        println(io)
    end
    if c.conformity !== nothing
        s = c.conformity
        println(io, "\\section*{Statement of conformity}")
        println(
            io,
            "\\begin{longtable}{@{}p{0.26\\textwidth}p{0.68\\textwidth}@{}}",
        )
        _tex_row(io, "Applies to", s.applies_to)
        _tex_row(io, "Specification", s.specification)
        _tex_row(io, "Result", _VERDICT_TEXT[s.verdict])
        _tex_row(
            io,
            "Decision rule",
            s.decision_rule === nothing ?
            "NOT STATED — required by \\S7.8.6.2 c)" : s.decision_rule,
        )
        println(io, "\\end{longtable}")
        println(io)
    end
    if c.calibration_interval !== nothing
        println(io, "\\section*{Calibration interval}")
        println(
            io,
            _tex(c.calibration_interval),
            c.interval_agreed ? " (agreed with the customer, \\S7.8.4.3)" :
            " --- not recorded as agreed; \\S7.8.4.3 forbids this",
        )
        println(io)
    end
    if !isempty(c.notes)
        println(io, "\\section*{Notes}")
        println(io, "\\begin{itemize}")
        for n in c.notes
            println(io, "\\item ", _tex(n))
        end
        println(io, "\\end{itemize}")
    end

    println(io, "\\vspace{4mm}")
    println(
        io,
        "\\noindent The results relate only to the item calibrated ",
        "(\\S7.8.2.1 l).",
    )
    println(io)

    if !isempty(c.findings)
        println(io, "\\section*{\\color{red}This certificate is incomplete}")
        println(
            io,
            "The following clauses of ISO/IEC 17025:2017 \\S7.8 are not satisfied:",
        )
        println(io, "\\begin{itemize}")
        for f in c.findings
            println(
                io,
                "\\item \\textbf{\\S",
                _tex(f.clause),
                "} ",
                _tex(f.requirement),
            )
        end
        println(io, "\\end{itemize}")
        println(io)
    end

    if c.authorised_by !== nothing
        println(io, "\\vspace{5mm}")
        println(
            io,
            "\\noindent\\textbf{Authorised by:} ",
            _tex(c.authorised_by),
        )
        println(io, "\\vspace{3mm}")
        println(io, "\\noindent\\rule{0.4\\textwidth}{0.4pt}")
        println(io)
    end

    println(io, "\\vspace{3mm}")
    println(io, "{\\centering\\small\\bfseries\\color{red}", mark, "\\par}")
    println(io, "\\vspace{2mm}")
    println(io, "{\\centering\\footnotesize --- End of certificate ---\\par}")
    println(io, "\\end{document}")
    return String(take!(io))
end
