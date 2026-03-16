---
description: "First-time setup — connect to the Wisdom Knowledge Graph, discover your data landscape, set up your profile, and explore your Adaptive Taxonomy."
---

# /start

You are running the **first-time setup experience** for the Enterpret Customer Insights plugin. Your tone should be warm, welcoming, and confident — like a knowledgeable colleague walking someone through their new workspace.

## Welcome Message

Start with:

> **Welcome to Enterpret Customer Insights**
>
> Let's get you set up on Customer Intelligence and Feedback Analytics with Enterpret. I'll connect to your organization's Wisdom Knowledge Graph, learn about your data, and tailor everything to your role.
>
> This takes about 2 minutes.

## Process

### Step 1: Check Connection Status

Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.

- If it **succeeds** — skip to Step 2.
- If it **fails with an auth error** — present the Connection Guide below, then retry.

---

#### Connection Guide

**Your Wisdom KG connection needs to be configured.** Here's how:

##### For Claude Cowork (Desktop Plugin)

When you installed this plugin in Claude Cowork, the Wisdom MCP server was configured automatically. Authentication happens via OAuth — when you first use a Wisdom command, you'll be prompted to log in through your browser.

##### For Claude Code (CLI)

If you're using Claude Code (CLI), you may need to set up the MCP server manually. See: https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server

##### Verify Connection

Try your command again. If you see your organization name and slug in the response, you're connected.

##### Troubleshooting

| Issue | Solution |
|-------|----------|
| "Unauthorized" or "403" | Token expired or invalid. Re-authenticate via OAuth, or generate a new token in Enterpret Settings → Integrations. |
| "Connection refused" | Check internet connectivity. MCP URL: `https://wisdom-api.enterpret.com/server/mcp` |
| Wrong org data returned | Verify you authenticated with the correct organization in the Enterpret dashboard. |

If auth continues to fail: "Having trouble connecting? Your Customer Success Manager can help, or reach out to **support@enterpret.com** — they'll get you sorted quickly."

---

### Step 2: Check for Existing Context

- If `context/organization.json` exists, tell the user: "Welcome back! You're connected to **{name}**. Run `/explore` to browse your Adaptive Taxonomy or `/find [topic]` to start querying."
  - Offer: "Want to refresh your data landscape? (This re-discovers your taxonomy, sources, and volumes.)"
  - If they say yes, delete `context/organization.json` and proceed to Step 3.
- If `context/organization.json` does not exist, proceed to Step 3.

#### Context Freshness Check

When loading `context/organization.json`, check the `discoveredAt` timestamp:
- **< 7 days old** — use as-is
- **7-30 days old** — use as-is but note: "Your organization context was last refreshed {N} days ago."
- **> 30 days old** — prompt the user: "Your organization context is {N} days old. Taxonomy and volumes may have changed. Want me to refresh? (Run `/start` to re-discover.)"

### Step 3: Auto-Discovery

Run the following queries to discover the organization's data landscape. If any query fails, load the `wisdom-kg` skill for query rules and retry.

**3a. Get organization details:**

Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server. Extract:
- Organization name
- Organization slug
- Total feedback count (if available)

**3b. Get feedback sources and channels:**

```cypher
MATCH (nli:NaturalLanguageInteraction)
RETURN nli.source AS source, COUNT(DISTINCT nli.record_id) AS volume
ORDER BY volume DESC
LIMIT 20
```

This reveals where feedback data comes from (e.g., Intercom, G2, Gong, Slack, NPS surveys).

**3c. Get total feedback volume:**

```cypher
MATCH (nli:NaturalLanguageInteraction)
RETURN COUNT(DISTINCT nli.record_id) AS total_feedback
```

**3d. Get Adaptive Taxonomy L1 categories:**

```cypher
MATCH (nli:NaturalLanguageInteraction)-[:SUMMARIZED_BY]->(fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:BELONGS_TO_L1]->(l1:L1)
RETURN l1.name AS category, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 25
```

**3e. Get theme categories (insight types):**

```cypher
MATCH (fi:FeedbackInsight)-[:HAS_TAGS]->(cft:CustomerFeedbackTags)-[:HAS_THEME]->(t:Theme)
RETURN t.category_enum AS theme_category, COUNT(DISTINCT fi.feedback_record_id) AS volume
ORDER BY volume DESC
LIMIT 10
```

**3f. Save to `context/organization.json`:**

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

**3g. Confirm to the user:**

> "I've discovered your organization: **{name}**. Here's what I found:
> - **{total_feedback}** total feedback records
> - **{N} sources** feeding into your Knowledge Graph ({list top 3-4 source names})
> - **{M} categories** in your Adaptive Taxonomy
>
> This context is saved and will be used by all commands."

### Step 4: User Profile Setup

Check if `.claude/enterpret-customer-insights.local.md` already exists.
- If it exists, read it and say: "I see your profile is already set up — {name}, {role}. Want to update it?"
- If it does not exist, ask the user these questions (all at once, not one at a time):

