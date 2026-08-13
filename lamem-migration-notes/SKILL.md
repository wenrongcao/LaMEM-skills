---
name: lamem-migration-notes
description: Create migration guides or release notes comparing two LaMEM versions (e.g. v2.2.1 → v3.0.0). Use this skill whenever the user asks to compare two LaMEM versions, document breaking changes, write a migration guide, produce release notes, or update an existing migration document to a newer commit. Trigger on phrases like "migration guide", "release notes", "what changed between versions", "compare v2.x and v3.x", "breaking changes", or "update the migration doc".
---

# LaMEM Migration / Release Notes Creator

A skill for producing a **user-friendly migration guide** (or release notes) between two
LaMEM versions, validated empirically against both source trees, and delivered as a
Markdown file — with an optional standalone HTML page.

**Bundled reference examples** (in this skill's `examples/` directory — the skill is
self-contained, no need to hunt for them elsewhere):

- `examples/MIGRATION_v2.2.1_to_v3.0.0.md` — structural template for any new guide
- `examples/MIGRATION_v2.2.1_to_v3.0.0_standalone.html` — style template for the
  standalone HTML (Step 7)

---

## Ground Rules (read first)

1. **Plan before writing.** This is a multi-phase analysis task. Make the plan with a
   **high-capability model (Fable 5, or Opus if Fable is unavailable)** — either enter
   plan mode or spawn a Fable-powered planning agent (`model: "fable"`). Do not start
   diffing ad hoc.
2. **Target the newest commit, not just the release tag.** A release tag is often weeks
   behind the branch HEAD (e.g. tag `v3.0.0` = `e506616`, but HEAD `eaf75d4b` included
   4 post-release PRs). Always resolve both and document against HEAD, flagging changes
   made after the tag with an inline **_(post-release)_** marker.
3. **Important information goes at the very top.** Section 0 of the guide is a
   **TL;DR migration checklist** followed by a **Quick self-check** — a reader who only
   reads the first screen must learn every breaking change.
4. **Verify every claim in both trees.** Bulk parameter diffs produce false positives;
   grep each claimed add/remove in both source trees before it goes in the guide.
5. **Run experiments.** Execute unmodified old-version input files under the new binary
   to observe *real* failure modes (silent vs. loud). Empirical evidence beats reading
   the diff.
6. **Local artifacts only.** Write the `.md` (and optional `.html`) into the repo /
   local filesystem. **Do NOT publish to claude.ai** (no Artifact tool) and do not push
   to GitHub or any public site **unless the user explicitly asks**.
7. **Ask about HTML.** After the Markdown guide is approved, ask the user whether they
   also want a standalone HTML version (see Step 7).

---

## Step 1 — Locate the two versions and resolve commits

Both trees are usually checked out locally (e.g. `/home/<user>/LaMEM_v221` and
`/home/<user>/LaMEM_v310`). Confirm paths with the user if not obvious.

```bash
# In the NEW tree — resolve tag vs HEAD:
git -C <new_tree> log --oneline -10
git -C <new_tree> rev-parse --short HEAD
git -C <new_tree> tag --list 'v*' --sort=-creatordate | head
git -C <new_tree> log --oneline <tag>..HEAD        # post-release commits
git -C <new_tree> log -1 --format=%ci HEAD          # HEAD date

# Version strings printed by the binaries:
grep -rn "Version" <tree>/src/LaMEMLib.cpp | head
```

Record in the guide header: old version + release date, new version tag + tag date,
**and** the HEAD commit + date the guide reflects, plus the post-release PR numbers.

---

## Step 2 — Plan with a high model

Present the user a plan covering the phases below before executing. Recommended
phase structure (adapt as needed):

| Phase | What | Output |
|-------|------|--------|
| 1 | Git/PR history between versions (`git log`, GitHub PRs, changelog) | change inventory |
| 2 | Build system & requirements diff (`Makefile`, PETSc versions, compiler flags) | §"Requirements & build" |
| 3 | Directory layout diff (`diff <(ls old) <(ls new)`, moved/removed dirs) | §"Repository layout" |
| 4 | Input-parameter vocabulary diff (see Step 3) | removed/added/renamed param map |
| 5 | Solver-options comparison (old flags vs new DSL/presets) | the headline section |
| 6 | Tests & examples diff (renames, `.expected` conventions) | §"Tests & examples" |
| 7 | Source-level conventions (error macros, C++ standard, warnings) | §"For people who patched the source" |
| 8 | **Empirical validation** — run old inputs under new binary | pitfalls section |

---

## Step 3 — Parameter vocabulary diff (and its false positives)

Extract every parameter each version can parse:

```bash
grep -rhoP 'get(Int|Scalar|String)Param\s*\(\s*fb\s*,\s*_(REQUIRED|OPTIONAL)_\s*,\s*"\K[^"]+' \
    <tree>/src/ | sort -u > params_<ver>.txt
comm -13 params_old.txt params_new.txt   # candidates: added
comm -23 params_old.txt params_new.txt   # candidates: removed
```

**⚠️ Every candidate must be verified individually** — parameters read via variables,
loops, or `%lld`-style constructed names show up as false adds/removes:

```bash
grep -rn '"<param>"' <old_tree>/src/ <new_tree>/src/
```

