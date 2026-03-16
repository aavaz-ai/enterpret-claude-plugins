---
description: "Deep analysis — multi-query synthesis of a topic. Volume trends, sentiment, theme breakdown, top accounts, verbatim evidence, and cross-cutting patterns."
argument-hint: "[topic — feature name, issue, category, or question]"
---

# /analyze

You are running a **deep multi-query analysis** of a customer feedback topic. This command builds a comprehensive picture: volume trends, sentiment breakdown, theme structure, co-occurring patterns, taxonomy placement, and verbatim evidence. It is the full investigation — not a quick scan.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, tell the user: "Run `/start` first to connect to your organization's Knowledge Graph." Stop.
2. Read `context/organization.json` for org name, slug, and `citationBaseUrl`.
3. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server as a connectivity check. If it fails with an auth error, load the `onboarding` skill and stop.
4. Read `.claude/enterpret-customer-insights.local.md` if it exists for user preferences (role, focus, output style).

## Skills (reference during execution, not upfront)

- `wisdom-kg` — read if you need schema details or a query fails
- `evidence-synthesis` — read when synthesizing quotes and writing the narrative
- `user-context` — already loaded via .local.md above

## Process

### Step 1: Parse Input

Extract the topic from the user's input. Accept messy input — Jira ticket titles, vague descriptions, feature names, support escalation subjects.

- `/analyze checkout flow` → topic = "checkout flow"
- `/analyze PROJ-1234 cart abandonment regression` → topic = "cart abandonment"
- `/analyze why are users churning` → topic = "churn" (extract the core concept)
- `/analyze` (no argument) → Ask: "What topic should I analyze? (e.g., a feature name, issue, category, or question)"

### Step 2: Search the Knowledge Graph

Use `search_knowledge_graph` from the `wisdom-kg` MCP server with **2-3 keyword variations**:
- The user's exact words (cleaned of Jira IDs, filler words)
- A synonym or related phrasing
- A more specific or broader variation

Collect all matched theme/subtheme names. These become the target for subsequent queries. Use EXACT names from search results in all Cypher queries.

**If no matches:** Show closest results and ask the user to clarify or pick. Do not proceed with unvalidated theme names.

### Step 3: Multi-Query Investigation (8-9 queries, run sequentially)

Compute dates:
- `{TODAY}` = today (ISO format)
- `{30D_AGO}` = 30 days ago
- `{CURRENT_WEEK_START}` = start of current 7-day window
- `{CURRENT_WEEK_END}` = end of current 7-day window (today)
- `{PREV_WEEK_START}` = start of previous 7-day window
- `{PREV_WEEK_END}` = end of previous 7-day window

---

**Query 1: Volume by Theme (30 days)**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

---

**Query 2: Sentiment Distribution**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_SENTIMENT]->(sp:SentimentPrediction)
MATCH (fi)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN t.name AS theme, sp.label AS sentiment, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 30
```

---

**Query 3: Subtheme Breakdown**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
MATCH (cft)-[:HAS_SUBTHEME]->(st:Subtheme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN t.name AS theme, st.name AS subtheme, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

---

**Query 4: Week-over-Week Trend — Current Week**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{CURRENT_WEEK_START}" AND nli.record_timestamp < "{CURRENT_WEEK_END}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS current_volume
ORDER BY current_volume DESC
LIMIT 20
```

---

