---
name: onboarding
description: >
  Guides new users through connecting to the Wisdom MCP server, auto-discovers
  organization details (including feedback sources and channels) to create
  context/organization.json, and provides a data landscape + Adaptive Taxonomy tour.
  Auto-triggers on authentication failure. Works with any Enterpret-powered organization.
version: 5.1.0
---

# Onboarding — Setup, Auto-Discovery & Data Landscape Tour

This skill handles three scenarios:
1. **MCP connection setup** — guiding users through OAuth and config
2. **Organization auto-discovery** — querying org details, sources, taxonomy, saving to `context/organization.json`
3. **Data landscape + Adaptive Taxonomy tour** — helping new users understand their feedback ecosystem

---

## Part 1: MCP Connection Guide

### When This Triggers

Any command that calls `get_organization_details` and receives an auth error, or when `context/organization.json` does not exist.

### Setup Instructions

Present this to the user:

---

**Your Wisdom KG connection needs to be configured.** Here's how:

#### For Claude Cowork (Desktop Plugin)

When you installed this plugin in Claude Cowork, the Wisdom MCP server was configured automatically. Authentication happens via OAuth — when you first use a Wisdom command, you'll be prompted to log in through your browser.

#### For Claude Code (CLI)

If you're using Claude Code (CLI), you may need to set up the MCP server manually. See: https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server

#### Verify Connection

Try your command again. If you see your organization name and slug in the response, you're connected.

Having trouble? Your Customer Success Manager can help, or reach out to **support@enterpret.com** — they'll get you sorted quickly.

### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unauthorized" or "403" | Token expired or invalid. Re-authenticate via OAuth, or generate a new token in Enterpret Settings → Integrations. |
| "Connection refused" | Check internet connectivity. MCP URL: `https://wisdom-api.enterpret.com/server/mcp` |
| Wrong org data returned | Verify you authenticated with the correct organization in the Enterpret dashboard. |

---

## Part 2: Organization Auto-Discovery

### When This Triggers

After a successful `get_organization_details` call, check if `context/organization.json` exists. If not, run auto-discovery.

### Discovery Flow

1. **Get organization details:**

Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server. Extract:
- Organization name
- Organization slug
- Total feedback count (if available)

2. **Get feedback sources and channels:**

```cypher
MATCH (nli:NaturalLanguageInteraction)
RETURN nli.source AS source, COUNT(DISTINCT nli.record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

This reveals where feedback data comes from (e.g., Intercom, G2, Gong, Slack, NPS surveys).

3. **Get total feedback volume:**

```cypher
MATCH (nli:NaturalLanguageInteraction)
RETURN COUNT(DISTINCT nli.record_id) AS total_feedback
```

4. **Get Adaptive Taxonomy L1 categories:**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L1]->(l1:L1)
RETURN l1.name AS category, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 25
```

5. **Get theme categories (insight types):**

