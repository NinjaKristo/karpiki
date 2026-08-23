# Grok 4.6 Medium density-contract A/B

Date: 2026-08-23

Model: Grok 4.6 Medium via plugin dispatcher (`wiki ingest-now` / `wiki capture` then tick). Grok CLI 1.0.5 (5115b46bc909). Isolated `WIKI_CONFIG_HOME=/tmp/karpathy-wiki-ab/config-home`. Isolated `WIKI_POINTER_FILE=/tmp/karpathy-wiki-ab/home/.wiki-pointer` (`none`). Production `~/.config/karpathy-wiki` and `/Users/lukaszmaj/dev/naturbiss/wiki` were not written. Temp wikis remain under `/tmp/karpathy-wiki-ab/` for inspection.

## Commits

| Arm | Tree | SHA | Contract |
| --- | --- | --- | --- |
| **A (old)** | `/tmp/karpathy-wiki-ab/tree-A` | `ba42f5247e1f504b35611b326cc8a04312a3706c` (`ba42f52`) | Source-count / 200-line split; Title-scope; missed-cross-link 7.5 |
| **B (new)** | `/Users/lukaszmaj/dev/toolboxmd/karpathy-wiki` | `03dc82059b7dc2ddcc1fa46e6fc2368429b01dbd` (`03dc820`) | Object-based split; no missed-cross-link 7.5; schema overlay; related list; protocol in `log.md` |

Wikis: `/tmp/karpathy-wiki-ab/wiki-A`, `/tmp/karpathy-wiki-ab/wiki-B`. Both `wiki config init-local ... --default-provider grok --default-model grok-4.6 --default-effort medium --max-processes 1 --dispatch-mode session_start`. Profile on every run: `grok_medium` / `grok-4.6` / medium.

## Fixtures (copied, not moved)

Base copies under `/tmp/karpathy-wiki-ab/fixtures/`.

1. Short text post: `/Users/lukaszmaj/dev/naturbiss/ingest-ready/carl-weische/ready/post-1536048997013544961.md` (PDP ATF / USP / reviews / CTA list). Inbox drop, text-only.
2. Long thread-like post: `/Users/lukaszmaj/dev/naturbiss/ingest-ready/carl-weische/ready/post-1673327854153527296.md` (11-event D2C resource list). Inbox drop.
3. Article: `/Users/lukaszmaj/dev/naturbiss/ingest-ready/carl-weische/ready/article-2025213839130624000.md` (quiz funnels / Spartan). Inbox drop.
4. One image: sidecar `ready/image-97c6a41954e5c590202e.md`. The sibling `ready/image-97c6a41954e5c590202e.jpg` was **absent**. JPEG copied from `/Users/lukaszmaj/dev/naturbiss/sources/external/carl-weische/x/media/1489704022818934785_thumb/1489704022818934785_thumb.jpg` and named to match the sidecar. SHA-256 matched the sidecar: `97c6a41954e5c590202e8be3d5e10272e8603ae4449cdb23e772882ae6682034`. Chat-attached capture with `--evidence-path` on that JPEG and `--body-file` the sidecar.
5. Multi-image unit: `/Users/lukaszmaj/dev/naturbiss/wiki/.source-staging/carl-weische-curated-v1.1/units/CARL-0531/source.md` plus `native-001.jpg` and `native-002.jpg` from the same directory (two images only). Chat-attached capture: evidence `native-001.jpg`, `--attachment-path native-002.jpg`, body `source.md`.

Order on both arms: 1, 2, 3, 4, 5. One source at a time; wait for archive / `.ingest-runs.jsonl` `completed` before the next.

## Per-source table

`pages touched` is new content pages (previous pages were not rewritten; line counts of older pages stayed fixed). `lines added` is `wc -l` of those new pages. Protocol-on-page means Title-scope / do-not-merge / different-object notes on the **page**, not only `log.md`.

| Source | A pages | A lines | A protocol-on-page | A summary | B pages | B lines | B protocol-on-page | B summary |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 short PDP post | `queries/high-converting-pdp-ux-checklist.md` | 62 | no (title-scope in log) | yes | `queries/high-converting-pdp-ux.md` | 46 | no (entity skip in log; `related: []`) | yes |
| 2 D2C resources | `queries/d2c-brand-scale-resources.md` | 75 | no (title-scope in log) | yes | `queries/d2c-scale-resources.md` | 49 | yes (Related: different object) | yes |
| 3 quiz article | `queries/quiz-funnel-five-part-flow.md` | 74 | no (title-scope in log) | yes | `queries/quiz-funnels.md` | 54 | yes (Related: different object) | yes |
| 4 Shopify image | `queries/shopify-kabellosladen-order-notification.md` | 75 | no (title-scope in log) | yes | `queries/kabellosladen-shopify-order-notification.md` | 67 | yes (Related: different object) | yes |
| 5 Gymshark unit | `queries/gymshark-cro-teardown-carl-0531.md` | 80 | yes (overlap + "augment this page rather than duplicating") | yes | `queries/gymshark-cro-teardown-carl-0531.md` | 83 | yes (Related: different object; augment-this-page) | yes |

