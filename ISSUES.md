---
title: karpathy-wiki issues
status: living-document
last_reviewed: 2026-08-26
---

# ISSUES

Known bugs, risks, regressions, blocked work, and technical debt for the
plugin. This file is a local scratchpad. It is not the `wiki issues` command,
not `.ingest-issues.jsonl`, not a GitHub Issues replacement, and not a
work-package manifest.

Promote an entry to GitHub Issues only when starting public, collaborative, or
automated work on it. Shipped fixes belong in `CHANGELOG.md`, not here.

Entries below were filled from the 2026-08-23 plugin audits and the Naturbiss
first-batch canary. They are problems to remember, not a work-package order.

---

## Accepted limitation: least-privilege containment for detached provider workers

```yaml
status: accepted-limitation
priority: p1
severity_if_triggered: high
effort: large
labels: [security, provider-runtime, blast-radius]
revisit_when:
  "Before unattended ingestion is offered for collaborator-controlled or
  otherwise untrusted captures and source files."
refs:
  - scripts/wiki_dispatch.py (provider environment inheritance)
  - scripts/wiki_providers.py (headless provider permission modes)
  - skills/karpathy-wiki-ingest/SKILL.md (semantic shell workflow)
  - docs/benchmarks/2026-08-20-grok-4.5-vs-4.6-medium.md
```

v0.3.0 treats detached ingesters as trusted local automation. Grok uses
`--always-approve`, Codex is launched with `danger-full-access`, and the
dispatcher passes the launcher's environment to provider processes. A hostile
capture can therefore attempt prompt injection against data and commands
available to the host user.

A Grok 4.5 Low canary on macOS established the useful but incomplete boundary:

- a project `.grok/sandbox.toml` profile based on the worker's current working
  directory can cover arbitrary project-wiki and main-wiki locations;
- `dontAsk` plus explicit read, edit, and command rules denied an unrelated
  test secret while allowing an exact helper;
- denying Grok's authentication file caused `Not signed in`, so provider auth
  cannot simply be placed outside every readable path;
- the production ingest traces use multiple general shell operations rather
  than one already-brokered helper;
- Grok's child-process network restriction is not enforced on macOS.

A complete fix should be provider-neutral and should include all of the
following in one separately reviewed workstream:

1. Construct a minimal explicit environment allowlist instead of copying
   `os.environ`, with no unrelated credentials.
2. Generate a fail-closed per-run path policy for the exact wiki, capture,
   evidence files, Git metadata, runtime files, and plugin-owned helpers.
3. Move locking, parsing, manifest updates, validation, Git publication, and
   completion behind deterministic helpers so the model does not need general
   shell authority.
4. Isolate provider authentication, preferably with a dedicated worker account
   or credential broker, while preserving non-interactive sign-in.
5. Apply equivalent policy to Grok, Codex, and Claude rather than documenting
   one provider as secure while the others retain broad host access.
6. Add adversarial prompt-injection, arbitrary-path, environment-secret,
   network, project-wiki, main-wiki, and `both` promotion canaries on macOS and
   Linux where supported.

Until every item is implemented and tested, unattended ingest remains for
trusted local content only. The v0.3.0 release documents and accepts this
limitation; it does not claim that `--always-approve` is sandboxed.

---

## Future: `allowed-tools` scoping on the four skills

```yaml
status: deferred
priority: p2
effort: medium
labels: [security, blast-radius]
revisit_when:
  "Next read-protocol-cycle planning. Orthogonal to read-protocol
  restoration; was deliberately not folded into 0.2.7 to keep the
  read-protocol commits independently revertable from security-scoping
  commits. Should ship alongside `bin/wiki orient` — the new CLI gives
  the read skill a cleaner `allowed-tools` entry."
refs:
  - skills/using-karpathy-wiki/SKILL.md (loader — no scoping; remains permissive)
  - skills/karpathy-wiki-capture/SKILL.md (capture — scope `bin/wiki capture` + `mv` to `inbox/`)
  - skills/karpathy-wiki-read/SKILL.md (read — scope `bin/wiki orient` + Read/Grep/Glob/WebFetch/WebSearch/Task)
  - skills/karpathy-wiki-ingest/SKILL.md (ingest — scope `scripts/wiki-*` + python3 + git)
```

