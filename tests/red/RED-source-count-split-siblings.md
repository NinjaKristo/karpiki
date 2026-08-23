# RED: source-count split mints sibling pages

## Observed pressure

Naturbiss first-batch ingest (2026-08-23) turned a 31-word tweet about
accent CTAs into a 231-line sibling of about ten nearby color/CTA pages.
The ingester treated "2+ sources or 200+ lines" and title-scope as a
mandate to create a new page, then ran missed-cross-link and reciprocal
see-also updates across those siblings.

Evidence: `~/dev/naturbiss/wiki/concepts/color-visual-hierarchy-black-white-site-accent-cta.md`
and `ISSUES.md` (default split and cross-link rules).

## Failure mode

Two sources about the same knowledge object produce two pages, a
Title-scope note on the page, and edits to pages whose claims did not
change. Indexes and entity catalogs grow while query quality falls.

## Required behavior

The same knowledge object is augmented on one page. A sibling is created
only for a distinct object. The choice is logged in `log.md`. Related
links are written on the primary page during that write. Extra
frontmatter keys and body sections exist only when that wiki's
`schema.md` names them.
