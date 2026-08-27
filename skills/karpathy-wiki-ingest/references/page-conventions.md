# Wiki page conventions (canonical)

Single source of truth for page format. The ingester writes pages following these conventions; the validator (`scripts/wiki-validate-page.py`) enforces them.

## Frontmatter

```yaml
---
title: "<page title>"
type: <category>           # plural form: concepts, entities, queries, ideas, projects, ...
tags: [tag1, tag2, ...]
summary: "<one line, <= 200 characters, no heading markup>"
sources:
  - raw/<basename>         # OR the literal string "conversation"
related:
  - /concepts/<slug>.md    # leading-slash, wiki-root-relative
created: "<ISO-8601 UTC>"
updated: "<ISO-8601 UTC>"
quality:
  accuracy: 1-5
  completeness: 1-5
  signal: 1-5
  interlinking: 1-5
  overall: <average>
  rated_at: "<ISO-8601 UTC>"
  rated_by: ingester       # OR "human" — human is sticky, ingester must not overwrite
---
```

`summary` is required on pages the ingester writes. It is the index
one-liner. Do not start it with `#`. Extra frontmatter keys named in
that wiki's `schema.md` are allowed; they are not plugin defaults.

Every `sources:` entry is cited in Evidence. Add the current raw path
to `sources:` only when this page's **claims** changed. A related-only
edit is not a claims change; do not append `sources:`. Why a sibling
was not merged belongs in `log.md`.

## Cross-link convention

All cross-links in the page body and the `related:` frontmatter use
**wiki-root-relative paths with a leading `/`**:

- ✅ `[Auth flow](/concepts/auth-flow.md)`
- ✅ `related: [/concepts/auth-flow.md]`
- ❌ `[Auth flow](concepts/auth-flow.md)` (relative; breaks when read from a nested page)
- ❌ `[Auth flow](../concepts/auth-flow.md)` (relative; breaks when page moves)

## Timestamp convention

`created`, `updated`, and `quality.rated_at` are actual UTC timestamps. When
working from a shell, generate them with:

```bash
date -u +%Y-%m-%dT%H:%M:%SZ
```

Never take local wall-clock output and merely append `Z`; that produces a
syntactically valid but factually incorrect timestamp on non-UTC machines.

## Quality block — never overwrite human ratings

If `rated_by: human`, the ingester MUST NOT change any quality field.
Human ratings are sticky. The ingester may add OTHER fields (sources,
related, etc.) but the quality block stays untouched.

If `rated_by: ingester` (or absent), the ingester re-rates on every
re-ingest.

`interlinking` scores whether the related list on the pages just written
is honest and useful, not whether every nearby page was edited.

## Body

The page is knowledge. Default sections, in this order:

- synthesis of the durable claims
- evidence (paths, dates, short quotes)
- limitations that add knowledge for this source
- related (a short list of pages whose objects were used)

Protocol choices (why this page, why a sibling, why not merged) go in
`log.md`.

## Targets

Choose one primary page for the capture's main knowledge object. Touch
another page only when that page's claims change. Entity pages are maps
(who or what, main frameworks, pointers), not append-only source catalogs.

## Split

Augment the existing page when the new source is the same knowledge
object. Create a sibling only for a distinct knowledge object (different
mechanism, surface, or decision). Split an oversized page when it still
holds two objects, or is still too long after dropping repetition. Two
sources about the same object stay on one page.

## Schema overlay

Headings in `<wiki>/schema.md` follow `schema-conventions.md`. After
reading `<wiki>/schema.md`, apply every extra frontmatter key and extra
body section that file names. If it names none, write only these plugin
defaults.

## Category directory

`type:` MUST equal `path.parts[0]` (the top-level directory name,
plural form). Validated by `wiki-discover.py` against the actual
directory tree.
