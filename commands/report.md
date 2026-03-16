---
description: "Generate a report — weekly memo, account brief, executive summary, or branded document. Auto-detects mode from input or presents archetype menu."
argument-hint: "[weekly | account name | exec | theme deep-dive | sentiment | custom]"
---

# /report

You are generating a **customer intelligence report**. This command auto-detects what kind of report to produce based on the input. Quick modes output directly in chat (with optional doc export); document modes follow a guided archetype workflow for branded output.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, tell the user: "Run `/start` first to connect to your organization's Knowledge Graph." Stop.
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
3. If it fails with an auth error, tell the user to run `/start` and stop.
4. If successful, read `context/organization.json` for org name, slug, and citation base URL.

## Skills (reference during execution, not upfront)

- User context is loaded from `.local.md` in Pre-Flight; defaults are in the `wisdom-kg` skill
- `wisdom-kg` — read if you need schema details or a query fails
- `report-engine` — read if user requests formatted document output
- `evidence-synthesis` — read when synthesizing quotes and writing the narrative

## Query Rules (critical)

- Always use `LIMIT` (max 50)
- Count with `COUNT(DISTINCT fi.feedback_record_id)` — never `COUNT(nli)`
- Never use `count` as an alias (reserved word) — use `volume`
- Sentiment values are capitalized: `"Positive"`, `"Negative"`, `"Neutral"`
- Dates use string comparison on `record_timestamp`: `>= "2026-02-27"` (not `date()`)
- Parameter name for `execute_cypher_query` is `cypher_query`
- Never use MATCH after WITH — use a single MATCH with multiple paths
- If no results, say so — never fabricate data

## Phase 0: Mode Detection

Parse the user's command and detect mode:

### Quick Modes (chat output first, offer doc export after)

- `/report` or `/report weekly` or `/report pm` → **Weekly Memo mode**
- `/report Acme Corp` or `/report canva` → **Account Brief mode**
- `/report exec` or `/report leadership` → **Executive Summary mode**
- `/report US` or `/report KR` → **Regional Digest mode**
- `/report cpo` or `/report eng` or `/report cx` → **Weekly Memo mode** with audience targeting

### Document Modes (guided archetype → branded doc)

- `/report theme deep-dive` → **Theme Deep-Dive** archetype
- `/report sentiment` → **Sentiment Trend** archetype
- `/report custom` → **Custom** archetype

### Mode Detection Logic

| Input | Mode | Rationale |
|-------|------|-----------|
| Known audience keyword (pm/cpo/eng/cx) | Weekly memo | Audience-tailored weekly scan |
| Company/account name | Account brief | Account-level analysis |
| Region code (US/KR/BR/etc.) | Regional digest | Region-filtered weekly overview |
| "exec," "leadership," "board" | Executive summary | High-level overview |
| "theme deep-dive" | Theme Deep-Dive doc | Guided archetype workflow |
| "sentiment" | Sentiment Trend doc | Guided archetype workflow |
| "custom" | Custom doc | Guided archetype workflow |
| No input or "weekly" | Unified menu | Let user choose |

If ambiguous, check if the input matches an account name first (via `search_knowledge_graph` or account metadata query), then fall back to weekly memo.

### No-Argument Menu

If no argument is provided, present:

> **What kind of report would you like?**
>
> **Quick reports** (output in chat):
> 1. **Weekly Memo** — what happened this week
> 2. **Account Brief** — one account's feedback profile
> 3. **Executive Summary** — high-level for leadership
>
> **Branded documents** (guided → docx/pptx/html):
> 4. **Theme Deep-Dive** — comprehensive category analysis
> 5. **Sentiment Trend** — period-over-period comparison
> 6. **Custom** — describe what you need
>
> Pick a number or name.

---

## Weekly Memo Mode

### The Big 5 Scan (7-day window)

**Scan 1: EMERGING — New themes this week**

