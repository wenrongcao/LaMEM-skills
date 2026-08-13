---
name: lamem-skill-maintenance
description: Meta-skill for keeping the LaMEM Claude Code skills themselves up to date against the current upstream HEAD. Use this skill whenever the user asks to refresh, audit, or verify the LaMEM skills, check whether the skills are stale, re-validate skill claims against the codebase, or propagate skill fixes to the public LaMEM-skills repo. Trigger on phrases like "update the skills", "are the skills stale", "audit the skills", "freshness check", "verify the skills against HEAD", "sync the skills repo", or any mention of skill drift or the LaMEM-skills GitHub repository.
---

# LaMEM Skill Maintenance (Meta-Skill)

A skill for auditing and refreshing the other LaMEM skills (`lamem-codebase`,
`lamem-test-creator`, `lamem-github-workflow`, `lamem-migration-notes`) so their
factual claims stay true as the LaMEM codebase evolves. The skills live in
`/home/wenrongc/LaMEM_v310/.claude/skills/` and are mirrored to the public repo
`https://github.com/wenrongcao/LaMEM-skills` (default branch `master`).

**The central insight: freshness is judged by the upstream COMMIT SHA, not the
version number.** The skills target LaMEM v3.1.0. Upstream does bump the version
(3.0.0 → 3.0.1 → 3.0.2 → 3.1.0), but it always lags `master`: dozens of commits
land under an unchanged string, so a skill can be badly stale while the printed
version looks current. Always compare against the SHA, never the version string.

---

## Step 1 — Establish the freshness baseline

Resolve exactly which commit the codebase is at and how far it has moved past
the release tag:

```bash
git -C /home/wenrongc/LaMEM_v310 rev-parse --short master
git -C /home/wenrongc/LaMEM_v310 log -1 --format=%ci master
git -C /home/wenrongc/LaMEM_v310 describe --tags master     # e.g. v3.0.0-46-geaf75d4b
```

**If the clone has no tags** (`git describe` → *"No names found"*, common for a
fresh `git clone` of a fork), fall back to the version-bump commits and to the
SHA recorded in the skills README:

```bash
# find the release boundary without tags
git -C /home/wenrongc/LaMEM_v310 log --oneline --all --grep="[Vv]ersion" | head
# drift window = last audited SHA (from README pin) .. master
git -C /home/wenrongc/LaMEM_v310 log <last-audited-sha>..master --oneline --merges
git -C /home/wenrongc/LaMEM_v310 log <last-audited-sha>..master --oneline | wc -l
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

**Real example (v3.0.0 → v3.1.0 audit, 54 commits of drift):** most breakage was
in *procedures*, not counts — `runtests.jl` had replaced its `maintenance = true` /
`update_expected = true` block with `mode=` targets, `make purge` no longer existed,
every `@testset` now needed a `should_run_test(...)` wrapper, and `CHKERRQ` had been
removed from `src/` entirely. **Run the documented commands, don't just read them**:
a stale procedure looks perfectly plausible on the page. The audit before that caught
an enumerated count (35 tests / next `t36` vs the real 36 / `t37`). Grep, `ls`, and
execute the actual thing; never eyeball.

**Watch for contested test numbers.** "Next test number" can be claimed by more than
one in-flight PR at once — check open PRs, not just the merged tree:
`gh pr list --repo UniMainzGeo/LaMEM --state open`.

**migration-notes skill specifics:** the shipped guide now lives at
`doc/src/man/Upgrade_v2.2.1_to_v3.0.0.md` in the LaMEM repo. The bundled
`examples/*.md` is **intentionally not byte-identical** to it: the repo copy is
rendered by Documenter.jl and uses `[§4](@ref "…")` cross-references plus an
"Upgrading from…" title, while the bundled copy is standalone Markdown with plain
`#anchor` links. Diff them to confirm only those two classes of difference (title
line and link syntax) and that the body/section count still matches — not that the
files are identical.

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

### Trusting the printed version string

It advances only at release commits, not as `master` moves; a skill can be weeks
stale while the version looks current (v3.1.0 landed 54 commits after the last
audit, most of them under an older string). Always diff against the SHA.

### Missing enumerated-count drift

Test counts, "next test number", file lists — grep/`ls` the actual thing, never
eyeball. (PR #69 adding `t36_spatially_limited_erosion` was the only stale claim
in the v3.0.0 audit.)

### Documented procedures that silently stopped working

The bigger risk than counts. A workflow block (`maintenance = true`, `make purge`,
a bare `@testset` template) keeps reading correctly long after upstream replaced it.
Actually run the commands the skill tells the user to run.

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
