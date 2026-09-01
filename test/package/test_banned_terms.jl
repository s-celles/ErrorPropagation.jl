@testitem "REQ-171: banned terms absent from source tree" begin
    # M10 smoke test: the library MUST NOT claim GUM-compliance,
    # GUM-certification, or accreditation. Scan the released
    # source tree (README, CHANGELOG, docs/src/, src/, ext/) for
    # case-insensitive matches of three exact phrases. See
    # `specs/012-stable-release/contracts/banned_terms_audit.md`
    # for scope rules.

    using SymbolicUncertainties
    repo = pkgdir(SymbolicUncertainties)
    banned_patterns =
        [r"GUM[-\s]?compliant"i, r"GUM[-\s]?certified"i, r"\baccredited\b"i]

    # README is the user-facing marketing copy; CHANGELOG
    # enumerates the banned phrases as a feature description
    # of this very audit and is excluded for the same self-
    # referential reason as the test/ tree.
    roots = [("README.md", joinpath(repo, "README.md")),]
    # Walk docs/src, src, ext directories
    function _scan_dir(dir, ext_suffix)
        files = String[]
        isdir(dir) || return files
        for (root, _, fnames) in walkdir(dir)
            for fname in fnames
                if endswith(fname, ext_suffix)
                    push!(files, joinpath(root, fname))
                end
            end
        end
        return files
    end
    append!(
        roots,
        [
            ("docs/src/$(relpath(p, joinpath(repo, "docs", "src")))", p) for
            p in _scan_dir(joinpath(repo, "docs", "src"), ".md")
        ],
    )
    append!(
        roots,
        [
            ("src/$(relpath(p, joinpath(repo, "src")))", p) for
            p in _scan_dir(joinpath(repo, "src"), ".jl")
        ],
    )
    append!(
        roots,
        [
            ("ext/$(relpath(p, joinpath(repo, "ext")))", p) for
            p in _scan_dir(joinpath(repo, "ext"), ".jl")
        ],
    )

    for (label, path) in roots
        @test isfile(path)
        content = read(path, String)
        for pat in banned_patterns
            matches = collect(eachmatch(pat, content))
            if !isempty(matches)
                @warn "REQ-171 violation: $(length(matches)) match(es) of $(pat) in $label"
            end
            @test isempty(matches)
        end
    end
end
