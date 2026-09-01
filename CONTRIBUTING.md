# Contributing to SymbolicUncertainties.jl

Thanks for your interest in contributing. This project follows a
structured specification-driven workflow and a strict set of quality
gates defined in the [project constitution](.specify/memory/constitution.md).
Before you start, please read:

- **[`specification/ears.md`](specification/ears.md)** — the normative
  EARS-style requirements specification (`REQ-*` identifiers).
- **[`ROADMAP.md`](ROADMAP.md)** — milestone plan (M0–M12).
- **[`.specify/memory/constitution.md`](.specify/memory/constitution.md)** —
  the five core principles that govern every merge.
- **[`CHANGELOG.md`](CHANGELOG.md)** — *Keep a Changelog* history.

## Quick prerequisites

- Julia **≥ 1.10 (LTS)** — check with `julia --version`.
- Optional but recommended: [`pre-commit`](https://pre-commit.com/) for
  local formatter / whitespace enforcement.

## Branching

- **`main`** is the single long-lived branch: the default branch, the
  integration target, and the branch `TagBot` tags for releases. It is
  also Documenter's `devbranch` and the `edit_link` target.
- Feature branches are named `NNN-short-kebab-description`
  (produced by the `speckit` workflow under `specs/NNN-.../`) and land
  on `main` via pull request.
- There is no `develop` branch. Earlier documents described a Git-flow
  `develop` integration branch that never existed on the remote; any
  remaining reference to it is a bug.

## Commit message format — Conventional Commits

Every commit message MUST start with a type prefix:

- `feat:` — new user-facing feature
- `fix:` — bug fix
- `refactor:` — non-functional code change
- `docs:` — documentation only
- `test:` — tests only
- `chore:` — tooling / scaffolding
- `build:` — build system / dependencies
- `ci:` — CI configuration

Do **not** include `Co-Authored-By` trailers or "Generated with …"
attributions.

## Quality gates — MUST pass before every commit

1. Tests green:

   ```bash
   julia --project=. -e 'using Pkg; Pkg.test()'
   ```

2. Documentation warning-free:

   ```bash
   julia --project=docs -e 'using Pkg; Pkg.develop(PackageSpec(path = pwd())); Pkg.instantiate(); include("docs/make.jl")'
   ```

3. Formatter clean:

   ```bash
   julia -e 'using JuliaFormatter; format(".")'
   ```

4. Pre-commit hooks installed (recommended):

   ```bash
   pre-commit install
   ```

## Test-Driven Development

The project constitution makes TDD **non-negotiable**. New behaviour
lands as a failing `TestItemRunner.jl` `@testitem` first, then the
implementation turns it green. See [`.specify/memory/constitution.md`
§Principle I](.specify/memory/constitution.md).

## Specification-driven workflow

Feature work flows through the `speckit` slash commands under the
`.claude/skills/speckit-*` skills:

1. `/speckit.specify` — write the feature spec
2. `/speckit.plan` — produce the implementation plan
3. `/speckit.tasks` — decompose into executable tasks
4. `/speckit.implement` — land the code

Intermediate artefacts live under `specs/NNN-feature-name/` and are
**not** part of the released package — do not `git add` the
`specs/`, `.specify/`, or `.claude/` directories manually.

## Reporting upstream bugs

If you encounter a bug in a dependency (e.g. `Symbolics.jl`,
`Documenter.jl`, `JuliaFormatter.jl`), record a reproducer in
[`upstream-bugs.md`](upstream-bugs.md) (create it if missing) with a
link to the upstream issue.
