# RED: doctor census rewrites page synthesis

## Observed pressure

A wiki has a large object cluster (many sibling pages, fat index). The
operator runs `wiki doctor`. Without a census-only skill, a strong model
compacts or restyles page bodies while "fixing" the wiki.

Evidence: spec #15 / ticket #20; Naturbiss homepage/PDP siblings.

## Failure mode

Census, schema patch, and tag/frontmatter repair are treated as permission
to rewrite synthesis. Playbook compact happens in the doctor worker.
Historical 200-line split proposals are applied as real splits.

## Required behavior

Doctor runs validators and tag lint, patches schema/tags/frontmatter/related,
and records rewrite jobs under `.wiki-pending/rewrite-jobs/`. Page body
synthesis stays unchanged. The doctor does not execute those rewrite jobs.
