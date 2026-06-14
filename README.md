# LaMEM Claude Code Skills

A small collection of [Claude Code](https://claude.com/claude-code) **skills** for working with
[LaMEM](https://github.com/UniMainzGeo/LaMEM) (Lithosphere and Mantle Evolution Model) — the parallel
3D geodynamics code built on PETSc.

These skills give Claude project-specific knowledge so it can navigate the codebase, add and run tests,
and handle the git/PR workflow without re-deriving conventions each session. They target **LaMEM v3.0.0**.

## Skills

| Skill | Purpose |
|-------|---------|
| [`lamem-codebase`](lamem-codebase/SKILL.md) | Architecture, build system, source map, conventions, and common workflows for the LaMEM C++/PETSc codebase. |
| [`lamem-test-creator`](lamem-test-creator/SKILL.md) | Create, register, and run LaMEM Julia tests; expected-file generation; common `.dat` pitfalls. |
| [`lamem-github-workflow`](lamem-github-workflow/SKILL.md) | Commit / branch / push / pull-request workflow for LaMEM, keeping commits clean and PR descriptions structured. |

## Usage

Each skill lives in its own folder containing a `SKILL.md` with YAML frontmatter (`name`, `description`).
To use them with Claude Code, place the skill folders where Claude Code discovers skills, e.g. a
project's `.claude/` directory or your user-level skills directory:

```bash
# project-local (per LaMEM checkout)
cp -r lamem-codebase lamem-test-creator lamem-github-workflow /path/to/LaMEM/.claude/
```

Claude loads a skill when a request matches its `description` triggers (e.g. mentioning LaMEM, PETSc
solvers, FDSTAG, adding a test, or preparing a PR).

## Notes

- Written against **LaMEM v3.0.0**. Because upstream keeps committing to `master` under the same
  `Version : 3.0.0` string, treat the upstream commit SHA — not the version — as the real reference
  point when these skills get out of date.
- Contributions / corrections welcome.
