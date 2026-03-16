---
description: "Guided report builder — choose from archetypes (Theme Deep-Dive, Sentiment Trend, Executive Summary) or build a custom report with branded output."
argument-hint: "[archetype name]"
---

# /report

You are launching the **guided report builder** — a flexible tool for creating formatted, branded analyses using report archetypes or a fully custom structure.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, load the `onboarding` skill to run auto-discovery first.
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
3. If it fails with an auth error, load the `onboarding` skill and stop.
4. If successful, read `context/organization.json` for org name, slug, and citation base URL.

## Skills (reference during execution, not upfront)

- `user-context` — read if you need audience framing and persona
- `wisdom-kg` — read if you need schema details or a query fails
- `report-engine` — read for the 4-phase workflow, archetypes, and output generation

## Query Rules (critical)

- Always use `LIMIT` (max 50)
- Count with `COUNT(DISTINCT fi.feedback_record_id)` — never `COUNT(nli)`
- Never use `count` as an alias (reserved word) — use `volume`
- Sentiment values are capitalized: `"Positive"`, `"Negative"`, `"Neutral"`
- Dates use string comparison on `record_timestamp`: `>= "2026-02-27"` (not `date()`)
- Parameter name for `execute_cypher_query` is `cypher_query`
- Never use MATCH after WITH — use a single MATCH with multiple paths
- If no results, say so — never fabricate data

## Phase 0: Archetype Selection

If the user provided an archetype in the command:
- `/report theme deep-dive` → skip to Phase 1 with Theme Deep-Dive
- `/report sentiment` → skip to Phase 1 with Sentiment Trend
- `/report exec summary` → skip to Phase 1 with Executive Summary
- `/report custom` → skip to Phase 1 with Custom

If no archetype specified, present the menu:

> **What kind of report would you like to build?**
>
> 1. **Theme Deep-Dive** — Comprehensive analysis of a specific category or topic. Taxonomy breakdown, sentiment, trends, evidence. Best for: understanding a specific area in depth.
>
> 2. **Sentiment Trend** — Period-over-period comparison. What's improving, what's getting worse, and why. Best for: tracking changes over time.
>
> 3. **Executive Summary** — High-level overview for leadership. Concise, metric-heavy, action-oriented. Best for: stakeholder presentations and quick updates.
>
> 4. **Custom** — Describe what you want, and I'll propose a report structure. Best for: anything that doesn't fit the above archetypes.
>
> Pick a number or name.

## Phase 1: Scope

Based on the selected archetype, ask scoping questions:

### Theme Deep-Dive
1. "Which category or topic should we deep-dive into?" (Show L1 categories from context if helpful)
2. "What date range?" (Default: last 14 days)
3. "Any region filter?" (Default: all)
4. "Who's the audience?" (Default: product team)

### Sentiment Trend
1. "What two periods should I compare?" (Default: this week vs last week)
2. "Any region filter?" (Default: all)
3. "Focus on negative sentiment or the full spectrum?" (Default: full)
4. "Who's the audience?" (Default: leadership)

### Executive Summary
1. "What date range?" (Default: last 7 days)
2. "Any region filter?" (Default: all)
3. "Any specific focus areas, or a full overview?" (Default: full)

### Custom
1. "Describe what you want to analyze or present."
2. Based on the description, propose a report structure: title, sections with descriptions, suggested charts
3. Present: "Here's the structure I'd propose: [structure]. Want to adjust anything?"
4. Wait for confirmation before proceeding

Confirm scope before Phase 2.

## Phase 2: Query

Execute queries based on the archetype's requirements:

### Theme Deep-Dive
1. L1 → L2 taxonomy drill-down for the target category
2. Sentiment for each L2 subcategory
3. WoW trend per theme (4 weeks if possible, else 2) + most recent date per theme
4. Subtheme breakdown for top 3 themes
5. Verbatim quotes (nli.content) for top 5 themes — 3+ quotes each with dates and [View in Enterpret] links
6. Co-occurring themes from other categories
7. Account breadth (if available in schema)

### Sentiment Trend
1. Sentiment distribution for Period 1
2. Sentiment distribution for Period 2
3. Top themes for each period with WoW trend
4. Quotes (nli.content) for top improving and deteriorating themes — 3+ each with dates

### Executive Summary
1. Top 5 themes by volume with WoW trend and most recent date
2. Overall sentiment split
3. Volume and sentiment WoW change
4. Quick negative spike scan

### Custom
- Determine which patterns to run based on the confirmed structure
- Execute relevant queries

## Phase 3: Draft

Present the draft in chat following the archetype's structure from `report-engine/references/report-templates.md`.

**Output rules (non-negotiable):**
- Every theme table MUST include a WoW trend column and Most Recent date column
- Every quote MUST show the YYYY-MM-DD date and link as `[View in Enterpret]({url})`
- Never use "View record" or "View" — always "View in Enterpret"
- Quotes must be customer verbatims (nli.content), NOT AI summaries (fi.content)
- 3+ quotes minimum per top-5 theme
- MUST include a Limitations section — sample size, channel bias, account breadth gaps
- Top 3 themes should include subtheme decomposition

Say: "Here's the draft. Want me to adjust anything before I generate the final report?"

Wait for user approval or adjustments.

## Phase 4: Final

After user approval:

**Step 4a — Choose Format:**

Ask: "What format would you like? (docx / pptx / html / all)" Default: docx

**Step 4b — Generate Charts** (see `report-engine/references/chart-patterns.md`):

Generate appropriate charts based on archetype:
- Theme Deep-Dive: horizontal bar (L2s), stacked bar (sentiment), line trend
- Sentiment Trend: grouped bar (comparison), horizontal bar (drivers)
- Executive Summary: horizontal bar (top 5), donut (sentiment)
- Custom: charts based on confirmed structure

Each `generateChart()` call returns a PNG buffer or `null` on failure. Charts never block report generation.

**Step 4c — Build Document:**

1. Load brand tokens: check for `brand/custom.json` first, fall back to `brand/enterpret.json`
2. Resolve `{ORG_NAME}` and `{ORG_SLUG}` template vars from `context/organization.json`
3. Generate output in chosen format(s) using the report-engine skill
4. Embed charts above their respective tables — if chart buffer is `null`, skip silently
5. Include header, footer with branding, page numbers
6. All citation links must be clickable hyperlinks
7. Save as: `{archetype_slug}_{topic_slug}_{YYYY-MM-DD}.{ext}`
8. Present link and brief summary
