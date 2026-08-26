# RED: common signal terms flood read Step B

## Observed pressure

2026-08-25 retrieval on two matched 10-source wikis. Question: "What
did Carl say about CRO before $500k?"

The read protocol's Step B treats any signal term as sufficient. The
owner name substring-matched every index title or one-liner. Overlay
wiki: 9 candidates. Live-cherry wiki (same sources, old pages): 13
candidates, every concept title. Gold claims lived on one page. Both
agents still found it, but they left the 1-5 inline-read band (6+ is
Explore).

Evidence: overlay `/tmp/karpathy-wiki-overlay/wiki/queries/_index.md`;
live-cherry `/tmp/karpathy-wiki-retrieval/wiki-live-cherry/concepts/_index.md`.

## Failure mode

A corpus or owner name that appears on most pages is treated as a
discriminator. "What did <owner> say about X" opens the whole category
instead of the pages that mention X.

## Required behavior

After extracting signal terms, drop any term that substring-matches
more than half of the entries in the `_index.md` being walked (title
or one-liner). Recount with the remaining terms. If every term is
common, keep the original set. The 0 / 1-5 / 6+ branches stay as they
are.
