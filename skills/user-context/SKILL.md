---
name: user-context
description: >
  Defines the default user persona for this plugin — a Product Manager
  focused on customer experience and product operations. This context
  shapes how reports are framed, what metrics matter, and what language is used.
  Users can customize their persona by editing the "Your Profile" section below.
version: 5.0.0
---

# User Context — Product Manager

This skill provides Claude with context about who is using the plugin, so that reports, investigations, and recommendations are tailored to the right audience.

## Loading User Preferences

Before applying defaults, check for a settings file:
1. Look for `.claude/enterpret-customer-insights.local.md` in the project directory
2. If found, parse YAML frontmatter for user preferences
3. Override defaults below with any values found in the settings file
4. The markdown body of the settings file provides additional context

## Default Persona

You are assisting a **Product Manager** who works across customer experience, product operations, and support. Here is what you should know about them:

### Role & Responsibilities

- **Title:** Product Manager
- **Company:** Read from `context/organization.json` → `name` (discovered during onboarding)
- **Scope:** Owns customer-facing product surfaces and support operations
- **Key activities:**
  - Analyze customer feedback to identify product friction and improvement opportunities
  - Track satisfaction trends and diagnose root causes of satisfaction drops
  - Produce weekly VOC (Voice of Customer) reports for leadership and regional teams
  - Investigate customer-reported issues with cross-functional teams
  - Monitor support patterns to improve self-service and routing accuracy
  - Assess impact of product changes, policy updates, and feature launches on CX metrics

### What They Care About

- **Top-line metrics:** CSAT, DSAT rate, support volume trends, first-contact resolution, escalation rates
- **Operational cadence:** Weekly VOC reporting, satisfaction diagnosis, spike detection
- **Cross-functional needs:** Handoff reports for engineering, escalation briefs for leadership, impact assessments for policy changes
- **Data depth:** Not just counts — they want themed groupings, ticket-level evidence, root cause hypotheses, and citation links back to source data

### Communication Preferences

- **Audience-aware:** Reports may go to leadership (executive summary, high-level), engineering (technical detail, ticket IDs), or CX ops (operational, actionable)
- **Evidence-based:** Always cite specific data. Never make unsupported claims.
- **Structured:** Use clear headings, ranked lists, and tables. Lead with the most important finding.
- **Concise:** Get to the point. Flag what changed and why it matters.

---

## Your Profile (Customizable)

> **To customize:** Edit the fields below to match your actual role. Claude will use this information to tailor its outputs.

```yaml
name: ""                    # Your name (leave blank for default)
role: "Product Manager"     # Your title/role
team: "Product / CX"       # Your team or department
focus: ""                   # What decisions you make with insights (e.g., "prioritize roadmap, debug issues")
output_style: "summary"     # How you prefer insights: "summary", "detailed", "report"
brand_colors:               # Custom brand colors for reports
  primary: ""               # Primary color hex (e.g., "#1B2A4A")
  accent: ""                # Accent color hex (e.g., "#2AABB3")
company_name: ""            # Your company name (overrides org discovery)
language: "en"              # Preferred output language
```

## How Claude Uses This Context

1. **Focus-aware analysis:** The `focus` field tells Claude what decisions the user makes. If they prioritize roadmap, lead with urgency signals. If they debug issues, lead with severity and blast radius. If they prep for leadership, lead with executive summary.
2. **Output style:** `summary` = concise chat output (default). `detailed` = full analysis with all evidence. `report` = formatted document with charts and branding.
3. **Topic suggestions:** After querying the KG, Claude can suggest topics relevant to the user's team and focus areas — e.g., if team is "Payments", suggest payment-related themes.
4. **Language and tone:** Professional, data-driven, structured. No marketing fluff.
5. **Recommendations:** Framed as product decisions ("Consider updating the flow UX") rather than abstract findings ("Users are frustrated").
6. **Citations:** Every claim links back to Enterpret dashboard records so the user can verify and share with stakeholders.
7. **Brand and output customization:** When `brand_colors` or `company_name` are set, reports use the user's branding.

## Persona Adaptation Rules

- If the user says "I'm on the compliance team" or similar, shift framing accordingly
- If the user says "this is for my VP" or "for leadership," elevate to executive summary format
- If the user specifies a region, default all queries to that region filter unless overridden
- If the user switches language, respond in that language
- Always ask "Who is the audience for this?" during the Scope phase of reports
