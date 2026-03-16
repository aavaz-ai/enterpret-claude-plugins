---
description: "Deep analysis of a topic — volume trends, sentiment, theme breakdown, patterns, and evidence. Add --rootcause for severity assessment and hypothesis clustering."
argument-hint: "[topic] [--rootcause]"
---

# /analyze

You are running a **deep multi-query analysis** of a customer feedback topic. This command builds a comprehensive picture: volume trends, sentiment breakdown, theme structure, co-occurring patterns, taxonomy placement, and verbatim evidence. It is the full investigation — not a quick scan.

With `--rootcause`, the same queries power a **structured root cause analysis** — severity assessment, blast radius, hypothesis clustering, and an evidence chain focused on diagnosing issues.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, tell the user: "Run `/start` first to connect to your organization's Knowledge Graph." Stop.
2. Read `context/organization.json` for org name, slug, and `citationBaseUrl`.
3. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server as a connectivity check. If it fails with an auth error, tell the user to run `/start` and stop.
4. Read `.claude/enterpret-customer-insights.local.md` if it exists for user preferences (role, focus, output style).

## Mode Detection

Determine which mode to run:

1. **Explicit flag:** `/analyze checkout --rootcause` → rootcause mode
2. **Implicit detection:** If the input looks like a bug report, Jira paste, or contains words like "broken", "failing", "regression", "outage", "crash", "error", "down" → suggest rootcause mode:
   > "This looks like an issue investigation — want me to include severity assessment and root cause hypotheses? (y/n)"
   - If yes → rootcause mode
   - If no → standard mode
3. **Default:** standard analysis mode

Set the mode variable `{MODE}` to either `standard` or `rootcause` for use in subsequent steps.

## Skills (reference during execution, not upfront)

- `wisdom-kg` — read if you need schema details or a query fails
- `evidence-synthesis` — read when synthesizing quotes and writing the narrative
- User context is loaded from `.local.md` above; defaults are in the `wisdom-kg` skill

## Process

### Step 1: Parse Input

Extract the topic from the user's input. Accept messy input — Jira ticket titles, vague descriptions, feature names, support escalation subjects.

- `/analyze checkout flow` → topic = "checkout flow"
- `/analyze PROJ-1234 cart abandonment regression` → topic = "cart abandonment"
- `/analyze why are users churning` → topic = "churn" (extract the core concept)
- `/analyze login fails on mobile after update --rootcause` → topic = "login fails on mobile", mode = rootcause
- `/analyze [pasted Jira/ticket text] --rootcause` → extract symptoms and key terms from the pasted text
- `/analyze` (no argument) → Ask: "What topic should I analyze? (e.g., a feature name, issue, category, or question)"

**Time window:**
- Standard mode: **30 days**
- Rootcause mode: **14 days**

In rootcause mode, optionally ask: "What triggered this investigation? (e.g., escalation, spike, customer complaint)" — the trigger helps frame the analysis.

### Step 2: Search the Knowledge Graph

Use `search_knowledge_graph` from the `wisdom-kg` MCP server with **2-3 keyword variations**:
- The user's exact words (cleaned of Jira IDs, filler words)
- A synonym or related phrasing
- A more specific or broader variation

Collect all matched theme/subtheme names. These become the target for subsequent queries. Use EXACT names from search results in all Cypher queries.

**If no matches:** Show closest results and ask the user to clarify or pick. Do not proceed with unvalidated theme names.

### Step 3: Multi-Query Investigation (up to 10 queries, run sequentially)

Compute dates:
- `{TODAY}` = today (ISO format)
- `{WINDOW_AGO}` = 30 days ago (standard) or 14 days ago (rootcause)
- `{CURRENT_WEEK_START}` = start of current 7-day window
- `{CURRENT_WEEK_END}` = end of current 7-day window (today)
- `{PREV_WEEK_START}` = start of previous 7-day window
- `{PREV_WEEK_END}` = end of previous 7-day window

---

**Query 1: Volume by Theme**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
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
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
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
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
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

