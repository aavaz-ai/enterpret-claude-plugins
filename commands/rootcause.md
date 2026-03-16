---
description: "Root cause analysis — structured investigation of a customer issue. Severity assessment, blast radius, contributing factors, timeline, and evidence chain."
argument-hint: "[issue description or bug report]"
---

# /rootcause

You are conducting a **structured root cause analysis** of a specific customer issue. This command investigates a problem in depth: what is happening, how bad it is, what else it touches, and what the likely causes are — backed by evidence from the Wisdom Knowledge Graph.

## Pre-Flight

1. Check if `context/organization.json` exists. If not: "Run `/start` first to connect to your organization's Knowledge Graph."
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
3. If it fails with an auth error, load the `onboarding` skill and stop.
4. If successful, read `context/organization.json` for org name, slug, and citation base URL.
5. Read `.claude/enterpret-customer-insights.local.md` if it exists for user preferences.

## Skills (reference during execution, not upfront)

- `wisdom-kg` — read if you need schema details or a query fails
- `evidence-synthesis` — read when synthesizing quotes and writing the narrative

## Phase 1: Parse Input

Determine what to investigate based on the user's input:

| Input | Behavior |
|-------|----------|
| `/rootcause login fails on mobile after update` | Direct investigation — use the description as-is |
| `/rootcause [pasted Jira/ticket text]` | Extract symptoms and key terms from the pasted text |
| `/rootcause` (no arguments) | Ask: "What issue should I investigate? Describe the problem, paste a bug report, or name a theme." |

**Default time window:** 14 days. After parsing, optionally ask: "What triggered this investigation? (e.g., escalation, spike, customer complaint)" — the trigger helps frame the analysis.

## Phase 2: Identify Themes

Use `search_knowledge_graph` to map the user's description to KG taxonomy. Search with 2-3 keyword variations:

1. The user's exact phrasing (e.g., "login fails on mobile")
2. Broader synonym (e.g., "authentication error")
3. More specific variant (e.g., "mobile app login")

Collect matching theme names. Use the EXACT names returned by search in all subsequent Cypher queries — never guess taxonomy labels.

If no themes match, tell the user and suggest `/explore` to browse the taxonomy.

## Phase 3: Multi-Query Investigation

Run 8 queries to build a complete picture. Compute `{START_DATE}` as 14 days ago and `{END_DATE}` as today, both in ISO format.

### Query 1: Volume and Trend

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

### Query 2: Sentiment Distribution

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)-[:HAS_SENTIMENT]->(sp:SentimentPrediction),
      (fi)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN sp.label AS sentiment, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

### Query 3: Subtheme Clustering

Identifies specific symptoms and causes within the issue.

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction),
      (cft)-[:HAS_SUBTHEME]->(st:Subtheme)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN st.name AS subtheme, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 15
```

### Query 4: Cascade Impact / Co-occurring Themes

Find what other themes appear alongside the target theme on the same feedback records. This reveals blast radius and downstream effects.

**IMPORTANT:** Use a single MATCH with two paths — never MATCH after WITH.

```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft1:CustomerFeedbackTags)-[:HAS_THEME]->(t1:Theme),
      (fi)-[:HAS_TAGS]->(cft2:CustomerFeedbackTags)-[:HAS_THEME]->(t2:Theme)
WHERE t1.name CONTAINS "{THEME_NAME}" AND NOT t2.name CONTAINS "{THEME_NAME}"
RETURN t2.name AS co_occurring_theme, COUNT(DISTINCT fi.feedback_record_id) AS shared_volume
ORDER BY shared_volume DESC
LIMIT 10
```

### Query 5: Week-over-Week Trend

**IMPORTANT:** Always two separate queries. Never attempt WoW in a single query.

**Current week** (last 7 days):
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{CURRENT_WEEK_START}" AND nli.record_timestamp < "{END_DATE}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS current_volume
ORDER BY current_volume DESC
LIMIT 5
```

**Previous week** (7-14 days ago):
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{PREV_WEEK_START}" AND nli.record_timestamp < "{CURRENT_WEEK_START}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS previous_volume
ORDER BY previous_volume DESC
LIMIT 5
```

Compute: `trend = (current_volume - previous_volume) / previous_volume`. Handle edge cases: prior = 0 and current > 0 = "NEW"; < 5% change = "flat".

### Query 6: Account Breadth

**Before running this query, call `get_schema` to check for account-related nodes and relationships.** Account metadata is schema-dependent — not all KGs have it.

If account nodes exist (e.g., `DerivedAccount` with `HAS_ACCOUNT` relationship):
```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN da.name AS account, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

**Graceful fallback:** If no account nodes/relationships exist in the schema, skip this query and note: "Account-level segmentation not available for this organization. Volume counts represent all feedback."

