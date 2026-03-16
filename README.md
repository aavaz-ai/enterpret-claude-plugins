# Enterpret Customer Insights — Claude Plugin

Your customer feedback intelligence, inside Claude.

Query your Wisdom Knowledge Graph, analyze feedback patterns, investigate root causes, and generate branded reports — without leaving Claude Code or Claude Cowork.

## Prerequisites

- An active **Enterpret** account with Wisdom MCP access
- **Claude Code** (CLI), **Claude Cowork**, or **Claude Desktop**

## Install

### Individual User

```bash
claude plugin marketplace add aavaz-ai/enterpret-customer-insights-plugin
claude plugin install enterpret-customer-insights@enterpret-plugins
```

### Organization-Wide (Claude Admins)

Deploy the plugin to every user in your Claude organization automatically. See the **[Admin Deployment Guide](ADMIN-GUIDE.md)** for step-by-step instructions.

## Quick Start

1. **Run `/start`** — connects to your Enterpret org and sets up your profile
2. **Try `/find [topic]`** — see what customers are saying about any topic
3. **Run `/brief`** — get a shareable summary for your team

## Commands

| Command | What It Does |
|---------|-------------|
| `/start` | First-time setup — connect, profile, taxonomy tour |
| `/find [topic]` | Quick lookup — themes, sentiment, quotes |
| `/analyze [topic]` | Deep analysis — trends, subthemes, patterns |
| `/rootcause [issue]` | Root cause investigation — severity, blast radius, evidence chain |
| `/explore [category?]` | Browse your feedback taxonomy interactively |
| `/brief [type?]` | Shareable summary — weekly, account, executive, or team |
| `/report [archetype?]` | Branded report — docx, pptx, or html |

## How It Works

This plugin connects to your organization's **Wisdom Knowledge Graph** via the Enterpret MCP server. When you run `/start`, it:

1. Authenticates via OAuth (Claude handles this automatically)
2. Discovers your organization's taxonomy and feedback structure
3. Saves context for all future commands

All queries run against your live feedback data. Every insight includes citation links back to the Enterpret dashboard.

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

## Skills

- **wisdom-kg** — KG schema, Cypher patterns, query validation
- **evidence-synthesis** — Turning raw data into actionable narrative
- **report-engine** — Branded report generation (docx/pptx/html)
- **user-context** — Your preferences, role, and brand settings
- **onboarding** — Setup and connection guide

## Agents

- **wisdom-expert** — General-purpose feedback research (auto-triggers on natural language questions)
- **report-builder** — Isolated context for long report generation

## Support

Having trouble? Contact your Customer Success Manager or reach out to **support@enterpret.com**.

- [Wisdom MCP Server Setup](https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server)
- [Wisdom User Guide](https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide)

## License

[MIT](LICENSE)