Themes in last 7 days:
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE nli.record_timestamp >= "<7_days_ago>"
RETURN t.name, COUNT(DISTINCT fi.feedback_record_id) AS current_volume
ORDER BY current_volume DESC
LIMIT 25
```

Themes in prior 23 days (to identify what's NEW):
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE nli.record_timestamp >= "<30_days_ago>" AND nli.record_timestamp < "<7_days_ago>"
RETURN t.name, COUNT(DISTINCT fi.feedback_record_id) AS prior_volume
ORDER BY prior_volume DESC
LIMIT 50
```

Emerging = present in 7-day but absent or minimal (<3) in prior 23 days, with >5 reports.

**Scan 2: WORSENING — Fastest negative acceleration**

Current and prior week negative sentiment per theme (two separate queries). Flag themes where `(current - prior) / prior > 0.25` AND current_negative > 5.

**Scan 3: ENTERPRISE BLOCKER — Account concentration**

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE nli.record_timestamp >= "<7_days_ago>"
RETURN t.name, da.name, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 30
```

Enterprise blocker = single account >5 reports on a theme, OR theme with 3+ accounts in same week. Skip if no account metadata.

**Scan 4: SELF-SERVE FRICTION — Onboarding/adoption barriers**

Top volume themes this week, filtered for onboarding/setup/docs-related L1/L2 categories.

**Scan 5: DECISION OF THE WEEK — Editorial pick**

From Scans 1-4, identify the ONE signal most needing a decision. Pull a representative quote.

### Audience Tailoring

| Audience | Lead With | Tone |
|----------|----------|------|
| PM (default) | Actionable signals, specific recs | Direct, practical |
| CPO | Strategic trends, OKR alignment | High-level, strategic |
| Eng | Bug patterns, tech debt signals | Technical, specific |
| CX | Sentiment trends, escalation patterns | Customer-centric |

### Weekly Memo Output

---

### Weekly Customer Intelligence Memo

**Week of:** [Monday date] · **Audience:** [PM/CPO/Eng/CX]

---

**Decision of the Week**

**[Theme name]** — [1-2 sentences on why this needs a decision NOW]

> "[Quote that crystallizes the issue]"
> — [timestamp] · [View in Enterpret](citation_url)

**Recommended action:** [Specific action]

---

**Emerging**

| Signal | Volume (7d) | Most Recent | Assessment |
|--------|------------|-------------|------------|
| [New theme] | [N] | [YYYY-MM-DD] | [What it might mean] |

---

**Worsening**

| Signal | This Week | Last Week | Change | Action |
|--------|-----------|-----------|--------|--------|
| [Theme] | [N] neg | [N] neg | [↑ X%] | [recommendation] |

---

**Enterprise Blockers**

| Account | Theme | Volume (7d) | Status |
|---------|-------|------------|--------|
| [Account] | [Theme] | [N] | [New/Recurring/Escalating] |

---

**Self-Serve Friction**

| Area | Volume (7d) | Trend | Impact |
|------|------------|-------|--------|
| [Theme] | [N] | [direction] | [Onboarding/Activation/Retention] |

---

**This week vs last week:** Total volume [N] vs [N] ([change]) · Negative ratio [X%] vs [X%] · New themes: [N]

**Limitations:** {Sources represented (e.g., "Reddit + App Store only"). Gaps (e.g., "No support tickets, no survey data"). Sample size caveats if N < 50.}

**Data scope:** [N] items, [sources], [date range].

---

## Account Brief Mode

### Phase 2: Find Account Feedback

**Step 1: Verify account exists**
```cypher
MATCH (da:DerivedAccount)
WHERE da.name CONTAINS "<account_name>"
RETURN da.name
LIMIT 5
```

If no match: fallback to `search_knowledge_graph`. Note: "Results based on text search — may be incomplete."

**Step 2: Account's top themes (90 days)**
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE da.name = "<account_name>"
AND nli.record_timestamp >= "<90_days_ago>"
RETURN t.name, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 15
```

**Step 3: Account sentiment**
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)-[:HAS_SENTIMENT]->(sp:SentimentPrediction),
      (fi)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE da.name = "<account_name>"
