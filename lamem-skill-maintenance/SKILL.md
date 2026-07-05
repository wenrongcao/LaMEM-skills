---
name: lamem-skill-maintenance
description: Meta-skill for keeping the LaMEM Claude Code skills themselves up to date against the current upstream HEAD. Use this skill whenever the user asks to refresh, audit, or verify the LaMEM skills, check whether the skills are stale, re-validate skill claims against the codebase, or propagate skill fixes to the public LaMEM-skills repo. Trigger on phrases like "update the skills", "are the skills stale", "audit the skills", "freshness check", "verify the skills against HEAD", "sync the skills repo", or any mention of skill drift or the LaMEM-skills GitHub repository.
---

# LaMEM Skill Maintenance (Meta-Skill)

A skill for auditing and refreshing the other LaMEM skills (`lamem-codebase`,
`lamem-test-creator`, `lamem-github-workflow`, `lamem-migration-notes`) so their
factual claims stay true as the LaMEM codebase evolves. The skills live in
`/home/wenrongc/LaMEM_v300/.claude/skills/` and are mirrored to the public repo
`https://github.com/wenrongcao/LaMEM-skills` (default branch `master`).

**The central insight: freshness is judged by the upstream COMMIT SHA, not the
version number.** The skills target LaMEM v3.0.0, but the codebase keeps
receiving commits under the *same* `Version : 3.0.0` string. A skill can be
badly stale while the printed version is unchanged. Always compare against
`git describe --tags` / `git log <tag>..HEAD`, never against `Version : 3.0.0`.

---

## Step 1 — Establish the freshness baseline

Resolve exactly which commit the codebase is at and how far it has moved past
the release tag:

```bash
git -C /home/wenrongc/LaMEM_v300 rev-parse --short HEAD
git -C /home/wenrongc/LaMEM_v300 log -1 --format=%ci HEAD
git -C /home/wenrongc/LaMEM_v300 describe --tags            # e.g. v3.0.0-46-geaf75d4b
git -C /home/wenrongc/LaMEM_v300 rev-parse --short v3.0.0^{commit}
git -C /home/wenrongc/LaMEM_v300 log v3.0.0..HEAD --oneline --merges   # post-tag PRs
```

The merge commits since the tag are exactly the changes most likely to have
outpaced the skills — **review those PRs first**. Each merged PR is a candidate
source of drift (new tests, new files, new options, renamed parameters).

---

## Step 2 — Verify each skill's factual claims against HEAD

For every skill, re-check its concrete assertions. Checklist and command
patterns:

| Claim type | How to verify |
|------------|---------------|
| **Every `file:line` reference** (line numbers drift) | `grep -rnoE '[A-Za-z_]+\.(cpp|h|jl):[0-9]+' .claude/skills/*/SKILL.md` — then open each hit and confirm it still points at the claimed code |
| **Counted / enumerated claims** (the classic staleness source) | e.g. test count and "next new test": `ls -d test/t[0-9]* \| sort -V \| tail` |
| **Source-map file lists** vs actual `src/` | Check each listed file exists; check no new `.cpp`/`.h` in `src/` is uncovered |
| **Version-range / requirement claims** (e.g. PETSc 3.19–3.25) | Verify against code guards: `grep -rn PETSC_VERSION_LT src/` — never trust docs |
| **Solver preset names/defaults** | `src/options.h` (`stokes_solver`, `penalty`, `direct_solver_type`) |
| **Test-harness param tables** | `test/test_utils.jl` (`perform_lamem_test` signature and defaults) |

**Real example from the last audit:** the only stale claim was an enumerated
count — the skills said 35 tests / next = `t36`, but PR #69 had added
`t36_spatially_limited_erosion`, so the truth was 36 tests / next = `t37`.
Grep/`ls` the actual thing; never eyeball.

**migration-notes skill specifics:** additionally confirm its bundled
`examples/*.md` / `*.html` are still byte-identical to the repo-root guide
(`diff -q`), and that HEAD hasn't moved past what that guide documents.

---

## Step 3 — Record findings

Keep a findings table in a scratchpad file as you go:

```
# | skill | claim | verified against | status | fix
```

Status values: ✅ OK · ❌ STALE · ⚠️ verify. Most rows should end ✅ — only the
drifted ones get edited. The table doubles as the audit trail for the PR body
in Step 5.

---

## Step 4 — Apply fixes

Edit the affected `.claude/skills/<skill>/SKILL.md` files for every ❌/⚠️ that
resolves to a real change. Leave verified-current claims untouched — a
freshness pass changes only what drifted, nothing else.

---

## Step 5 — Propagate to the public repo (only with the user's go-ahead)

Mirror the same edits to `https://github.com/wenrongcao/LaMEM-skills`.
Pushing and opening a PR are shared-state actions — **confirm with the user
first** unless they already authorized it.

```bash
git clone https://github.com/wenrongcao/LaMEM-skills   # or cd into an existing clone
git checkout master && git pull
git checkout -b freshness-<short-desc>
# apply the same edits (sed or manual)
git -c user.email="caowenrong@gmail.com" -c user.name="wenrongcao" commit -m "..."
git push -u origin freshness-<short-desc>
gh pr create --base master --title "..." --body "..."
```

Additional rules:

- **Bump the README pin.** When a skill is pinned to a commit, update the repo
  `README.md` "Target version" callout to the new HEAD SHA + date (not just
  the version tag), stating explicitly which version **and** head commit the
  skills reflect. The "as of commit X" line is the whole point of the refresh.
- **Split unrelated concerns.** Unrelated changes (e.g. a brand-new skill) go
  on a **separate branch/PR** from freshness fixes.
- Freshness edits touch files independent of any in-flight PR, so they merge
  cleanly in any order.

---

## Common Pitfalls

### Trusting the `Version : 3.0.0` string

It does not advance as `master` moves; a skill can be weeks stale while the
version string is unchanged. Always diff against the SHA (`git describe`,
`git log <tag>..HEAD`).

### Missing enumerated-count drift

Test counts, "next test number", file lists — the most common *real*
staleness. Grep/`ls` the actual thing, never eyeball. (This was the only stale
claim in the last audit: PR #69 added `t36_spatially_limited_erosion`.)

### `file:line` drift

A reference that was right last month silently points elsewhere after an edit.
Re-grep the *quoted code*, not just the line number.

### Editing local but forgetting to propagate

The local skills and the public `LaMEM-skills` repo must stay in sync — an
edit on one side without the other (in either direction) recreates the drift
the audit just fixed.

### Forgetting to bump the README pin

Refreshing the skills without updating the README's "Target version" callout
(HEAD SHA + date) leaves readers unable to tell what the skills reflect.

### Bundling a new-skill PR with freshness fixes

Keep them on separate branches/PRs so each can be reviewed and reverted
independently.
