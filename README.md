# Enterpret Customer Insights

Customer intelligence powered by Enterpret's Wisdom Knowledge Graph. Query feedback, analyze patterns, investigate root causes, generate branded reports, and deliver scheduled feedback digests — all from Claude.

## Install

### Claude Code CLI

```bash
# Step 1 — Add the marketplace (one-time)
claude plugin marketplace add https://github.com/aavaz-ai/enterpret-claude-plugins

# Step 2 — Install the plugin
claude plugin install enterpret-customer-insights@enterpret-claude-plugins
```

### Claude CoWork (Desktop App)

1. Open Settings > Plugins > Add Marketplace
2. Paste: `https://github.com/aavaz-ai/enterpret-claude-plugins`
3. Browse the marketplace and install **Enterpret Customer Insights**

### Optional Setup

Commands work right after install. To save your profile and preferences, start a new Claude session and run:

```
/start
```

This connects to Enterpret, discovers your organization's data, and sets up your profile.

## Commands

| Command | What It Does |
|---------|-------------|
| `/start` | Optional setup — connect, discover data, set up profile |
| `/find [topic]` | Quick lookup — themes, sentiment, quotes |
| `/analyze [topic]` | Deep analysis — trends, patterns, root causes (`--rootcause` for severity triage) |
| `/explore [category?]` | Browse your feedback taxonomy interactively |
| `/report [mode?]` | Generate output — weekly memo, account brief, exec summary, or branded doc |
| `/digest [setup\|run\|preview\|config]` | Build a recurring feedback digest — choose topics, preview, deliver to Slack/email/CoWork, and schedule |

## How It Works

This plugin connects to your organization's **Wisdom Knowledge Graph** via the Enterpret MCP server. Commands load your organization's details themselves. When you run `/start`, it also:

1. Authenticates via OAuth (CoWork handles this automatically)
2. Discovers your organization's taxonomy and feedback structure
3. Saves context and your profile (in CoWork, saved context lasts for that chat only)

All queries run against your live feedback data. Every insight includes citation links back to the Enterpret dashboard.

## Skills

The plugin includes specialized knowledge modules:

- **wisdom-kg** — KG schema, Cypher patterns, query validation, user context
- **evidence-synthesis** — Turning raw data into actionable narrative
- **report-engine** — Branded report generation (docx/pptx/html)
- **wisdom-slack-digest** — Scheduled feedback digests delivered to Slack

## Agents

- **wisdom-expert** — General-purpose feedback research (used when you ask about customer feedback)
- **report-builder** — Isolated context for long report generation

## Configuration

### User Profile

Your preferences are stored in `.claude/enterpret-customer-insights.local.md`:

```yaml
---
name: "Your Name"
role: "Product Manager"
team: "Your Team"
audience: "leadership"
default_format: "html"
brand_colors:
  primary: "#1B2A4A"
  accent: "#2AABB3"
company_name: "Your Company"
language: "en"
---
```

Edit this file to customize report formatting, audience targeting, and brand colors.

### Brand Assets

Default brand tokens are in `brand/enterpret.json`. To customize, create `brand/custom.json` with your overrides.

### Feedback Digest

The `/digest` command builds a recurring customer feedback digest and delivers it to your team's channel. Setup is interactive — Claude walks you through:

1. **What to track** — pick topics based on your goals, not raw taxonomy browsing
2. **Preview** — see the formatted digest before sending anything
3. **Where to deliver** — Slack, email, or CoWork (auto-detects available connectors)
4. **Schedule** — set up recurring delivery via CoWork's scheduler

Digest configuration is saved to `context/digest-config.md`. Edit it anytime with `/digest config` or re-run `/digest setup` to start fresh.

The digest uses a three-tier Slack architecture: a scannable headline in the channel (severity indicators + one-line insights), detailed topic cards in the thread (analysis + quote + action), and optional raw data for data-oriented readers.

## Requirements

- Claude Code CLI (latest) or Claude CoWork desktop app
- Enterpret account with Wisdom Knowledge Graph access

## Support

Having trouble? Contact your Customer Success Manager or reach out to **support@enterpret.com**.

- [Wisdom MCP Server Setup](https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server)
- [Wisdom User Guide](https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide)
