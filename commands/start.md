---
description: "First-time setup — connect to the Wisdom Knowledge Graph, discover your data landscape, set up your profile, and explore your Adaptive Taxonomy."
argument-hint: ""
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

1. Load the `onboarding` skill — it contains the full setup, auto-discovery, and data landscape tour flow.

2. **Check connection status:**
   - Call `get_organization_details` from the `enterpret-wisdom-mcp` MCP server.
   - If it fails with an auth error → run Part 1 (Connection Guide) from the onboarding skill.
     - If auth continues to fail: "Having trouble connecting? Your Customer Success Manager can help, or reach out to **support@enterpret.com** — they'll get you sorted quickly."
   - If it succeeds → skip to step 3.

3. **Check for existing context:**
   - If `context/organization.json` exists, tell the user: "Welcome back! You're connected to **{name}**. Run `/explore` to browse your Adaptive Taxonomy or `/find [topic]` to start querying."
   - Offer: "Want to refresh your data landscape? (This re-discovers your taxonomy, sources, and volumes.)"
   - If they say yes, delete `context/organization.json` and proceed to step 4.
   - If `context/organization.json` does not exist, proceed to step 4.

4. **Run auto-discovery** — Part 2 from the onboarding skill. This queries:
   - Organization details (name, slug)
   - Feedback sources and channels (where your data comes from)
   - Total feedback volume
   - Adaptive Taxonomy L1 categories
   - Theme categories (insight types)

   Save all results to `context/organization.json`.

5. **Set up user profile:**

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

6. **Run data landscape and taxonomy tour** — Part 3 from the onboarding skill. Always offer the tour on first setup.

   **IMPORTANT:** Before showing the Adaptive Taxonomy, first present the data landscape overview (sources, channels, total volume) so the user understands what data feeds into the taxonomy. Then show the taxonomy.

7. **Suggest first action based on user profile:**

   After the tour, use the user's stated role, team, and focus to suggest a personalized first action. Examples:

   - If focus mentions "roadmap" or "prioritize" → "Based on your focus on roadmap prioritization, try `/analyze {top L1 category}` to see what's driving the most customer feedback."
   - If focus mentions "debug" or "issues" or "bugs" → "Since you focus on debugging customer issues, try `/rootcause` to scan for emerging problems."
   - If focus mentions "leadership" or "executive" or "reviews" → "For your leadership reviews, `/brief exec` gives you a ready-to-share executive summary."
   - If focus mentions "account" or "customer health" → "To monitor account health, try `/brief {account name}` for an account-specific intelligence brief."
   - Default: "Try `/find {user's team or top L1 category}` to see what customers are saying about your area."

8. **Close with clear end-of-onboarding signal:**

> ---
>
> **Setup complete!** You're connected to **{org name}** with {N} feedback sources and {total volume} insights ready to explore.
>
> Here are your commands — pick the one that matches what you need:
>
> | Command | What It Does |
> |---------|-------------|
> | `/find [topic]` | Quick lookup — what are customers saying about X? |
> | `/analyze [topic]` | Deep analysis with trends, subthemes, and patterns |
> | `/rootcause [issue]` | Investigate an issue — severity, blast radius, root cause |
> | `/explore` | Browse your Adaptive Taxonomy interactively |
> | `/brief` | Shareable summary — weekly, account, or executive |
> | `/report` | Generate a branded report (docx/pptx/html) |
>
> {Personalized suggestion from step 7}
>
> Questions or issues? Your CSM is your best resource, or reach out to **support@enterpret.com** anytime.
