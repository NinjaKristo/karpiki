# RED: high-df tags and corpus names select too many pages

## Observed pressure

After object-first titles, "What did Carl say about CRO before $500k?"
still opened 6 pages on the compacted 10-page slice. Titles no longer
said Carl. Six pages were tagged `cro`. Step B treats a tag hit as
enough to select a page.

The same failure hits any shared label: a method family (`cro`), a
channel (`x-post`), or a person/corpus tag (`carl-weische`,
`davie-fogarty`). Patching one tag name does not fix the next corpus.

## Failure mode

A term that appears on many pages in the walked index selects all of
them. Rare terms in the same question (`$500k`, `checkout`, `hooks`)
never get to narrow the set.

## Required behavior

Count how many index entries a term hits (title, one-liner, or tag
list on that line). A term that hits 6 or more entries is common
(the Explore band). Rare terms select candidates (or any common
term if there is no rare term). Then AND each common term unless
that would leave zero pages. Frequency on the walked index is the
only test; do not denylist `cro`, owner tags, or corpus names.
