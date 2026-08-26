# RED: related-only ingest appends sources: without new claims

## Observed pressure

Naturbiss live AOV page `concepts/aov-perceived-value-upsells-and-pre-500k-offer-cro.md`
lists 20 `sources:` while the body is one 2026 reply. Later units
touched the page to add see-also / "do not collapse" notes. Ingest
step 6d treated those touches as claims changes and appended each
new raw path.

A compact pass that copied that `sources:` list onto an overlay body
kept the lie: 20 files in frontmatter, one file in Evidence.

## Failure mode

`sources:` grows with related-link edits. Accuracy rating ("every claim
maps to evidence in sources:") becomes uncheckable. Compact and
retrieval then inherit a source catalog that the page does not use.

## Required behavior

Add the current raw path to `sources:` and Evidence only when this
page's claims changed. A related-only edit is not a claims change.
Protocol (why not merged) stays in `log.md`.