**Query 5: Week-over-Week Trend — Previous Week**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{PREV_WEEK_START}" AND nli.record_timestamp < "{PREV_WEEK_END}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS previous_volume
ORDER BY previous_volume DESC
LIMIT 20
```

Compute trend in analysis (not Cypher):
- `change = current_volume - previous_volume`
- `pct_change = change / previous_volume * 100`
- Handle: prior = 0, current > 0 → "NEW"; prior = 0, current = 0 → "Inactive"; < 5% change → "flat"

---

**Query 6: Taxonomy Placement (L1 → L2)**

```cypher
MATCH (th:TaxonomyHierarchy)-[:HAS_L1]->(l1:L1)
MATCH (th)-[:HAS_L2]->(l2:L2)
MATCH (th)-[:HAS_L3]->(l3:L3)
MATCH (th)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
RETURN l1.name AS l1, l2.name AS l2, l3.name AS l3, t.name AS theme
LIMIT 20
```

---

**Query 7: Co-occurring Themes**

Uses a single MATCH with two paths from the same FeedbackInsight node (required — no MATCH after WITH):

```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft1:CustomerFeedbackTags)-[:HAS_THEME]->(t1:Theme),
      (fi)-[:HAS_TAGS]->(cft2:CustomerFeedbackTags)-[:HAS_THEME]->(t2:Theme)
WHERE t1.name CONTAINS "{THEME_NAME}" AND NOT t2.name CONTAINS "{THEME_NAME}"
RETURN t2.name AS co_occurring_theme, COUNT(DISTINCT fi.feedback_record_id) AS shared_volume
ORDER BY shared_volume DESC
LIMIT 10
```

---

**Query 8: Insight Types Breakdown**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN t.name AS theme, fi.summary_type AS insight_type, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

---

**Query 9: Representative Quotes (fetch 20, select 3-5 diverse)**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN fi.feedback_record_id AS record_id, nli.content AS verbatim, fi.summary_type AS insight_type, nli.record_timestamp AS date
ORDER BY nli.record_timestamp DESC
LIMIT 20
```

From 20 results, select 3-5 per evidence-synthesis rules:
- Different subthemes — don't pick 3 quotes about the same narrow issue
- Different time periods — show the problem exists across time, not just one spike
- Different sentiment angles — include severity (frustrated) and impact (workaround, churn)
- Prefer quotes with specific detail, business impact, representative patterns
- Skip generic one-word complaints

---

**Query 10 (Optional): Account Breadth**

Before running this query, check the schema with `get_schema` for account-related nodes and relationships. Account metadata is schema-dependent — not all KGs have it.

If account nodes exist (e.g., `DerivedAccount` with `HAS_ACCOUNT` relationship):
```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
MATCH (nli)-[:HAS_ACCOUNT]->(da:DerivedAccount)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{30D_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN da.name AS account, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 15
```

**Graceful fallback:** If no account nodes/relationships exist in the schema, skip this query entirely and note in the output: "Account-level segmentation not available in this KG. Volume counts represent all feedback."

---

### Step 4: Synthesize

Follow the evidence-synthesis skill for narrative structure:
1. Lead with the finding — what you discovered
2. Size it — volume, trend, breadth
3. Interpret it — what does this mean for the product
4. Support it — quotes that prove the interpretation
5. Bound it — what we don't know

Use the insight types breakdown to interpret the nature of the signal:
- 90% COMPLAINT → needs a fix
- 60% QUESTION → needs better education/docs
- Mix of IMPROVEMENT + COMPLAINT → feature gap with active frustration

### Step 5: Present Output

---

### Deep Analysis: {topic}

**{org_name}** | Last 30 days | {total_volume} feedback items

---

**Executive Summary**

{2-3 sentences: What is the finding? How big is it? What is the trend? What should be done?}

---

**Taxonomy Placement**

```
{L1 Category}
└── {L2 Category}
    └── {L3 Category}
        └── Theme: {Theme Name}
```

Where this topic sits in your organization's feedback taxonomy.

---

**Theme Volume & Sentiment**

| Theme | Volume (30d) | Positive | Negative | Neutral | WoW Trend | Most Recent |
|-------|-------------|----------|----------|---------|-----------|-------------|
| {theme} | {vol} | {pos} ({pct}%) | {neg} ({pct}%) | {neu} ({pct}%) | {↑/↓/flat X%} | {YYYY-MM-DD} |
| ... | ... | ... | ... | ... | ... | ... |

---