Today no `karpathy-wiki-*` skill declares `allowed-tools`, so each
skill runs with full tool access when active. The prose narrows intended usage,
but the harness does not enforce that boundary. `allowed-tools` would make the
scope explicit for supported interactive hosts. This does not solve the
detached-provider boundary above; that worker is a separate provider process
with its own permission, sandbox, environment, and credential behavior.

Per-skill draft:

| Skill | `allowed-tools` |
|---|---|
| `using-karpathy-wiki` | none — loader, not actor; per upstream pattern, loaders don't restrict |
| `karpathy-wiki-capture` | `Bash(bin/wiki capture:*)`, `Bash(mv * <wiki>/inbox/*)`, `Read`, `Write(/tmp/*)` |
| `karpathy-wiki-read` | `Bash(bin/wiki orient:*)`, `Read`, `Grep`, `Glob`, `WebFetch`, `WebSearch`, `Task` |
| `karpathy-wiki-ingest` | `Bash(scripts/wiki-*:*)`, `Bash(python3 scripts/wiki-*.py:*)`, `Read`, `Edit`, `Write`, `Bash(git ...)`, `Bash(flock ...)` |

The ingester's broad write permissions are scoped to its own spawned
`claude -p` process — main-agent permissions are unaffected.

---

## P0: scheduler status is false-green on a stale CLI path

```yaml
status: open
priority: p0
effort: medium
labels: [scheduler, observability]
revisit_when: "When a live wiki scheduler install is next requested; code now reports broken."
refs:
  - scripts/wiki_scheduler.py (_global_status)
  - SPECS/0.3.1-global-scheduler.md (CLI path and stale-path reporting)
  - ~/Library/LaunchAgents/com.toolboxmd.karpathy-wiki.scheduler.plist
```

Live 2026-08-23: LaunchAgent `ProgramArguments` is
`~/.codex/plugins/cache/toolboxmd/karpathy-wiki/0.3.1/bin/wiki`. That file does
not exist. `0.3.2` does. `launchctl` last exit is `78: EX_CONFIG`. Status can
still report `state: installed` and `loaded: true` because it only checks that
the plist exists and launchd has the label loaded. Spec 0.3.1 required
reporting the CLI path and detecting stale paths. Not implemented.

`wiki scheduler status` now reports `broken` when the plist program or the
recorded CLI is missing, including a loaded LaunchAgent that still points at
a deleted snapshot. Live repair is still not a gate: the machine plist is
unchanged until someone runs `wiki scheduler install`. Orphaned captures can
wait.

---

## P0: LaunchAgent stores a versioned plugin-cache path

```yaml
status: open
priority: p0
effort: medium
labels: [scheduler, packaging]
revisit_when: "With the false-green status fix."
refs:
  - scripts/wiki_scheduler.py (install_global, build_launch_agent)
```

New installs write `$WIKI_CONFIG_HOME/scheduler/run` as the plist program and
record the real `bin/wiki` in `current-cli`. VERSION bumps no longer change
the plist path. The live machine plist still points at the deleted `0.3.1`
cache until the next `wiki scheduler install`. A checkout bump still does not
refresh a Codex cache folder.

---

## P0: release identity disagrees with installed identity

```yaml
status: open
priority: p0
effort: small
labels: [versioning, packaging]
revisit_when: "When tagging a release, or when rewriting README/MANUAL to stop pinning a version in prose."
refs:
  - VERSION
  - .version-policy.json
  - .codex-plugin/plugin.json
  - .claude-plugin/plugin.json
  - README.md
  - MANUAL.md
```

Plugin manifests are versionctl mirrors of `VERSION`. That closes checkout
identity between `VERSION` and both `plugin.json` files. Remaining drift:
README status and MANUAL title still pin an older prose version; there are
still no git tags or GitHub Releases; README still tells users to install
from mutable `main` while policy says `released-tags-only`.