AND nli.record_timestamp >= "<90_days_ago>"
RETURN t.name, sp.label, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 30
```

**Step 4: Market comparison** — for each top 5 theme, check market-wide volume and how many other accounts report it.

**Step 5: Account quotes**
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE da.name = "<account_name>"
AND nli.record_timestamp >= "<90_days_ago>"
RETURN nli.content AS verbatim, t.name, fi.feedback_record_id, nli.record_timestamp
ORDER BY nli.record_timestamp DESC
LIMIT 15
```

### Scalability Assessment

| Classification | Criteria | Implication |
|---------------|----------|-------------|
| **Scalable product gap** | 3+ other accounts, growing | Build — canary signal |
| **Segment-specific** | Same segment reports, not broadly | Build if strategic segment |
| **Account-specific** | Only this account | Accommodate, don't build |
| **Already addressed** | Declining market volume | Communicate |

### Account Brief Output

---

### Account Brief: [Account Name]

**Data window:** 90 days · **Total feedback:** [N] items

---

**Account Health Summary**

| Metric | Value |
|--------|-------|
| Total feedback (90d) | [N] items |
| Negative sentiment | [X%] |
| Top concern | [Theme] |
| Trend | [Improving/Stable/Worsening] |

---

**Top Themes — Scalability Assessment**

| Theme | Account Vol | Market Vol | Other Accounts | WoW Trend | Most Recent | Classification | Recommendation |
|-------|------------|------------|----------------|-----------|-------------|----------------|----------------|
| [Theme] | [N] | [N] | [N] | [↑/↓/flat] | [YYYY-MM-DD] | Scalable gap | Build |

---

**What this account is saying:**

> "{Verbatim quote — customer's actual words}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{Second quote — different theme or angle}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{Third quote — shows impact or urgency}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

**Scalable gaps (build for the market):**
- [Theme] — [N] other accounts, [trend]

