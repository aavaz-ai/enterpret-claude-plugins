---
description: "Quick lookup — what are customers saying about a topic? Returns themes, sentiment, and quotes with citations."
argument-hint: "[topic — feature name, issue, or question]"
---

# /find

Quick lookup of customer feedback on a topic. Fast, focused, 1-2 queries max.

## Setup

1. Read `context/organization.json` for `citationBaseUrl` and org name. If it doesn't exist, tell the user to run `/start` and stop.
2. If the user provided no topic, ask: "What topic should I look into?"

## Execution

**Step 1:** Use `search_knowledge_graph` from the `enterpret-wisdom-mcp` MCP server with the user's topic (try 2-3 keyword variations). Use the EXACT theme names returned.

**Step 2:** Run this query for volume + sentiment (substitute the exact theme name and dates):

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_SENTIMENT]->(sp:SentimentPrediction)
MATCH (fi)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN t.name AS theme, sp.label AS sentiment, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

Use `execute_cypher_query` with parameter name `cypher_query`. Default window: 7 days if user said "last week", otherwise 30 days. Compute ISO dates.

**Note:** Use `CONTAINS` (not `=`) for theme matching to handle partial name matches consistently across all commands. The `search_knowledge_graph` step already validates theme names, so CONTAINS catches slight variations without false positives.

**Step 3:** Run this query for quotes:

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
WHERE t.name CONTAINS "{THEME_NAME}"
  AND nli.record_timestamp >= "{START_DATE}" AND nli.record_timestamp < "{END_DATE}"
RETURN fi.feedback_record_id AS record_id, nli.content AS verbatim, nli.record_timestamp AS date
ORDER BY nli.record_timestamp DESC
LIMIT 10
```

Pick 3-5 diverse quotes (different angles, not repetitive).

## Output — YOU MUST PRESENT THIS

After running queries, you MUST present results in this format:

---

### What customers are saying about: {topic}

**{org_name}** · Last {N} days · {total_volume} items · Most recent: {YYYY-MM-DD}

| Theme | Volume | Positive | Negative | Neutral |
|-------|--------|----------|----------|---------|
| {name} | {total} | {pos} ({pct}%) | {neg} ({pct}%) | {neu} ({pct}%) |

**What customers are saying:**

> "{quote 1}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{quote 2}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

> "{quote 3}"
> — {YYYY-MM-DD} · [View in Enterpret]({citationBaseUrl}{record_id})

**Key takeaway:** {1-2 sentence synthesis of what this means}

---

For deeper analysis with trends and subthemes, try `/analyze {topic}`.

---

## Query Rules (critical)

- Always use `LIMIT` (max 50)
- Count with `COUNT(DISTINCT fi.feedback_record_id)` — never `COUNT(nli)`
- Never use `count` as an alias (reserved word) — use `volume`
- Sentiment values are capitalized: `"Positive"`, `"Negative"`, `"Neutral"`
- Dates use string comparison on `record_timestamp`: `>= "2026-02-27"` (not `date()`)
- Parameter name is `cypher_query` not `query`
- If no results, say so — never fabricate data
- If search returns no matches, show closest results and ask user to pick