Sibling fanout: **1 page per source** on both arms. Entity pages: **0**. Concept pages: **0**. `concepts/_index.md`: not created on either wiki.

### Totals

| | A | B |
| --- | --- | --- |
| Content pages | 5 | 5 |
| Entity pages | 0 | 0 |
| Content lines (`wc -l`, excluding `_index.md`) | 366 | 299 |
| Provider runs completed / failed | 5 / 0 | 5 / 0 |
| Protocol notes location | almost all in `log.md` as title-scope | `log.md` as "Did not augment: different knowledge object"; Related lists on pages 2-5 |
| Summary frontmatter | 5/5 | 5/5 |

A source 1 omitted `related:` frontmatter. B source 1 has `related: []`. Both wikis used `summary` on every page (A already required it at `ba42f52`).

## Index one-liners

Neither wiki created `concepts/_index.md`. Queries indexes (plugin `wiki-build-index.py`, summary-based):

**A `queries/_index.md`**

- Carl Weische three D2C scale resources (X, 2023) — Carl Weische posted the same three D2C scale resources (Skool, Accelerated Agency, YouTube) across 11 X events Apr-Sep 2023; source evidence, not a verified Naturbiss fact.
- Gymshark CRO teardown (Carl Weische CARL-0531, 2022-07-12) — Carl Weische thread 1546857415542439938 mockups a 6-idea Gymshark CRO teardown; native before/afters for header and menu only; source evidence, not a verified Naturbiss fact.
- High-converting PDP UX checklist (Carl Weische, 2022-06-12) — Carl Weische X post 1536048997013544961 lists four above-the-fold PDP conversion rules; source evidence, not a verified Naturbiss fact.
- Quiz funnel five-part flow (Carl Weische, Spartan case, 2026-02-24) — Carl Weische X article 2025213839130624000 claims a five-part quiz funnel (Spartan hair-care case); source evidence, not a verified Naturbiss fact.
- Shopify KabellosLaden order notification (Carl Weische X image, 2022-02-04) — Lock-screen screenshot of a Shopify push for KabellosLaden: 1 item totaling €30,00 from Online Store; Carl Weische X image, source evidence not a verified Naturbiss fact.

**B `queries/_index.md`**

- D2C scale resources (Carl Weische 2023) — This wiki's Carl Weische X group 1673327854153527296 lists three D2C scale resources (Skool, Accelerated Agency, YouTube); same text in 11 events; not verified Naturbiss facts.
- Gymshark CRO teardown (Carl Weische CARL-0531, 2022-07-12) — This wiki's Carl Weische unit CARL-0531 is a six-idea Gymshark CRO mockup teardown; native before/afters cover header and menu only; not verified Naturbiss facts.
- High-converting PDP UX (Carl Weische 2022-06-12) — This wiki's Carl Weische X post 1536048997013544961 lists four above-the-fold PDP conversion practices; claims are source text, not verified Naturbiss facts.
- KabellosLaden Shopify lock-screen order notification — This wiki's Carl Weische X image shows an iOS lock-screen Shopify banner: KabellosLaden new order, 1 item, €30,00, from Online Store.
- Quiz funnel playbook (Carl Weische 2026-02-24) — This wiki's Carl Weische X article 2025213839130624000 is a five-section quiz-funnel plus sales-page playbook using Spartan; claims are source text, not verified Naturbiss facts.

## Claims check (no invented scores)

Source claims that appear on both arms, grounded in the fixtures:

- PDP post: four ATF rules (important info ATF; USPs on imagery and underneath; reviews; CTA ATF). Named image evidence files noted as **not in this drop**.
- D2C post: Skool `ecom-messiah`, Accelerated Agency, YouTube `@carlweische`; 11 events Apr-Sep 2023; peak views on `1691132696544661507`.
- Quiz article: "lead forms with extra steps" vs automated consulting session; Spartan $10M/month men's hair care; five-part flow; May 2026 / six-month AOV frame; checkout tactics (limited inventory, 10-minute card reserve, doubled guarantee). Cover image not in drop.
- Image 4 visual facts in pixels: iOS lock screen, time `19:40`, `Sunday, 2. August`, `Notification Centre`, Shopify card `KabellosLaden has a new order for 1 item totaling €30,00 from Online Store.`, `99 more notifications`, wallpaper fragment `CREATE`, flashlight and camera shortcuts. Both arms recorded these. B additionally rejected Tesseract tokens (`thago`, `Wither ti he`) as non-claims.
- Gymshark natives: ACCELERATED before/after chrome; after-state announcement bar `Free Standard Shipping when you spend $75`; labeled Menu/Search/Wishlist/Cart; `GYMSHARK X WHITNEY SIMMONS` hero; after-menu `NEW RELEASES` terracotta tile plus TRENDING thumbnails. Ideas 3-6 named from thread text with natives 003-006 **not shown**. 3-8% CVR treated as author claim / mockups.

No unsourced Naturbiss implementation claims caught on either arm.

## Probe: What does Carl say about PDP above-the-fold CTAs?

Answered from each wiki only.

**A.** Keep a CTA above the fold as item 4 of the 2022 PDP checklist (`queries/high-converting-pdp-ux-checklist.md`: "4. Keep a CTA above the fold."). The Gymshark teardown repeats it as idea 4: "Put important information and the CTA above the fold on the PDP to raise add-to-cart" (`queries/gymshark-cro-teardown-carl-0531.md`), and notes the PDP mockup (`native-004.jpg`) was not in this drop.

**B.** Same two objects, not merged. Checklist page: "4. Keep the CTA above the fold." (`queries/high-converting-pdp-ux.md`). Gymshark page idea 4 quotes the same ATF CTA rule, links the checklist as a **different object**, and records that the native PDP mockup was not delivered (`queries/gymshark-cro-teardown-carl-0531.md` Related: "Idea #4 in this thread overlaps that checklist; the native PDP mockup was not in this drop.").

## Provider run IDs

All `provider=grok`, `model=grok-4.6`, `profile=grok_medium`, `attempt=1`, `exit_code=0`, `status=completed`.

**A `/tmp/karpathy-wiki-ab/wiki-A/.ingest-runs.jsonl`**

| Source | run_id | capture |
| --- | --- | --- |
| 1 | `in-1787499431200882-30585-1` | `drift-28c9346d096b-post-1536048997013544961-md.md` |
| 2 | `in-1787500008594126-38436-1` | `drift-c25100057814-post-1673327854153527296-md.md` |
| 3 | `in-1787500479098529-45923-1` | `drift-4c96e0082330-article-2025213839130624000-md.md` |
| 4 | `in-1787500975845177-53465-1` | `2026-08-23T16-02-54Z-shopify-kabellosladen-order-notification.md` |
| 5 | `in-1787501704545713-62061-1` | `2026-08-23T16-15-02Z-gymshark-cro-teardown-carl-0531.md` |

**B `/tmp/karpathy-wiki-ab/wiki-B/.ingest-runs.jsonl`**

| Source | run_id | capture |
| --- | --- | --- |
| 1 | `in-1787499668731196-34817-1` | `drift-de30e9c0236f-post-1536048997013544961-md.md` |
| 2 | `in-1787500240063749-42642-1` | `drift-afe86b91c282-post-1673327854153527296-md.md` |
| 3 | `in-1787500714661024-49115-1` | `drift-0a5acafbd782-article-2025213839130624000-md.md` |
| 4 | `in-1787501228286285-56829-1` | `2026-08-23T16-07-06Z-shopify-kabellosladen-order-notification.md` |
| 5 | `in-1787502018588989-66610-1` | `2026-08-23T16-20-16Z-gymshark-cro-teardown-carl-0531.md` |

## Verdict: B better

Same split outcome (one query page per source, no entity encyclopedia, no source-count split of a single object) on both arms. B is better on the density contract that `03dc820` actually changed.

Evidence quotes:

- B log, source 2: "Did not augment: different knowledge object (PDP ATF checklist vs this resource list). Did not create entities for Carl Weische, Accelerated Agency, Skool, or YouTube"
- B `queries/d2c-scale-resources.md` Related: "different object (PDP ATF checklist, not this resource list)"
- B page-conventions body (new): protocol choices belong in `log.md`; pages carry a short related list. B followed that. A put title-scope in `log.md` (old skill) and did not put "do not merge" on pages 1-4.
- Line density: B 299 content lines vs A 366 for the same five objects. A pages carry more heading/lookup scaffolding; B uses synthesis / evidence / limitations / related.
- B image 4: "The capture's Tesseract OCR (`tesseract 5.5.2`) misreads several painted strings (`thago` for `1h ago`; `Wither ti he` for the `CREATE` wallpaper). Those OCR tokens are not claims."
- A schema still says "Split a concept page: 2+ sources or 200+ lines"; B schema says split when a page holds two knowledge objects. Neither arm split a page that still had one object.

A was not worse on claim coverage or visual grounding. A's Gymshark pixel inventory is also complete for natives 001/002. The contract delta (object split, related list, protocol in log, no missed-cross-link 7.5) is visible on B and is the reason for **B better** rather than mixed.

Missed-cross-link 7.5 on A added See-also on new pages; it did not rewrite older pages (PDP checklist stayed 62 lines after later ingest). B related-linked "from the new page only" by design.

## Failures

None. All ten provider runs completed with exit 0.

Operational notes (not run failures):

- Inbox scanner defers files with mtime within 5 seconds; first A source 1 `ingest-now` created no capture until a second tick after 6s.
- Source 4 JPEG was missing from `ready/`; archive copy used after SHA-256 match.
- New-tag schema-proposals were written on both wikis (expected ingest lint). Not index-split proposals.
- Local auto-commit git repos were created **inside** the temp wikis only.

Do not resume Naturbiss. Temp trees: `/tmp/karpathy-wiki-ab/wiki-A`, `/tmp/karpathy-wiki-ab/wiki-B`, `/tmp/karpathy-wiki-ab/tree-A`, `/tmp/karpathy-wiki-ab/fixtures`, `/tmp/karpathy-wiki-ab/config-home`.