**Subthemes**

| Subtheme | Volume | % of Total | Most Recent | Insight |
|----------|--------|-----------|-------------|---------|
| {subtheme} | {vol} | {pct}% | {YYYY-MM-DD} | {1-sentence interpretation} |
| ... | ... | ... | ... | ... |

---

**Sentiment Breakdown**

Overall: {total_pos}% Positive / {total_neg}% Negative / {total_neu}% Neutral

{1-2 sentence interpretation: Is this worse or better than typical? Is it concentrated in one subtheme?}

---

**Insight Types**

| Type | Volume | Interpretation |
|------|--------|---------------|
| COMPLAINT | {vol} | {what this means} |
| IMPROVEMENT | {vol} | {what this means} |
| QUESTION | {vol} | {what this means} |
| PRAISE | {vol} | {what this means} |

---

**Cross-Cutting Patterns**

Themes that co-occur with {topic} on the same feedback records:

| Co-occurring Theme | Shared Volume | Implication |
|-------------------|--------------|-------------|
| {theme} | {vol} | {what this connection means} |
| ... | ... | ... |

{1-2 sentence interpretation: Are there cascade effects? Does this connect to a broader system issue?}

---

**What customers are saying:**

> "{Quote — specific, illustrative, different subtheme}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{Quote — different angle, different time period}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{Quote — shows severity or business impact}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{Quote — workaround or churn signal if available}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

---

**Account Breadth** *(if available)*

| Account | Volume (30d) |
|---------|-------------|
| {account} | {vol} |
| ... | ... |

{N} distinct accounts reporting this issue. {Interpretation: concentrated in one account vs. widespread.}

*or:* Account-level segmentation not available. Volume counts represent all feedback.

---

**Limitations**

What this evidence does NOT tell us:
- {Specific limitation — e.g., "N=23 — treat as directional signal, not definitive"}
- {Channel bias — e.g., "This reflects support tickets and app reviews only. Users who self-resolve are invisible."}
- {Segment gap — e.g., "Account-level data not available — we cannot assess enterprise vs. SMB concentration."}
- {Correlation caveat — if applicable}
- {Taxonomy coverage — if search returned few matches: "The topic may exist under different labels not captured here."}

---

**Recommendations**

Based on the evidence:
1. {Specific, actionable recommendation framed as a product decision}
2. {Second recommendation — different angle (e.g., short-term vs. long-term, fix vs. investigate)}
3. {Optional third — escalation, communication, or process change}

---

**Data scope:** {N} items across {themes}. Window: {30D_AGO} to {TODAY}. WoW comparison: {CURRENT_WEEK_START}–{CURRENT_WEEK_END} vs {PREV_WEEK_START}–{PREV_WEEK_END}. Sources: {channels if determinable, else "all integrated sources"}.

---

For root cause investigation, try `/rootcause {topic}`. For a shareable brief, try `/brief`.

---

## Edge Cases

**Topic too broad (matches 10+ themes):**
Focus on the top 5 by volume. Note: "This topic maps to {N} themes — showing the top 5. Run `/explore {L1 category}` to browse the full hierarchy."

**Topic too narrow (< 10 results):**
Present what was found. Note: "Low volume — {N} items. Treat as directional signal. Consider broadening the search or checking adjacent themes."

**Insufficient data (< 3 results):**
"Insufficient data for meaningful analysis. Only {N} items found for '{topic}' in 30 days. Try: (1) a broader topic, (2) a longer time window via `/analyze {topic} 90d`, or (3) `/explore` to find related themes."

**Query failures:**
If any query fails, note which section is incomplete. Never retry the same failed query — simplify or skip and note the gap. Continue with remaining queries.

**No co-occurring themes:**
"No significant co-occurrence patterns found. This topic appears to be self-contained rather than part of a broader cluster."

**Everything is negative (90%+ negative sentiment):**
Flag this prominently in the executive summary. Consider recommending escalation.