Only claims confirmed by direct grep in *both* trees go in the guide's appendix table.

---

## Step 4 — Empirical validation (run the experiments)

Compile the new version if needed (`cd src && make mode=opt all`, or `cd test && make test`
which compiles first). Then run **unmodified old-version input files** under the new binary:

```bash
<new_tree>/bin/opt/LaMEM -ParamFile <old_input>.dat -nstep_max 1
```

Classify every observed behavior:

- **SILENT pitfall** — removed parameters that are *ignored* (model runs with defaults;
  the user's settings are dropped without warning). These are the most dangerous and
  must be flagged loudest in the guide.
- **LOUD pitfall** — hard errors with a message (e.g. `Less than two cells are
  specified…`). Quote the exact error text so users can grep for it.

Also verify positive claims: run one worked before/after solver-block example and show
the option dump (`view_solvers = 1` / `monitor_solvers = 1`) matches expectations.

---

## Step 5 — Write the Markdown guide

**File:** `MIGRATION_v<old>_to_v<new>.md` in the new tree's repo root (or where the
user asks). Model the structure on the bundled example
(`examples/MIGRATION_v2.2.1_to_v3.0.0.md` in this skill's directory):

```
# Migrating LaMEM from v<old> to v<new>
  <2-3 line intro: versions, dates, upstream PR link>
  > blockquote: which HEAD commit this reflects; post-release PRs; methodology note

## 0. TL;DR — the migration checklist      ← IMPORTANT INFO FIRST
   Numbered list: every breaking change, one line each, with §-links
   and ⚠️ markers on silent failures.
### Quick self-check when migrating a file
   Ordered grep-based checklist a user can walk top-to-bottom on one .dat file,
   each item naming the error message they'd otherwise hit.

## 1. Requirements & build
## 2. What's new (the "why")
## 3. Repository layout changes
## 4. <Headline change — e.g. solver options>     ← old way / new way / param map /
                                                     presets / worked before-after example
## 5. Input-file (.dat) breaking changes          ← one subsection per breaking change
## 6. Tests & examples
## 7. For people who patched the source
## 8. Pitfalls & troubleshooting                  ← SILENT pitfalls first, then LOUD
## Appendix: parameter change reference           ← the verified add/remove table
```

Style rules:
- Flag post-tag changes inline with **_(post-release)_**.
- Every claim carries a `file.cpp:line` reference into the new tree or a demonstrated
  runtime behavior.
- Before/after code blocks for anything users must rewrite.
- Tables for parameter maps; prose kept short and scannable.

---

## Step 6 — Review loop

Show the user the guide (or its section outline + TL;DR) and iterate. Keep the `.md`
as the **source of truth** — any later edits go to the md first, then propagate to
derived HTML.

---

## Step 7 — Ask about standalone HTML

After the Markdown is accepted, **ask the user** whether they want a standalone HTML
version. If yes:

- **Use the bundled example as the style reference and keep the same style:**
  `examples/MIGRATION_v2.2.1_to_v3.0.0_standalone.html` in this skill's directory.
  Read it first and reuse its visual language — layout, typography, color palette,
  sticky table-of-contents sidebar, callout/pitfall boxes, before/after code blocks,
  light/dark theming. New guides should look like siblings of the existing one.
- Generate a self-contained page (inline CSS/JS only, no CDN links) so it opens with
  a plain `file://` double-click.
- Wrap in a full skeleton: `<!DOCTYPE html><html><head><meta charset>…<title>…</head><body>…</body></html>`.
- Support light/dark via `prefers-color-scheme`; wide tables scroll in their own
  `overflow-x: auto` container.
- Name it `MIGRATION_v<old>_to_v<new>_standalone.html` next to the md.
- A high model (Fable 5) does the design/authoring well — but constrain scope: convert
  the md faithfully in the reference style, **no unrequested content changes**.

**Do not** publish to claude.ai Artifacts. Files stay local.

---

## Step 8 — Optional publication (only on explicit request)

If — and only if — the user asks to share publicly (e.g. GitHub):

```bash
gh repo create <name> --public --source=<staging_dir> --push
```

Typical layout: `README.md` = the guide itself, plus the standalone HTML alongside.
Confirm repo name and visibility with the user (AskUserQuestion) before creating.

---

## Common Pitfalls

### Trusting the release tag
The tag is not the branch tip. Guides written against the tag miss post-release fixes;
always `git log <tag>..HEAD` and document the delta.

### Bulk-diff false positives
`comm`-based parameter diffs flagged params as "added" that existed in both trees
(read through indirection). Never publish an appendix row without a direct grep hit
in both trees.

### Burying the breaking changes
Putting the checklist at the end (natural "conclusion" position) means most readers
never see it. TL;DR + self-check go at §0, before anything else.

### Understating silent failures
A removed-but-ignored parameter is worse than a hard error: the model runs and gives
*different results*. Silent pitfalls get the ⚠️ marker, first position in the pitfalls
section, and a mention directly inside the TL;DR item that concerns them.

### Scope creep in the HTML step
Design agents tend to "improve" content while converting. Instruct explicitly: faithful
conversion of the approved md, flag any content change for approval instead of making it.

### Accidental publication
Never call the Artifact tool for these guides and never push to a remote without the
user's explicit go-ahead. Local files only by default.
