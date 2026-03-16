---
description: "Browse your Adaptive Taxonomy interactively — L1 → L2 → L3 → Theme hierarchy with volume, sentiment, and record retrieval."
argument-hint: "[category name, level, or record ID]"
---

# /explore

You are exploring your organization's **feedback taxonomy and data** — the hierarchical classification system for customer feedback. This is a utility command that outputs directly in chat (no report generation).

## Pre-Flight

1. Check if `context/organization.json` exists. If not, load the `onboarding` skill to run auto-discovery first.
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
3. If it fails with an auth error, load the `onboarding` skill and stop.
4. If successful, read `context/organization.json` for org name and L1 categories.

## Skills (reference if needed, do NOT read upfront)

- `wisdom-kg` — query patterns and KG rules (only read if a query fails and you need to debug)

## Behavior

### No argument: Show L1 overview

If the user runs `/explore` with no argument:

1. If `context/organization.json` already has L1 categories, present those directly. Otherwise query:
```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L1]->(l1:L1)
RETURN l1.name AS category, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

2. Present as a numbered table:

| # | Category | Volume |
|---|----------|--------|
| 1 | {top category} | {volume} |
| 2 | {second category} | {volume} |
| ... | ... | ... |

3. Say: "Pick a category number or name to drill deeper, or say 'done' to exit."

### With L1 argument: Show L2 breakdown

If the user runs `/explore {category}` or selects a category:

1. Query L2 under that L1:
```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L1]->(l1:L1)
MATCH (cft)-[:BELONGS_TO_L2]->(l2:L2)
WHERE l1.name = "{L1_CATEGORY}"
RETURN l2.name AS subcategory, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

2. Present as tree + table:

```
{L1 Category}
├── {L2 subcategory 1} ({volume})
├── {L2 subcategory 2} ({volume})
├── {L2 subcategory 3} ({volume})
└── ...
```

3. Say: "Pick a sub-category to see L3 detail and themes, or 'back' to go up."

### With L2 argument: Show L3 + Themes

1. Query L3 and themes with sentiment:
```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L2]->(l2:L2)
MATCH (cft)-[:BELONGS_TO_L3]->(l3:L3)
MATCH (cft)-[:HAS_THEME]->(t:Theme)
MATCH (fi)-[:HAS_SENTIMENT]->(sp:SentimentPrediction)
WHERE l2.name = "{L2_CATEGORY}"
RETURN l3.name AS issue, t.name AS theme, sp.label AS sentiment, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 30
```

2. Present as tree:

```
{L2 Category}
├── L3: {Issue 1} ({volume})
│   ├── Theme: {Theme name 1} ({volume}) — {X}% Negative
│   ├── Theme: {Theme name 2} ({volume}) — {X}% Negative
│   └── Theme: {Theme name 3} ({volume}) — {X}% Negative
├── L3: {Issue 2} ({volume})
│   └── Theme: {Theme name 4} ({volume})
└── ...
```

3. Say: "Want to investigate any of these themes? Try `/find [theme name]` or `/rootcause [theme name]`."

### Record Retrieval Mode

If the user provides a record ID or asks to "show me records" / "show me examples":

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)
WHERE fi.feedback_record_id = "{RECORD_ID}"
OPTIONAL MATCH (fi)-[:HAS_SENTIMENT]->(sp:SentimentPrediction)
OPTIONAL MATCH (fi)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
RETURN fi.feedback_record_id AS id, nli.content AS verbatim,
       nli.record_timestamp AS date, t.name AS theme, sp.label AS sentiment
LIMIT 5
```

For segment/filter-based record retrieval:

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE t.name = "{THEME_NAME}"
AND nli.record_timestamp >= "{START_DATE}"
RETURN fi.feedback_record_id AS id, nli.content AS verbatim, nli.record_timestamp AS date
ORDER BY nli.record_timestamp DESC
LIMIT 20
```

Present records with citation links: `[View in Enterpret]({citationBaseUrl}{record_id})`

### Search Mode

If the input doesn't match an L1/L2/L3 name exactly, use `search_knowledge_graph` to find the closest match:

1. Search with the user's terms
2. Present matches with their taxonomy placement
3. Ask: "Did you mean one of these? Or pick a category to browse."

## Interaction Loop

This command supports an interactive loop:
- User can keep drilling down by typing category/subcategory names or numbers
- User can go "back" to the previous level
- User can exit with "done"
- User can pivot to another command at any point (e.g., "investigate this" → suggest `/rootcause [theme]`)

## Notes

- This command does NOT generate a report. It's a utility for exploration and discovery.
- Keep output clean and scannable — use tree format for hierarchy.
- Always include volume counts to give context on relative importance.
- Suggest next actions based on what the user finds — `/find` for quick feedback, `/rootcause` for deep analysis.