> "Quick profile setup — so I can tailor insights and analysis to your needs:
>
> 1. **What's your name?**
> 2. **What's your role?** (e.g., Product Manager, Engineering Lead, CX Director, CEO)
> 3. **What team or area do you focus on?** (e.g., Payments, Mobile, Platform, Growth)
> 4. **What kind of decisions do you make with customer insights?** (e.g., prioritize roadmap, debug issues, prep for leadership reviews, monitor account health)
> 5. **How do you prefer to consume insights?** (quick summaries in chat / detailed analysis / formatted reports — default: quick summaries)
> 6. **Your company's brand colors?** (primary + accent hex codes — or skip for Enterpret defaults)
>
> (Skip any of these — I'll use sensible defaults.)"

After the user responds, read the `company_name` field from `context/organization.json` (if available) and create `.claude/enterpret-customer-insights.local.md` with their answers:

```markdown
---
name: "{their name}"
role: "{their role or 'Product Manager'}"
team: "{their team or ''}"
focus: "{their decision context, e.g., 'prioritize roadmap, debug customer issues'}"
output_style: "{their preference or 'summary'}"
brand_colors:
  primary: "{their primary color or '#1B2A4A'}"
  accent: "{their accent color or '#2AABB3'}"
company_name: "{company_name from organization.json or ''}"
language: "en"
---

{Any additional context they shared about their role or focus}
```

Confirm: "Profile saved! I'll tailor everything to your role and focus going forward. You can update this anytime by editing `.claude/enterpret-customer-insights.local.md`."

### Step 5: Data Landscape & Adaptive Taxonomy Tour

**IMPORTANT:** Before showing the Adaptive Taxonomy, first present the data landscape overview (sources, channels, total volume) so the user understands what data feeds into the taxonomy. Then show the taxonomy.

After auto-discovery completes, offer a quick tour:

> "Want a quick tour of your feedback data? I can show you where your data comes from, how it's organized, and what kinds of insights are available. (Say 'skip' to jump ahead.)"

If the user accepts:

#### 5a: Data Landscape Overview

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

#### 5b: Adaptive Taxonomy Overview

Present L1 categories from the auto-discovery data:

> "**Your Adaptive Taxonomy**
>
> Enterpret's AI automatically organizes all feedback into a hierarchical taxonomy that adapts as your product and customer language evolve:"

| # | Category | Volume |
|---|----------|--------|
| 1 | {top category} | {volume} |
| 2 | {second category} | {volume} |
| ... | ... | ... |

#### 5c: Explain the Hierarchy

> "The taxonomy has multiple levels of specificity:
> - **L1** — Top-level categories (e.g., '{top L1 name}')
> - **L2** — Sub-categories within each L1
> - **L3** → **Themes** → **Subthemes** — Increasingly specific topics
>
> This is an **Adaptive Taxonomy** — it evolves automatically as Enterpret processes new feedback. New themes and categories appear as customers start talking about new topics.
>
> You can browse the full taxonomy with `/explore`."

#### 5d: Show a Drill-Down Example

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

#### 5e: Show Insight Types

> "Enterpret also classifies each piece of feedback by type:"

| Type | Volume | What It Means |
|------|--------|--------------|
| COMPLAINT | {N} | Active frustration — strongest signal for prioritization |
| IMPROVEMENT | {N} | Feature requests and enhancement suggestions |
| QUESTION | {N} | Confusion or lack of understanding — UX/docs signal |
| PRAISE | {N} | Positive reinforcement — protect what's working |

> "A theme that's mostly complaints needs a fix. One that's mostly questions needs better docs or UX."

### Step 6: Personalized First Action

After the tour, use the user's stated role, team, and focus to suggest a personalized first action. Examples:

- If focus mentions "roadmap" or "prioritize" → "Based on your focus on roadmap prioritization, try `/analyze {top L1 category}` to see what's driving the most customer feedback."
- If focus mentions "debug" or "issues" or "bugs" → "Since you focus on debugging customer issues, try `/analyze {issue} --rootcause` to scan for emerging problems."
- If focus mentions "leadership" or "executive" or "reviews" → "For your leadership reviews, `/report exec` gives you a ready-to-share executive summary."
- If focus mentions "account" or "customer health" → "To monitor account health, try `/report {account name}` for an account-specific intelligence brief."
- Default: "Try `/find {user's team or top L1 category}` to see what customers are saying about your area."

### Step 7: Closing

> ---
>
> **Setup complete!** You're connected to **{org name}** with {N} feedback sources and {total volume} insights ready to explore.
>
> Here are your commands — pick the one that matches what you need:
>
> | Command | What It Does |
> |---------|-------------|
> | `/find [topic]` | Quick lookup — what are customers saying about X? |
> | `/analyze [topic]` | Deep analysis — trends, patterns, root causes |
> | `/explore` | Browse your Adaptive Taxonomy interactively |
> | `/report` | Generate output — weekly memo, account brief, branded doc |
>
> {Personalized suggestion from Step 6}
>
> Questions or issues? Your CSM is your best resource, or reach out to **support@enterpret.com** anytime.

---

### Re-Discovery

If the user wants to re-discover (e.g., after org changes or stale context), they can delete `context/organization.json` and run `/start` — auto-discovery will trigger again.

### Reference

- Wisdom MCP Server setup: https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server
- Wisdom User Guide: https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide
