---
description: "Build a recurring customer feedback digest — choose what matters, preview it, then deliver on a schedule to Slack, email, or wherever your team reads it."
argument-hint: "[setup | run | preview | config]"
---

# /digest

Build and deliver a recurring customer feedback digest from Enterpret's Wisdom
Knowledge Graph. Interactive setup on first run, headless execution for scheduling.

## Pre-Flight

1. Check if `context/organization.json` exists. If not, tell the user to run `/start` first. Stop.
2. Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server. If auth fails, tell the user to run `/start`. Stop.
3. Read `context/organization.json` for org name, slug, and citation base URL.

## Skills (reference during execution, not upfront)

- `wisdom-kg` — read if a query fails or schema details are needed
- `wisdom-slack-digest` — read when executing the digest (run/preview modes)
- `evidence-synthesis` — read if the user wants richer narrative in quotes

## Query Rules (critical)

- Always use `LIMIT` (max 50)
- Count with `COUNT(DISTINCT fi.feedback_record_id)` — never `COUNT(nli)`
- Never use `count` as an alias (reserved word) — use `volume`
- Sentiment values: `"Positive"`, `"Negative"`, `"Neutral"`
- Dates: string comparison on `record_timestamp` (not `date()`)
- Parameter: `cypher_query` for `execute_cypher_query`
- If no results, say so — never fabricate data

## Mode Detection

| Input | Mode | What Happens |
|-------|------|-------------|
| `/digest` (no config exists) | Setup | Interactive wizard |
| `/digest` (config exists) | Run | Execute digest and deliver |
| `/digest setup` | Setup | Force re-enter setup wizard |
| `/digest run` | Run | Execute digest (error if no config) |
| `/digest preview` | Preview | Dry run — show formatted output in chat |
| `/digest config` | Show Config | Display current config and offer to edit |

---

## Setup Mode

A guided, conversational experience that helps the user design a feedback digest
and set up recurring delivery. The flow is: **understand goals → design content →
preview → choose delivery → schedule.**

### Phase 1: Welcome and Context

Start with a warm, clear explanation of what we're building:

> **Let's build your feedback digest**
>
> I'll help you create a recurring customer intelligence briefing — a snapshot
> of what your customers are saying about the topics that matter to you.
>
> Here's how this works:
> 1. **We'll pick your topics** — what feedback themes should this track?
> 2. **I'll show you a preview** — so you can see exactly what the output looks like
> 3. **You'll choose where it goes** — Slack, email, or right here in CoWork
> 4. **We'll put it on autopilot** — recurring delivery on your schedule
>
> Let's start with what matters to you.

### Phase 2: Understand the User's Goal

Ask conversationally — do NOT jump into taxonomy browsing or technical config:

> "**What decisions or conversations does this digest support?**
>
> For example:
> - _'I prep for a weekly product review and need to know what's trending'_
> - _'Our CS team wants to spot account-level issues before they escalate'_
> - _'Leadership wants a pulse on customer sentiment after our last launch'_
>
> Tell me what you're trying to accomplish and I'll suggest what to track."

Based on their answer, infer what topics, granularity, and framing would be most
useful. This context shapes everything downstream.

### Phase 3: Design Topics

Use the user's stated goal to suggest specific topics. **Do NOT show L1 categories
as the starting point** — they're too broad for a digest. Instead:

**Option A (preferred): Infer from context.** If the user said something like
"we just launched a redesign and want to track reactions," use `search_knowledge_graph`
with relevant terms to find matching themes at the L2/L3/Theme level:

```
search_knowledge_graph with: "redesign", "new UI", "layout change", etc.
```

Present the matching themes as suggestions:

> "Based on what you described, here are themes in your feedback that look relevant:
>
> | # | Theme | Volume (30d) | Sentiment |
> |---|-------|-------------|-----------|
> | 1 | {specific theme} | {vol} | {ratio} |
> | 2 | {specific theme} | {vol} | {ratio} |
> | ... | ... | ... | ... |
>
> Want to track all of these, or pick specific ones? You can also add custom
> topics not on this list."

**Option B (fallback): User isn't sure.** If the user doesn't have a clear goal,
THEN offer to explore the taxonomy — but drill into L2/L3, not L1:

> "Let me show you what's generating the most feedback right now."

```cypher
MATCH (t:Theme)<-[:HAS_THEME]-(cft:CustomerFeedbackTags)<-[:HAS_TAGS]-(fi:FeedbackInsight)
  -[:HAS_SENTIMENT]->(sp:SentimentPrediction),
  (fi)<-[:SUMMARIZED_BY]-(nli:NaturalLanguageInteraction)
WHERE nli.record_timestamp >= "{30_days_ago}"
RETURN t.name AS theme, COUNT(DISTINCT fi.feedback_record_id) AS volume,
  SUM(CASE WHEN sp.label = 'Negative' THEN 1 ELSE 0 END) AS negative
ORDER BY volume DESC
LIMIT 15
```

For each topic the user selects, build a keywords list with variations and confirm:

> "For **{topic}**, I'll search for: {keyword1}, {keyword2}, {keyword3}.
> Does that cover it, or should I add more variations?"

**Most digests work best with 2-4 focused topics.** Gently steer if the user picks
too many: "That's 7 topics — the digest might get long. Want to prioritize the
top 3-4 and save the rest for a separate one?"

### Phase 4: Design Structure (optional breakdowns)

Only ask about breakdowns if the user's goal suggests they need dimensional slicing.
If they said "I just want to know what's trending," skip breakdowns entirely.

If relevant (e.g., "I need to see this by region for our geo leads"):

> "**Want to slice the results by any dimensions?**
>
> Based on your data, I can break things down by:"

Call `get_schema` and show only dimensions that exist:

> | # | Dimension | Example Values |
> |---|-----------|---------------|
> | 1 | Region | EMEA, AMER, APAC |
> | 2 | Segment | Enterprise, Mid-Market, SMB |
> | 3 | Customer stage | Implementation, Adoption, Renewal |
> | 4 | No breakdown | Just totals per topic |
>
> "Pick 1-2 dimensions, or skip this for a simpler digest."

### Phase 5: Preview the Digest

**This is the moment of truth.** Run the actual queries and show a fully formatted
preview in chat. Format it to approximate how it will look when delivered — use
emoji, bold, blockquotes, the works.

Present it cleanly:

> "Here's a preview of your digest based on the last 30 days of data:"

Then render the digest using the formatting rules from the `wisdom-slack-digest`
skill. In chat, render emoji characters directly (not `:emoji_name:` codes).

After the preview, ask:

> "**How does that look?** I can:
> - Adjust the topics or keywords
> - Add or remove breakdowns
> - Change the number of quotes shown
> - Tweak the title or formatting
>
> Or if it looks good, let's set up delivery."

Iterate until the user is satisfied. Only proceed when they signal approval.

### Phase 6: Choose Delivery Channel

**Detect available delivery mechanisms** by checking for MCP tools in the current
session. Present only options the user actually has available:

Check for these tool patterns:
- **Slack**: `slack_send_message` or similar Slack MCP tools
- **Email**: `gmail_send_email`, `send_email`, or similar email MCP tools
- **Other connectors**: Any MCP that supports message sending (Teams, Discord, etc.)
- **CoWork**: Always available — the digest runs in chat

Build the options list dynamically:

> "**Where should this digest go?**"

Show only detected options, for example:

> | # | Channel | Status |
> |---|---------|--------|
> | 1 | **Slack** | Connected — ready to use |
> | 2 | **CoWork** | Always available — runs in your Claude session |
>
> "Pick a channel. If you want to add more options later (email, Teams, etc.),
> connect the MCP server and run `/digest config`."

If the user picks Slack, help them find the channel:

> "Which Slack channel? Give me the name (e.g., #customer-insights) and I'll
> look up the ID."

Use Slack tools to search and confirm the channel.

If the user picks CoWork, note that the digest will just run in their Claude session
when scheduled — no external posting needed.

If NO delivery connectors are detected beyond CoWork:

> "Right now you only have CoWork available for delivery. The digest will run in
> your Claude session. To add Slack, email, or other channels, connect the
> relevant MCP server in Settings > MCP Servers."

### Phase 7: Write Config

Write `context/digest-config.md` with all the user's choices. Include:
- Topics with keywords
- Breakdowns (if any)
- Delivery channel type and destination (channel ID, email, or "cowork")
- Display preferences
- Digest title

Confirm concisely:

> "Digest configured. Here's your setup:
>
> | Setting | Value |
> |---------|-------|
> | Topics | {topic names} |
> | Breakdowns | {breakdown names or 'None'} |
> | Delivery | {channel type} → {destination} |
> | Quotes/topic | {N} |

### Phase 8: Deliver and Schedule

Offer to run it now as a live test:

> "**Want to send it now as a test?** I'll post the digest to {destination} so you
> can see exactly how it looks. Then we can set up the recurring schedule."

If they say yes, execute the digest (Run Mode) and deliver it. After delivery:

> "**Posted to {destination}** — go take a look and make sure it reads well!
>
> When you're ready, want to set up a recurring schedule? I can run this
> automatically — for example, every Monday at 9am."

Wait for the user to come back after checking. Do NOT immediately jump to scheduling.

If they want to schedule:

> "**When should this run?**
>
> Common cadences:
> - Weekly on Monday at 9:00 AM
> - Weekly on Wednesday at 9:00 AM
> - Daily at 8:00 AM
> - Custom (describe your schedule)
>
> Note: Your computer needs to be awake with Claude Desktop open for scheduled tasks."

Guide them through `/schedule`:

> "To set up the recurring schedule:
> 1. Run `/schedule` in any Claude session
> 2. Set the prompt to: **Run /digest run**
> 3. Set frequency to: **{their cadence}**
> 4. Save
>
> All set! Your digest will run automatically and post to {destination}."

---

## Run Mode

Execute the configured digest and deliver it. Load the `wisdom-slack-digest`
skill and follow its execution flow.

If `context/digest-config.md` does not exist:

> "No digest configured yet. Run `/digest setup` to create one, or just run
> `/digest` and I'll walk you through it."

---

## Preview Mode

Same as Run Mode, but display the formatted digest in chat instead of delivering
to the external channel.

After showing the preview:

> "This is what would be delivered to {destination}. Want to:
> 1. **Send it** — deliver to {destination} now
> 2. **Adjust** — tweak topics, breakdowns, or formatting
> 3. **Done** — just wanted to see it"

---

## Show Config Mode

Read and display `context/digest-config.md`:

> **Current Digest Configuration**
>
> | Setting | Value |
> |---------|-------|
> | Title | {digest_title} |
> | Topics | {topic names} |
> | Breakdowns | {breakdown names or 'None'} |
> | Delivery | {channel} → {destination} |
> | Quotes/topic | {N} |
>
> "Want to change anything? I can update individual settings, or run `/digest setup`
> to start fresh."

For single-setting changes, update only that section of `context/digest-config.md`.

---

## Edge Cases

**Quiet period (no results):**
Deliver a short message: "No feedback matching your configured topics in this period.
This could mean a data gap or a genuinely quiet period."

**Delivery channel unavailable at run time:**
If the configured MCP is disconnected when the scheduled run fires, save the digest
to a local file and note: "Couldn't reach {channel} — digest saved locally. Check
your MCP connection."

**Config references stale schema properties:**
If a query fails on a breakdown property, inform and suggest `/digest setup`.

**User wants multiple delivery channels:**
Support this — write multiple delivery entries in config. Execute delivery to each
in sequence.