```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
RETURN t.category_enum AS theme_category, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

6. **Save to `context/organization.json`:**

```json
{
  "name": "Acme Corp",
  "slug": "acme-corp",
  "discoveredAt": "2026-03-05T12:00:00Z",
  "dashboardUrl": "https://dashboard.enterpret.com/acme-corp/",
  "citationBaseUrl": "https://dashboard.enterpret.com/acme-corp/record/",
  "totalFeedback": 150000,
  "sources": [
    { "name": "intercom", "volume": 80000 },
    { "name": "g2", "volume": 30000 },
    { "name": "Gong", "volume": 25000 },
    { "name": "snowflake-nps survey", "volume": 15000 }
  ],
  "taxonomy": {
    "l1Categories": [
      { "name": "Category Name", "volume": 12345 }
    ],
    "themeCategories": [
      { "name": "COMPLAINT", "volume": 100000 },
      { "name": "HELP", "volume": 50000 }
    ]
  }
}
```

7. **Confirm to the user:**

> "I've discovered your organization: **{name}**. Here's what I found:
> - **{total_feedback}** total feedback records
> - **{N} sources** feeding into your Knowledge Graph ({list top 3-4 source names})
> - **{M} categories** in your Adaptive Taxonomy
>
> This context is saved and will be used by all commands."

### Re-Discovery

If the user wants to re-discover (e.g., after org changes), they can delete `context/organization.json` and run any command — auto-discovery will trigger again.

---

## Part 3: Data Landscape & Adaptive Taxonomy Tour

### When to Offer

After auto-discovery completes (or on first successful connection), offer a quick tour:

> "Want a quick tour of your feedback data? I can show you where your data comes from, how it's organized, and what kinds of insights are available. (Say 'skip' to jump ahead.)"

### Tour Flow

If the user accepts:

#### Step 1: Data Landscape Overview

Present the feedback sources from the auto-discovery data:

> "**Your Feedback Landscape**
>
> Your Wisdom Knowledge Graph ingests feedback from {N} sources:"

| # | Source | Volume | Channel Type |
|---|--------|--------|-------------|
| 1 | {source name} | {volume} | {type: support tickets / reviews / calls / surveys / social} |
| 2 | {source name} | {volume} | {type} |
| ... | ... | ... | ... |

> "That's **{total_feedback}** feedback records total. Enterpret's AI has analyzed each one, extracting insights, detecting sentiment, and organizing everything into your Adaptive Taxonomy."

Briefly explain channel types based on the sources found:
- **Support tickets** (Intercom, Zendesk, etc.): Direct customer-reported issues and requests
- **App reviews** (G2, App Store, etc.): Public perception and competitive signal
- **Sales/CS calls** (Gong, etc.): Qualitative depth — buying signals, churn risk, feature gaps
- **Surveys** (NPS, CSAT, etc.): Structured sentiment with score data
- **Community/social** (Slack, social, etc.): Organic conversation and emerging signals

#### Step 2: Adaptive Taxonomy Overview

Present L1 categories from the auto-discovery data:

> "**Your Adaptive Taxonomy**
>
> Enterpret's AI automatically organizes all feedback into a hierarchical taxonomy that adapts as your product and customer language evolve:"

| # | Category | Volume |
|---|----------|--------|
| 1 | {top category} | {volume} |
| 2 | {second category} | {volume} |
| ... | ... | ... |

#### Step 3: Explain the hierarchy

> "The taxonomy has multiple levels of specificity:
> - **L1** — Top-level categories (e.g., '{top L1 name}')
> - **L2** — Sub-categories within each L1
> - **L3** → **Themes** → **Subthemes** — Increasingly specific topics
>
> This is an **Adaptive Taxonomy** — it evolves automatically as Enterpret processes new feedback. New themes and categories appear as customers start talking about new topics.
>
> You can browse the full taxonomy with `/explore`."

#### Step 4: Show a drill-down example

Pick the top L1 category and drill into its L2s:

```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L1]->(l1:L1)
MATCH (cft)-[:BELONGS_TO_L2]->(l2:L2)
WHERE l1.name = "{top L1 category}"
RETURN l2.name AS subcategory, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

Present the L2 drill-down as a tree:

```
{Top L1 Category}
├── {L2 subcategory 1} ({volume})
├── {L2 subcategory 2} ({volume})
├── {L2 subcategory 3} ({volume})
└── ...
```

#### Step 5: Show insight types

> "Enterpret also classifies each piece of feedback by type:"

| Type | Volume | What It Means |
|------|--------|--------------|
| COMPLAINT | {N} | Active frustration — strongest signal for prioritization |
| IMPROVEMENT | {N} | Feature requests and enhancement suggestions |
| QUESTION | {N} | Confusion or lack of understanding — UX/docs signal |
| PRAISE | {N} | Positive reinforcement — protect what's working |

> "A theme that's mostly complaints needs a fix. One that's mostly questions needs better docs or UX."

#### Step 6: Hand off (do NOT show a generic command table)

The `/start` command handles the closing — this skill just provides the data. Return control to the command for the personalized closing based on the user's profile.

### Reference

- Wisdom MCP Server setup: https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server
- Wisdom User Guide: https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide
