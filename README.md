# Enterpret Customer Insights

Customer intelligence powered by Enterpret's Wisdom Knowledge Graph. Query feedback, analyze patterns, investigate root causes, and generate branded reports — all from Claude.

## Quick Start

1. Install the plugin in Claude Cowork
2. Run `/start` to connect and set up your profile
3. Try `/find [topic]` to see what customers are saying

## Commands

| Command | What It Does |
|---------|-------------|
| `/start` | First-time setup — connect, discover data, set up profile |
| `/find [topic]` | Quick lookup — themes, sentiment, quotes |
| `/analyze [topic]` | Deep analysis — trends, patterns, root causes (`--rootcause` for severity triage) |
| `/explore [category?]` | Browse your feedback taxonomy interactively |
| `/report [mode?]` | Generate output — weekly memo, account brief, exec summary, or branded doc |

## How It Works

This plugin connects to your organization's **Wisdom Knowledge Graph** via the Enterpret MCP server. When you run `/start`, it:

1. Authenticates via OAuth (Cowork handles this automatically)
2. Discovers your organization's taxonomy and feedback structure
3. Saves context for all future commands

All queries run against your live feedback data. Every insight includes citation links back to the Enterpret dashboard.

## Skills

The plugin includes specialized knowledge modules:

- **wisdom-kg** — KG schema, Cypher patterns, query validation, user context
- **evidence-synthesis** — Turning raw data into actionable narrative
- **report-engine** — Branded report generation (docx/pptx/html)

## Agents

- **wisdom-expert** — General-purpose feedback research (auto-triggers on natural language questions)
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

## Support

Having trouble? Contact your Customer Success Manager or reach out to **support@enterpret.com**.

- [Wisdom MCP Server Setup](https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server)
- [Wisdom User Guide](https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide)