### Query 7: Insight Types Breakdown

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN fi.summary_type AS insight_type, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

### Query 8: Verbatim Evidence

Retrieve 20 records to select 3-5 diverse quotes per subtheme.

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name CONTAINS "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN nli.content AS verbatim, fi.feedback_record_id AS record_id, nli.record_timestamp AS date, fi.summary_type AS insight_type
ORDER BY nli.record_timestamp DESC
LIMIT 20
```

From the 20 results, select 3-5 quotes following evidence-synthesis rules:
- **Different subthemes** — don't cluster quotes on one symptom
- **Different time periods** — show persistence, not a single spike
- **Different severity angles** — include both frustration and business impact
- Prefer quotes with specific detail over generic complaints

## Phase 4: Analyze

### Root Cause Clustering

Group the verbatim quotes by symptom pattern. For each cluster:
1. Assign a descriptive label (e.g., "Session timeout after app update", "Payment form reset on back-navigation")
2. Mark each as **HYPOTHESIS** — root causes are inferred, not proven
3. Note the supporting evidence count and subtheme alignment

### Severity Assessment

Classify the issue using the evidence gathered:

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0 — Critical** | >20 accounts affected + >50% negative sentiment + accelerating WoW trend | Escalate immediately |
| **P1 — High** | 5-20 accounts affected OR >30% negative sentiment OR worsening WoW trend | Prioritize this sprint |
| **P2 — Monitor** | <5 accounts affected, stable or declining trend | Track, don't escalate |

If account data is unavailable, assess severity on volume + sentiment + trend only and note the gap.

## Phase 5: Present Output

---

## Root Cause Analysis: {Issue Description}

**Window:** {START_DATE} to {END_DATE} (14 days) | **Volume:** {total_volume} items | **Severity:** {P0/P1/P2 badge}

---

### Executive Summary

- {3-5 bullet points: what is happening, how bad it is, who is affected, what's driving it, what to do next}

---

### Scope & Scale

| Metric | Value |
|--------|-------|
| Total feedback (14d) | {volume} items |
| Negative sentiment | {X%} ({negative_count} of {total}) |
| WoW trend | {direction} {X%} (this week: {current}, last week: {previous}) |
| Accounts affected | {count or "Data not available"} |
| Insight type breakdown | {X% complaint, Y% question, Z% improvement} |

---

### Subtheme Breakdown

| Subtheme | Volume | % of Total | Most Recent | Assessment |
|----------|--------|-----------|-------------|------------|
| {subtheme_1} | {volume} | {pct} | {YYYY-MM-DD} | {symptom or cause label} |
| {subtheme_2} | {volume} | {pct} | {YYYY-MM-DD} | {symptom or cause label} |
| ... | ... | ... | ... | ... |

---

### Cascade Impact

Themes that co-occur with this issue on the same feedback records — reveals blast radius and downstream effects.

| Co-occurring Theme | Shared Volume | Relationship |
|-------------------|---------------|--------------|
| {theme_1} | {volume} | {e.g., "likely downstream effect", "shared root cause", "user journey overlap"} |
| {theme_2} | {volume} | {relationship} |
| ... | ... | ... |

---

### Root Cause Hypotheses

For each cluster, present the hypothesis with supporting evidence:

**HYPOTHESIS 1: {Descriptive label}**
Confidence: {High/Medium/Low} | Supporting evidence: {N} items | Subthemes: {list}

{2-3 sentence interpretation of what this cluster reveals.}

> "{Quote 1 — specific, detailed, illustrative}"
> — {YYYY-MM-DD} | [View in Enterpret]({citationBaseUrl}{record_id})

> "{Quote 2 — different angle or subtheme}"
> — {YYYY-MM-DD} | [View in Enterpret]({citationBaseUrl}{record_id})

**HYPOTHESIS 2: {Descriptive label}**
...

---

### What We DON'T Know

- {Specific limitation 1 — e.g., "No account-level data available; cannot assess enterprise concentration."}
- {Specific limitation 2 — e.g., "All evidence comes from support tickets — users who churned silently are not represented."}
- {Specific limitation 3 — e.g., "Correlation between {theme_A} and {theme_B} does not confirm causation."}
- {Sample size caveat if N < 50}
- {Channel bias caveat}

---

### Recommendations

1. **{Action 1}** — {Why, based on which evidence cluster}
2. **{Action 2}** — {Why, based on which evidence cluster}
3. **{Action 3}** — {Why, based on which evidence cluster}

---

**Data scope:** {N} items from {sources} over {date range}. Themes matched via Enterpret Adaptive Taxonomy.

---

For a broader view of this area, try `/analyze {related topic}`. For a shareable summary, try `/brief`.