Markdown prose is not a versionctl mirror. A checkout bump still does not
rewrite LaunchAgent or the Codex cache folder until plugin reinstall plus
`scheduler install`.

---

## P0: CHANGELOG has two heading dialects

```yaml
status: open
priority: p1
effort: small
labels: [versioning, docs]
revisit_when: "When rewriting CHANGELOG to one heading dialect."
refs:
  - CHANGELOG.md
  - agentsmd tools/versionctl changelog.py (`## [version] - date`)
```

The file opens with `## Unreleased - 2026-08-22` and `## 0.3.2 - 2026-08-21`,
then a historical YAML dump, then versionctl headings `## [0.3.13]` through
`## [0.3.4]` at the bottom. Doctor treats the bracketed heading as consistent
and never notices the human section at the top. Humans never see 0.3.13.

---

## P0: installed Codex snapshot contains checkout and wiki data

```yaml
status: open
priority: p0
effort: medium
labels: [packaging, privacy]
revisit_when: "Before the next marketplace install or public package."
refs:
  - tests/unit/test-codex-plugin-packaging.sh
  - ~/.codex/plugins/cache/toolboxmd/karpathy-wiki/0.3.2
```

Live `0.3.2` cache is 33 MB: 13 MB `.git`, 3.6 MB project `wiki/`, 11 MB
benchmarks, plus tests, planning, tmp, and runtime scratch. The packaging test
checks manifests and skill discovery, not the produced artifact. Copying a
project wiki into an install cache is a privacy problem.

Need an allowlisted staging tree or git archive, and a test that rejects
`.git`, `wiki/`, `.wiki-config`, benchmarks, tmp, and caches.

---

## P0: ingest transaction is prompt law, not a helper

```yaml
status: open
priority: p0
effort: large
labels: [ingest, integrity]
revisit_when: "After the generic page-contract work, as its own workstream."
refs:
  - skills/karpathy-wiki-ingest/SKILL.md (step 4 staging dance)
  - scripts/wiki-manifest.py
  - scripts/wiki-scan.sh
  - scripts/wiki-complete-ingest.sh
```

The model is instructed to stage evidence, take locks, mutate the manifest,
rename into `raw/`, edit pages, rebuild indexes, validate, and complete.
Crash between manifest write and `raw/` rename leaves a manifest entry for a
missing file (`DELETED`). Scan recovers `NEW` and `MODIFIED` only. Staging
cleanup is deferred to stub `wiki doctor`.

Completion calls manifest validation, but that check is mostly `origin` shape.
It does not enforce raw-file existence, SHA equality, timestamp types,
referenced page existence, or reciprocal `sources:`.

Intended shape later: `ingest prepare` and `ingest complete` as deterministic
helpers. The model chooses pages and writes bodies.

---

## P1: capture-input failure can cool the whole provider profile

```yaml
status: open
priority: p1
effort: medium
labels: [dispatcher, provider]
revisit_when: "Next dispatcher classification session."
refs:
  - scripts/wiki_providers.py (ProviderError)
  - scripts/wiki_dispatch.py (configuration_or_auth_failure)
```

Attachment-local failures raise the same `ProviderError` as broken provider
config. The worker records `configuration_or_auth_failure` and applies a
profile-wide cooldown without consuming the attempt budget. A missing image
can block unrelated valid captures and retry indefinitely.

Need distinct outcomes: capture-input (terminal for that capture),
configuration, authentication, transient retry, semantic rejection.

---

## P1: auto-commit stages the entire wiki working tree

```yaml
status: open
priority: p1
effort: small
labels: [git, ingest]
revisit_when: "When completion already knows the touched-page set."
refs:
  - scripts/wiki-commit.sh (`git add -A -- .`)
```

Auto-commit stages every dirty path under the wiki, not only run-owned files.
Tests prove a parent-repo file is excluded; they do not prove unrelated wiki
edits are preserved. Refuse auto-commit on pre-existing dirt, or stage only
the run's paths.

---

## P1: two capture-claim implementations

```yaml
status: open
priority: p1
effort: small
labels: [capture, drift]
revisit_when: "When tightening the ingest skill."
refs:
  - scripts/wiki_dispatch.py (os.replace claim)
  - scripts/wiki-capture.sh (wiki_capture_claim)
  - skills/karpathy-wiki-ingest/SKILL.md (fallback if WIKI_CAPTURE unset)
```

Production claim is dispatcher `os.replace` to `.processing`. The skill still
tells the model to call `wiki_capture_claim` if `WIKI_CAPTURE` is missing.
Two claimers will drift.

---

## P1: YAML and timestamps are not one parser

```yaml
status: open
priority: p2
effort: medium
labels: [parsing, drift]
revisit_when: "When completion or capture is next opened."
refs:
  - scripts/wiki_yaml.py
  - scripts/wiki-complete-ingest.sh
  - scripts/wiki-status.sh
  - scripts/wiki-promote-capture.py
  - bin/wiki (captured_at)
```

Page YAML goes through `wiki_yaml.py`. Completer, status, and promoter each
have another dialect. Duplicate keys last-win in the custom parser. Capture
`captured_at` uses a filename-safe stamp rather than canonical ISO-8601 UTC.
Archive directories use local `date +%Y-%m`, so month identity can disagree
with UTC capture time near month boundaries.

---

## P1: page locks are skill-enforced noclobber files

```yaml
status: open
priority: p2
effort: medium
labels: [locking]
revisit_when: "With ingest prepare/complete helpers."
refs:
  - scripts/wiki-lock.sh
```

The runtime never takes page locks. The model is asked to. Reclaim is
mtime-based and does not check whether the owner is alive. Release does not
verify the recorded token. Two concurrent workers on one page is a
compliance problem, not a runtime one. A corrupt per-wiki lease can hold the
only slot; `wiki doctor` is still a stub.

---

## P1: default split and cross-link rules mint siblings and protocol pages

```yaml
status: open
priority: p1
effort: medium
labels: [ingest-contract, skill]
revisit_when: "After Naturbiss overlay on a small sample; A/B on 2026-08-23 favored B."
refs:
  - skills/karpathy-wiki-ingest/references/page-conventions.md
  - skills/karpathy-wiki-ingest/SKILL.md
  - scripts/wiki-init.sh (seeded schema.md)
  - tests/red/RED-source-count-split-siblings.md
```

Plugin defaults now augment the same knowledge object, write related links
on the primary page, and log protocol choices. New wikis seed that split
rule. Existing pages (Naturbiss siblings, entity catalogs) still need the
A/B and a later overlay before resume. Not a validator hard-reject.

---

## P1: index descriptions take the first body paragraph, including headings

```yaml
status: open
priority: p1
effort: small
labels: [index, ingest-contract]
revisit_when: "After new pages are written with summary; old pages still fall back."
refs:
  - scripts/wiki-build-index.py (_description)
  - skills/karpathy-wiki-ingest/references/page-conventions.md
```

The generator now prefers `summary`, else the first non-heading body
paragraph. Old pages without `summary` still fall back. Indexes stay
poisoned until those pages are rewritten or given a summary. Do not
special-case brand field names in the plugin builder.

---

## P1: common signal terms flood read Step B

```yaml
status: open
priority: p1
effort: small
labels: [read-protocol, retrieval]
revisit_when: "After a Q2 retrieval glance on the overlay temp wiki with the half-index drop."
refs:
  - skills/karpathy-wiki-read/SKILL.md (Step B)
  - tests/red/RED-read-common-signal-terms.md
  - tests/acceptance/grok/2026-08-23-density-contract-ab.md
```

2026-08-25 matched retrieval: "what did Carl say about CRO before $500k?"
matched 9 overlay pages and 13 live-cherry pages because the owner name
is in every title or one-liner. Gold claims were on one page. Step B now
drops a term that hits more than half the index entries and keeps the
original set only when every term is common. Skill prose, not a matcher
binary. Old pages still poison answers with Status banners until rewritten.

---

## P1: related-only ingest inflates sources:

```yaml
status: open
priority: p1
effort: small
labels: [ingest-contract, provenance]
revisit_when: "After compact recipe uses Evidence-cited sources only; ingest 6d related-only rule is in the skill."
refs:
  - skills/karpathy-wiki-ingest/SKILL.md (step 6d)
  - skills/karpathy-wiki-ingest/references/page-conventions.md
  - tests/red/RED-see-also-inflates-sources.md
```

See-also / do-not-merge edits appended each capture's raw path to
`sources:` even when the page's claims did not change. Compact must
list only files cited in Evidence. Skill now: related-only is not a
claims change.

---

## P2: capture skill still documents `.wiki-mode`

```yaml
status: open
priority: p2
effort: small
labels: [docs, drift]
revisit_when: "Next capture-skill edit."
refs:
  - skills/karpathy-wiki-capture/SKILL.md (Mode change)
```

Routing authority is XDG `workspaces/<hash>/runtime.toml` via `wiki use`.
The capture skill still says mode is persisted in `.wiki-config` or
`.wiki-mode`.

---

## P2: executable-looking historical docs

```yaml
status: open
priority: p1
effort: small
labels: [docs, process]
revisit_when: "Docs hygiene session; not bundled with ingest-contract code."
refs:
  - docs/planning/RESUME.md
  - SPECS/0.3.1-global-scheduler.md (status still ready-for-implementation)
  - docs/specs/
  - docs/planning/
  - docs/superpowers/
```

`RESUME.md` says implementation has not started and the next agent should
execute a 29-task plan on `v2-rewrite`. Current reality is 0.3.x on `main`.
Specs live in four directories. 0.3.1 is shipped and still marked
ready-for-implementation. `docs/specs/0.2.8.md` correctly says `shipped`.

Need one live spec home (`SPECS/`), archived historical plans, and a banner
on retained handoffs. Do not mass-delete rationale.

---

## P2: AGENTS.md mixes contributor PR rules with working instructions

```yaml
status: open
priority: p2
effort: small
labels: [docs, process]
revisit_when: "When opening CONTRIBUTING.md."
refs:
  - AGENTS.md
  - docs/planning/2026-08-12-test-strategy-rightsizing-handoff.md
  - docs/planning/2026-08-12-test-strategy-rightsizing-audit.md
```

PR checklist, "we will not accept," and transcript-in-PR-description belong
in `CONTRIBUTING.md`. AGENTS still requires full suite, test-before-script,
and a pressure scenario for every SKILL.md change, plus a Superpowers skill
that is not in this checkout. The rightsizing audit and focused `run-all.sh`
groups already exist. The handoff pointer still says Phase 1 must run; the
audit says Phase 1 is complete and waiting for human review.

---

## P2: `tests/self-review.sh` is red and not in `run-all.sh`

```yaml
status: open
priority: p2
effort: small
labels: [tests]
revisit_when: "When aligning test policy."
refs:
  - tests/self-review.sh
  - README.md
```

README still recommends it as a final gate. It fails: Stop hook (removed),
`AGENTS.md` is a symlink (now the reverse), every Python file executable
(many are `python3` invoked). It is not discovered by `tests/run-all.sh`.

---

## P2: GitHub issue #10 is not cross-indexed here

```yaml
status: open
priority: p2
effort: small
labels: [process]
revisit_when: "When triaging public issues against this ledger."
refs:
  - https://github.com/toolboxmd/karpathy-wiki/issues/10
```

Schema-regeneration defect exists as a public issue. This scratchpad did not
point at it.

---

## Watchpoint: Naturbiss first batch is the ingest-contract canary

```yaml
status: watchpoint
priority: p1
effort: n/a
labels: [canary, ingest-contract]
revisit_when: "After object-first schema and common-term read; live compact vs reingest vs index-only is still open. Do not resume the 4114-unit drain."
refs:
  - ~/dev/naturbiss/wiki
  - ~/dev/naturbiss/ingest-ready/carl-weische
```

Curation-before-inbox, claim vs visible evidence vs applicability, and
verbatim provenance are the parts to keep. The plugin default contract
amplified them into unusable pages. Queue stays paused. This is not a
Naturbiss implementation list; it is why the plugin split/fanout/index
issues above are not theoretical.

---
