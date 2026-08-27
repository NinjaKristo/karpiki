# RED: sixth source for a clustered object mints a seventh page

## Observed pressure

A wiki already has six concept index lines whose title, one-liner, or
tag list contain the same object token (for example homepage). A new
capture about that object still creates another page. The index grows;
"how should the homepage look?" leaves the 1-5 inline-read band.

Evidence: Naturbiss homepage-* siblings; GitHub issue #17 / spec #15.

## Failure mode

Any-term match plus "different brand / different decision" is treated
as permission to create a sibling. The sixth-plus source never merges
into the best existing match.

## Required behavior

If the walked index has 6 or more hits on the capture's object token
(title, one-liner, or tag list on that line), ingest augments the best
existing match (signal-match count, then shorter title, then
alphabetical). A new page is allowed only when no object match exists.
Creating a sibling against a 6+ cluster logs `sibling-fanout`. This
capture does not compact the rest of the cluster.