**Account-specific requests (accommodate, don't build):**
- [Theme] — [context]

**Recommendation for account team:**
1. [Action]
2. [What to communicate]
3. [What NOT to promise]

**Limitations:** {channel bias, sample size caveats, account data completeness}

**Data scope:** [N] items, [date range]. Market comparison: [M] total items across [K] accounts.

---

## Regional Digest Mode

Follow the weekly memo scan flow but add a COR filter to all queries:
```cypher
AND nli.uf_cor_9a00Yg__list = "{REGION_CODE}"
```

**Note:** The COR (Country/Region) property name `uf_cor_9a00Yg__list` is organization-specific. If this property doesn't exist in the current org's schema, call `get_schema` to find the correct COR/region property. Common alternatives include other `uf_` prefixed properties. If no region property exists, inform the user: "Regional filtering is not available for this organization."

Present as a regional weekly digest with the same Big 5 structure.

---

## Executive Summary Mode

Run a simplified scan: top 5 themes by volume, overall sentiment, WoW change, emergency detection. Present in 4 concise sections: Key Metrics, Top Themes, Highlights & Risks, Recommended Actions.

---

## Theme Deep-Dive Mode

### Phase 1: Scope

1. "Which category or topic should we deep-dive into?" (Show L1 categories from context if helpful)
2. "What date range?" (Default: last 14 days)
3. "Any region filter?" (Default: all)
4. "Who's the audience?" (Default: product team)

Confirm scope before proceeding.

### Phase 2: Query

1. L1 → L2 taxonomy drill-down for the target category
2. Sentiment for each L2 subcategory
3. WoW trend per theme (4 weeks if possible, else 2) + most recent date per theme
4. Subtheme breakdown for top 3 themes
5. Verbatim quotes (nli.content) for top 5 themes — 3+ quotes each with dates and [View in Enterpret] links
6. Co-occurring themes from other categories
7. Account breadth (if available in schema)

### Phase 3: Draft

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

Wait for user approval or adjustments, then proceed to Document Generation.

---

## Sentiment Trend Mode

### Phase 1: Scope

1. "What two periods should I compare?" (Default: this week vs last week)
2. "Any region filter?" (Default: all)
3. "Focus on negative sentiment or the full spectrum?" (Default: full)
4. "Who's the audience?" (Default: leadership)

Confirm scope before proceeding.

### Phase 2: Query

1. Sentiment distribution for Period 1
2. Sentiment distribution for Period 2
3. Top themes for each period with WoW trend
4. Quotes (nli.content) for top improving and deteriorating themes — 3+ each with dates

### Phase 3: Draft

Present the draft in chat following the archetype's structure from `report-engine/references/report-templates.md`.

Apply the same output rules as Theme Deep-Dive (see above).

Say: "Here's the draft. Want me to adjust anything before I generate the final report?"

Wait for user approval or adjustments, then proceed to Document Generation.

---

## Custom Mode

### Phase 1: Scope

1. "Describe what you want to analyze or present."
2. Based on the description, propose a report structure: title, sections with descriptions, suggested charts
3. Present: "Here's the structure I'd propose: [structure]. Want to adjust anything?"
4. Wait for confirmation before proceeding

### Phase 2: Query

Determine which patterns to run based on the confirmed structure. Execute relevant queries.

### Phase 3: Draft

Present the draft in chat. Apply the same output rules as Theme Deep-Dive (see above).

Say: "Here's the draft. Want me to adjust anything before I generate the final report?"

Wait for user approval or adjustments, then proceed to Document Generation.

---

## Document Generation (all modes)

After presenting any mode's output in chat, offer:

> "Want me to generate this as a branded report? (docx / pptx / html)"

If yes:

**Step 1 — Choose Format:**

Ask: "What format would you like? (docx / pptx / html / all)" Default: docx

**Step 2 — Generate Charts** (see `report-engine/references/chart-patterns.md`):

Generate appropriate charts based on mode:
- Theme Deep-Dive: horizontal bar (L2s), stacked bar (sentiment), line trend
- Sentiment Trend: grouped bar (comparison), horizontal bar (drivers)
- Executive Summary: horizontal bar (top 5), donut (sentiment)
- Weekly Memo: horizontal bar (top themes), stacked bar (sentiment WoW)
- Account Brief: horizontal bar (themes), donut (sentiment)
- Custom: charts based on confirmed structure

Each `generateChart()` call returns a PNG buffer or `null` on failure. Charts never block report generation.

**Step 3 — Build Document:**

1. Load brand tokens: check for `brand/custom.json` first, fall back to `brand/enterpret.json`
2. Resolve `{ORG_NAME}` and `{ORG_SLUG}` template vars from `context/organization.json`
3. Generate output in chosen format(s) using the report-engine skill
4. Embed charts above their respective tables — if chart buffer is `null`, skip silently
5. Include header, footer with branding, page numbers
6. All citation links must be clickable hyperlinks
7. Save with appropriate filename (see below)
8. Present link and brief summary

### Output File Naming

Quick modes:
- Weekly memo: `weekly_memo_{audience}_{YYYY-MM-DD}.{ext}`
- Account brief: `account_brief_{account_slug}_{YYYY-MM-DD}.{ext}`
- Regional digest: `digest_{region}_{YYYY-MM-DD}.{ext}`
- Executive summary: `exec_summary_{YYYY-MM-DD}.{ext}`

Document modes:
- Theme Deep-Dive / Sentiment Trend / Custom: `{archetype_slug}_{topic_slug}_{YYYY-MM-DD}.{ext}`

---

## Edge Cases

**Quiet week (weekly memo):**
Positive finding: "Quiet week — no emerging themes, no sentiment shifts, no blockers. Product is in steady state."

**Account not in metadata:**
Use text search fallback. Note incompleteness.

**Account has <10 items:**
"Only [N] items. Insufficient for reliable analysis."

**Everything is on fire (5+ signals):**
Prioritize top 3. Add "Also worth noting" for the rest.

**No data for requested period:**
Say so clearly. Suggest broadening the date range.

**Region property not found:**
Call `get_schema` to find correct property. If none exists: "Regional filtering is not available for this organization."
