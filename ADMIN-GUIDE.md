# Admin Deployment Guide

Deploy the Enterpret Customer Insights plugin to every Claude user in your organization — works across both Claude Code (CLI) and Claude Cowork.

## Prerequisites

- **Claude organization admin** access
- An active **Enterpret** account — each user will authenticate with their own Enterpret credentials on first run

## Option A: Managed Settings (Recommended)

Add the following to your organization's managed `.claude/settings.json`. This automatically installs the plugin for every user on their next Claude session.

```json
{
  "extraKnownMarketplaces": {
    "enterpret-plugins": {
      "source": {
        "source": "github",
        "repo": "aavaz-ai/enterpret-claude-plugins"
      }
    }
  },
  "enabledPlugins": {
    "enterpret-customer-insights@enterpret-plugins": true
  }
}
```

### Where to set managed settings

- **Claude for Work (console.anthropic.com):** Organization Settings → Developer → Managed Settings
- **Claude Code CLI:** Distribute via your organization's config management (MDM, dotfiles repo, etc.)

## Option B: Manual Install (Individual Teams)

**Claude Code (CLI):**

```bash
claude plugin marketplace add aavaz-ai/enterpret-claude-plugins
claude plugin install enterpret-customer-insights@enterpret-plugins
```

**Claude Cowork:**

1. Open the **Customize** menu (left sidebar)
2. Click **Browse plugins**
3. Search for "Enterpret Customer Insights"
4. Click **Install**

## What Users Experience

On their first session after installation, users see an automatic onboarding flow:

1. The plugin detects it's a first-time session
2. It triggers the `/start` command automatically
3. The user authenticates with their Enterpret account (OAuth)
4. Their organization's taxonomy and feedback structure are discovered
5. A user profile is created with sensible defaults

Subsequent sessions load instantly with full context.

## Updating the Plugin

When we release a new version, users get the update automatically on their next session. If you need to force an immediate update:

```bash
claude plugin update enterpret-customer-insights@enterpret-plugins
```

Or update the marketplace:

```bash
claude plugin marketplace update enterpret-plugins
```

## Troubleshooting

### "MCP server not responding"

The Wisdom MCP server requires an active Enterpret account. Verify the user has access at [enterpret.com](https://enterpret.com).

### "Organization context not found"

Run `/start` to re-initialize the connection. This re-discovers the organization's taxonomy and feedback structure.

### "Plugin not appearing for users"

1. Verify the managed settings JSON is correctly formatted
2. Check that `enabledPlugins` uses the exact key: `enterpret-customer-insights@enterpret-plugins`
3. Users may need to restart their Claude session

### Need help?

Contact your Customer Success Manager or email **support@enterpret.com**.
