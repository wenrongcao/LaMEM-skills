# LaMEM Claude Code Skills

A small collection of [Claude Code](https://claude.com/claude-code) **skills** for working with
[LaMEM](https://github.com/UniMainzGeo/LaMEM) (Lithosphere and Mantle Evolution Model) — the parallel
3D geodynamics code built on PETSc.

These skills give Claude project-specific knowledge so it can navigate the codebase, add and run tests,
and handle the git/PR workflow without re-deriving conventions each session.

> **Target version:** LaMEM **v3.1.0**, tracked at upstream commit **`7e7a012e`** (2026‑08‑12) —
> the 3.1.0 release (`d1a5715e`, "Version update 3.0.2 -> 3.1.0") plus the `buffers` merge (#79).
> Previously pinned to v3.0.0 at `eaf75d4b` (2026‑06‑15), 54 commits earlier.
>
> Upstream did bump the version string this time (3.0.0 → 3.0.1 → 3.0.2 → 3.1.0), but it still
> lags `master`: many commits land under an unchanged string. The commit SHA above — not the
> version number — remains the real reference point for how current these skills are.

## Skills

| Skill | Purpose |
|-------|---------|
| [`lamem-codebase`](lamem-codebase/SKILL.md) | Architecture, build system, source map, conventions, and common workflows for the LaMEM C++/PETSc codebase. |
| [`lamem-test-creator`](lamem-test-creator/SKILL.md) | Create, register, and run LaMEM Julia tests; expected-file generation; common `.dat` pitfalls. |
| [`lamem-github-workflow`](lamem-github-workflow/SKILL.md) | Commit / branch / push / pull-request workflow for LaMEM, keeping commits clean and PR descriptions structured. |
| [`lamem-migration-notes`](lamem-migration-notes/SKILL.md) | Produce a migration guide / release notes between two LaMEM versions — validated against both source trees, delivered as Markdown with an optional standalone HTML page. Ships bundled example templates. |
| [`lamem-skill-maintenance`](lamem-skill-maintenance/SKILL.md) | Meta-skill: audit and refresh these skills against the current upstream HEAD (freshness judged by commit SHA, not the version string, which lags `master`), then propagate fixes back to this repo. |

## Usage

Each skill lives in its own folder containing a `SKILL.md` with YAML frontmatter (`name`, `description`).
To use them with Claude Code, place the skill folders where Claude Code discovers skills, e.g. a
project's `.claude/` directory or your user-level skills directory:

```bash
# project-local (per LaMEM checkout)
cp -r lamem-codebase lamem-test-creator lamem-github-workflow lamem-migration-notes lamem-skill-maintenance /path/to/LaMEM/.claude/
```

Claude loads a skill when a request matches its `description` triggers (e.g. mentioning LaMEM, PETSc
solvers, FDSTAG, adding a test, or preparing a PR).

## Notes

- Written against **LaMEM v3.1.0** at upstream commit **`7e7a012e`** (2026‑08‑12). Because upstream
  keeps committing to `master` between version bumps, treat the upstream commit SHA — not the
  version — as the real reference point when these skills get out of date.
- Contributions / corrections welcome.

## Contributors

- **Wenrong Cao** ([@wenrongcao](https://github.com/wenrongcao)) — author & maintainer
- **Claude** (Anthropic, via [Claude Code](https://claude.com/claude-code)) — co-authored the skills