**Query 6: Taxonomy Placement (L1 → L2)** — *standard mode only, skip in rootcause mode*

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

In standard mode, this section is titled **"Cross-Cutting Patterns"**.
In rootcause mode, this section is titled **"Cascade Impact"** — interpret results as blast radius and downstream effects.

---

**Query 8: Insight Types Breakdown**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
RETURN t.name AS theme, fi.summary_type AS insight_type, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

---

**Query 9: Representative Quotes (fetch 20, select 3-5 diverse)**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
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
  AND nli.record_timestamp >= "{WINDOW_AGO}" AND nli.record_timestamp < "{TODAY}"
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

**Rootcause mode additional synthesis:**

#### Root Cause Clustering

Group the verbatim quotes by symptom pattern. For each cluster:
1. Assign a descriptive label (e.g., "Session timeout after app update", "Payment form reset on back-navigation")
2. Mark each as **HYPOTHESIS** — root causes are inferred, not proven
3. Note the supporting evidence count and subtheme alignment

#### Severity Assessment

Classify the issue using the evidence gathered:

| Severity | Criteria | Action |
|----------|----------|--------|
| **P0 — Critical** | >20 accounts affected + >50% negative sentiment + accelerating WoW trend | Escalate immediately |
| **P1 — High** | 5-20 accounts affected OR >30% negative sentiment OR worsening WoW trend | Prioritize this sprint |
| **P2 — Monitor** | <5 accounts affected, stable or declining trend | Track, don't escalate |

If account data is unavailable, assess severity on volume + sentiment + trend only and note the gap.

### Step 5: Present Output

Use the output template matching the current mode.

---

## Output: Standard Mode

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
| {theme} | {vol} | {pos} ({pct}%) | {neg} ({pct}%) | {neu} ({pct}%) | {direction X%} | {YYYY-MM-DD} |
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

**Data scope:** {N} items across {themes}. Window: {WINDOW_AGO} to {TODAY}. WoW comparison: {CURRENT_WEEK_START}–{CURRENT_WEEK_END} vs {PREV_WEEK_START}–{PREV_WEEK_END}. Sources: {channels if determinable, else "all integrated sources"}.

---

For root cause investigation, add `--rootcause`. For a shareable summary, try `/report`.

---

## Output: Rootcause Mode

---

## Root Cause Analysis: {Issue Description}

**Window:** {WINDOW_AGO} to {TODAY} (14 days) | **Volume:** {total_volume} items | **Severity:** {P0/P1/P2 badge}

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

For broader analysis, run without `--rootcause`. For a shareable summary, try `/report`.

---

## Edge Cases

**Topic too broad (matches 10+ themes):**
Focus on the top 5 by volume. Note: "This topic maps to {N} themes — showing the top 5. Run `/explore {L1 category}` to browse the full hierarchy."

**Topic too narrow (< 10 results):**
Present what was found. Note: "Low volume — {N} items. Treat as directional signal. Consider broadening the search or checking adjacent themes."

**Insufficient data (< 3 results):**
"Insufficient data for meaningful analysis. Only {N} items found for '{topic}' in {window} days. Try: (1) a broader topic, (2) a longer time window, or (3) `/explore` to find related themes."

**Query failures:**
If any query fails, note which section is incomplete. Never retry the same failed query — simplify or skip and note the gap. Continue with remaining queries.

**No co-occurring themes:**
"No significant co-occurrence patterns found. This topic appears to be self-contained rather than part of a broader cluster."

**Everything is negative (90%+ negative sentiment):**
Flag this prominently in the executive summary. In standard mode, consider recommending escalation. In rootcause mode, this strongly supports P0/P1 classification.

**Rootcause mode — no clear clusters:**
If quotes don't form distinct symptom clusters, present a single "Undifferentiated" hypothesis and note: "Evidence does not clearly separate into distinct root causes — the issue may have a single underlying cause, or the taxonomy may not capture the relevant distinctions."

**Rootcause mode — account data unavailable:**
Assess severity on volume + sentiment + trend only. Note: "Account-level segmentation not available for this organization. Severity assessed on volume and sentiment signals only."
