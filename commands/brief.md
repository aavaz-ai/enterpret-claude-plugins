---
description: "Ready-to-share summary — account brief, weekly memo, or exec overview. Auto-detects: account name → account brief; audience keyword → tailored memo."
argument-hint: "[account name, audience (pm/cpo/eng/cx), or topic]"
---

# /brief

You are generating a **ready-to-share intelligence brief**. This command auto-detects what kind of brief to produce based on the input. It merges three patterns: account briefs, weekly memos, and customer digests.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, load the `onboarding` skill to run auto-discovery first.
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
3. If it fails with an auth error, load the `onboarding` skill and stop.
4. If successful, read `context/organization.json` for org name, slug, and citation base URL.

## Skills (reference during execution, not upfront)

- `user-context` — read if you need audience framing and persona
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

## Phase 1: Parse Input & Detect Mode

Parse the user's command:
- `/brief Acme Corp` or `/brief canva` → **Account brief mode**
- `/brief` or `/brief pm` or `/brief weekly` → **Weekly memo mode** (default)
- `/brief cpo` or `/brief eng` or `/brief cx` → **Weekly memo mode** with audience targeting
- `/brief US` or `/brief KR` → **Regional digest mode**
- `/brief leadership` or `/brief exec` → **Executive summary mode**

### Mode Detection Logic

| Input | Mode | Rationale |
|-------|------|-----------|
| Known audience keyword (pm/cpo/eng/cx) | Weekly memo | Audience-tailored weekly scan |
| Company/account name | Account brief | Account-level analysis |
| Region code (US/KR/BR/etc.) | Regional digest | Region-filtered weekly overview |
| "exec," "leadership," "board" | Executive summary | High-level overview |
| No input or "weekly" | Weekly memo (pm) | Default Monday morning brief |

If ambiguous, check if the input matches an account name first (via `search_knowledge_graph` or account metadata query), then fall back to weekly memo.

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

Present as a regional weekly digest with the same Big 5 structure.

## Executive Summary Mode

Run a simplified scan: top 5 themes by volume, overall sentiment, WoW change, emergency detection. Present in 4 concise sections: Key Metrics, Top Themes, Highlights & Risks, Recommended Actions.

## Phase 3: Report Generation (Optional)

After presenting the brief in chat, offer: "Want me to generate this as a report? (docx / pptx / html)"

If yes, follow the report-engine 4-phase workflow for format selection, chart generation, and branded document output.

**Output file naming:**
- Weekly memo: `weekly_memo_{audience}_{YYYY-MM-DD}.{ext}`
- Account brief: `account_brief_{account_slug}_{YYYY-MM-DD}.{ext}`
- Regional digest: `digest_{region}_{YYYY-MM-DD}.{ext}`

## Edge Cases

**Quiet week (weekly memo):**
Positive finding: "Quiet week — no emerging themes, no sentiment shifts, no blockers. Product is in steady state."

**Account not in metadata:**
Use text search fallback. Note incompleteness.

**Account has <10 items:**
"Only [N] items. Insufficient for reliable analysis."

**Everything is on fire (5+ signals):**
Prioritize top 3. Add "Also worth noting" for the rest.
