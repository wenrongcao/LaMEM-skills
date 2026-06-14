---
name: lamem-github-workflow
description: Workflow for committing, branching, pushing, and preparing pull requests for the LaMEM repository. Use this skill whenever the user asks to commit changes, create a branch, push to GitHub, prepare a PR, or wants to share work with the LaMEM project. Trigger on phrases like "create a branch", "push to GitHub", "open a PR", "prepare a pull request", "commit my changes", or any mention of `git`, `gh`, or pull-request descriptions for LaMEM.
---

# LaMEM GitHub Workflow

A skill for taking local changes in a LaMEM checkout through commit → push → pull request, while keeping commits clean, the working tree free of platform debris, and PR descriptions well-structured.

---

## Overview

A typical contribution flow:

1. Create a topic branch from `master` (or the current upstream branch).
2. Stage the relevant files only — exclude generated test artifacts and platform metadata.
3. Make one logical commit per concern (split unrelated changes).
4. Push the branch to the user's fork.
5. Either open a PR via GitHub UI (using a prepared title + markdown body) or via `gh pr create`.

Confirm with the user before each shared-state action: pushing, opening a PR, or force-pushing.

---

## Step 1 — Inspect the working tree

```bash
git status
git diff --stat
```

Group changes into logical commits **before** staging. A renaming + bug fix is one commit; an unrelated input-file cleanup is another.

---

## Step 2 — Create a topic branch

```bash
git checkout -b <branch_name>
```

Naming guidance: short, lowercase, hyphen- or underscore-separated, describing the change (`test_fix`, `topo-diff`, `add-passive-tracer-output`). Avoid generic names like `patch-1`.

---

## Step 3 — Stage files selectively

Stage only the files relevant to the current commit. Use file paths or directory paths, not `git add .` or `git add -A`:

```bash
git add path/to/file1 path/to/dir/
```

### Files to exclude

| Pattern | Reason |
|---------|--------|
| `._*` | macOS resource-fork metadata; never useful |
| `*.log`, `savegrid.log` | Local logs from prior runs |
| `Timestep_*/`, `markers/`, `*.pvd`, `*.vts` | Generated test artifacts |
| `bin/opt/`, `bin/deb/`, `lib/opt/`, `lib/deb/` | Build artifacts |

If `git status` shows an untracked `._<filename>` next to a file you intend to commit, delete the metadata file before staging the directory:

```bash
rm path/to/._*
```

After staging, always re-check:

```bash
git status -s
```

The list should contain only the intended files.

---

## Step 4 — Identity for the commit

If `git config user.email` and `user.name` are not set, **do not modify the global config**. Pass identity inline per commit:

```bash
git -c user.email="<email>" -c user.name="<name>" commit -m "..."
```

Use the user's actual identity (e.g., the GitHub email/username they want associated with the commit). Confirm before the first commit if not certain.

Do **not** add `Co-Authored-By: Claude ...` unless the user explicitly asks for it.

---

## Step 5 — Write the commit message

Follow the existing repository style — check `git log -5 --pretty=format:"%s"` to match tone (LaMEM commits are typically present-tense, short titles).

Structure:

```
<Imperative title, ≤ 72 chars, no trailing period>

<Body — wrap at ~72 chars. Explain *why* the change exists, not just
what it does. Mention the user-visible effect, the symptom that
prompted the fix, or the constraint being satisfied.>

<Optional bullet list of concrete changes:>
- Renamed X -> Y.
- Removed Z.
```

For multi-line messages, pass via heredoc to preserve formatting:

```bash
git commit -m "$(cat <<'EOF'
<title>

<body>
EOF
)"
```

If a single change touches several distinct concerns, **make multiple commits**. Reviewers can then read each commit independently and revert one without losing the other.

---

## Step 6 — Push the branch

```bash
git push -u origin <branch_name>
```

The `-u` sets the upstream so subsequent `git push` and `git pull` work without arguments. The push output includes a "Create a pull request" URL — share it with the user; do **not** open the PR automatically unless explicitly asked.

---

## Step 7 — Prepare a pull request

Two paths:

### Path A — User opens the PR in the GitHub UI

Provide the user with two artifacts to paste:

**Title:** short (≤ 70 chars), capturing the change in one line.

**Body (markdown):** structured sections — keep it scannable, not narrative.

Recommended template:

```markdown
## Summary

One short paragraph naming the problem this PR solves and the
high-level approach.

## Changes

### 1. <Change name>

- Bullet list of concrete, verifiable changes.
- Mention any rename / move / deletion explicitly.

### 2. <Change name>

- ...

## Verification

Commands the reviewer can run to check the change locally.

```
cd test && make test
```

## Notes for reviewers

- Anything subtle the reviewer should look at first.
- Whether the commits can be reviewed/reverted independently.
- Files intentionally *not* touched.
```

### Path B — Open the PR via `gh`

Only when the user explicitly asks. Use a heredoc for the body:

```bash
gh pr create --title "<title>" --body "$(cat <<'EOF'
<markdown body>
EOF
)"
```

For a PR from a fork to an upstream repo, add `--repo <upstream_owner>/LaMEM`.

---

## Common Pitfalls

### Accidentally committing macOS `._*` files

`git add directory/` picks them up if they exist alongside real files. Always run `git status -s` after staging and unstage anything matching `._*`:

```bash
git restore --staged path/to/._*
rm path/to/._*
```

### Mixing renames with content edits in one commit

Git records a rename only when the new file is sufficiently similar to the old one. If a file is both renamed and substantially rewritten in a single commit, `git log --follow` may lose the connection. Prefer committing the rename first, then the content edit, when both are large.

### Pushing to the wrong remote

Verify with `git remote -v` before pushing. The user's fork is the default `origin`; the upstream LaMEM repo (if configured) is typically `upstream`. Push topic branches to `origin`, not `upstream`.

### Force-pushing

Avoid `git push --force` unless the user explicitly authorizes it for that branch. Even then, prefer `--force-with-lease` to protect against unexpected upstream updates.

### Skipping hooks

Never use `--no-verify` to bypass pre-commit hook failures. If a hook fails, fix the underlying issue and commit again.

---

## Quick Reference

| Task | Command |
|------|---------|
| Status (concise) | `git status -s` |
| Recent commit titles | `git log -5 --pretty=format:"%s"` |
| Stage by path | `git add path/...` |
| Commit with inline identity | `git -c user.email="…" -c user.name="…" commit -m "…"` |
| Push new branch | `git push -u origin <branch>` |
| List remotes | `git remote -v` |
| Inspect a commit | `git show <sha>` |
| Compare branch to master | `git diff master...<branch>` |
| Open PR via CLI | `gh pr create --title "…" --body "$(cat <<'EOF' … EOF)"` |
