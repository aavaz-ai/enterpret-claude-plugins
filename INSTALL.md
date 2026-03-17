# Enterpret Customer Insights — Installation Guide

Query customer feedback, analyze patterns, investigate root causes, and generate branded reports — powered by your Wisdom Knowledge Graph.

---

## Install (Claude Code CLI)

**Prerequisites:** Claude Code CLI installed ([install guide](https://docs.anthropic.com/en/docs/claude-code/overview))

### Step 1 — Add the Enterpret marketplace (one-time)

```bash
claude plugin marketplace add https://github.com/aavaz-ai/enterpret-claude-plugins
```

### Step 2 — Install the plugin

```bash
claude plugin install enterpret-customer-insights@enterpret-claude-plugins
```

### Step 3 — Start a new Claude session and run setup

```bash
claude
```

Once inside Claude, type:

```
/enterpret-customer-insights:start
```

You'll be prompted to authenticate via your browser — log in with your Enterpret account. The setup wizard connects to your organization's Knowledge Graph, discovers your data, and configures your profile. Takes about 2 minutes.

> **Note:** When Claude asks to approve the `enterpret-wisdom-mcp` MCP server (connecting to `wisdom-api.enterpret.com`), select **Yes** — this is the connection to your Wisdom Knowledge Graph.

---

## Install (Claude CoWork Desktop App)

1. Open **Settings** > **Plugins** > **Add Marketplace**
2. Paste: `https://github.com/aavaz-ai/enterpret-claude-plugins`
3. Browse the marketplace and install **Enterpret Customer Insights**
4. Start a new session and type `/enterpret-customer-insights:start`

Authentication happens automatically via OAuth — you'll be prompted to log in through your browser on first use.

---

## Commands

| Command | What it does | Example |
|---------|-------------|---------|
| `/enterpret-customer-insights:start` | First-time setup — connect, discover data, configure profile | |
| `/enterpret-customer-insights:find [topic]` | Quick lookup — themes, sentiment, quotes | `/enterpret-customer-insights:find onboarding friction` |
| `/enterpret-customer-insights:analyze [topic]` | Deep analysis — trends, patterns, root causes | `/enterpret-customer-insights:analyze churn drivers` |
| `/enterpret-customer-insights:explore` | Browse your feedback taxonomy interactively | |
| `/enterpret-customer-insights:report [mode]` | Generate output — weekly memo, account brief, exec summary | `/enterpret-customer-insights:report weekly` |

You can also ask questions in plain language — the Wisdom Expert agent responds automatically:

> *"What are customers saying about the new pricing?"*
> *"Show me the top complaints from enterprise accounts this month"*
> *"Why are users churning from the mobile app?"*

---

## Troubleshooting

| Issue | Solution |
|-------|----------|
| `marketplace.json not found` | Update Claude Code CLI to latest (`npm i -g @anthropic-ai/claude-code@latest`) |
| `Unauthorized` or `403` on start | Your Enterpret token expired. Re-run the start command to re-authenticate |
| `Connection refused` | Check internet. MCP server: `https://wisdom-api.enterpret.com/server/mcp` |
| Commands don't appear after install | Start a **new** Claude session — plugins load at session start |
| Wrong organization data | Verify you logged in with the correct Enterpret account |

---

## Support

Contact your Customer Success Manager or email **support@enterpret.com**.

- [Wisdom MCP Server Setup](https://helpcenter.enterpret.com/en/articles/12665166-wisdom-mcp-server)
- [Wisdom User Guide](https://helpcenter.enterpret.com/en/articles/12665509-wisdom-user-guide)
