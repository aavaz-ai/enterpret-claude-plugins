# HTML Report Format — Self-Contained Interactive Report

This file provides the template and patterns for generating self-contained HTML reports with embedded Chart.js charts. Reports are single-file, print-optimized, and work offline (except for CDN-loaded Chart.js).

---

## HTML Template Scaffold

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{{REPORT_TITLE}} — {{ORG_NAME}}</title>
  <script src="https://cdn.jsdelivr.net/npm/chart.js@4"></script>
  <style>
    :root {
      --color-primary: {{BRAND.colors.primary}};
      --color-accent: {{BRAND.colors.accent}};
      --color-accent-light: {{BRAND.colors.accentLight}};
      --color-text: {{BRAND.colors.text}};
      --color-text-secondary: {{BRAND.colors.textSecondary}};
      --color-border: {{BRAND.colors.border}};
      --color-table-header: {{BRAND.colors.tableHeaderBg}};
      --color-alt-row: #{{BRAND.colors.tableAltRowBg}};
      --color-positive: {{BRAND.colors.sentimentPositive}};
      --color-negative: {{BRAND.colors.sentimentNegative}};
      --color-neutral: {{BRAND.colors.sentimentNeutral}};
      --font-family: {{BRAND.typography.fontFamily}}, sans-serif;
    }

    * { margin: 0; padding: 0; box-sizing: border-box; }

    body {
      font-family: var(--font-family);
      color: var(--color-text);
      line-height: 1.6;
      max-width: 900px;
      margin: 0 auto;
      padding: 2rem;
      background: #FFFFFF;
    }

    /* Header */
    .report-header {
      border-bottom: 3px solid var(--color-primary);
      padding-bottom: 1rem;
      margin-bottom: 2rem;
    }
    .report-header h1 {
      font-size: 2rem;
      color: var(--color-primary);
      margin-bottom: 0.25rem;
    }
    .report-header .subtitle {
      color: var(--color-text-secondary);
      font-size: 1rem;
    }

    /* Executive Summary */
    .exec-summary {
      border-left: 4px solid var(--color-accent);
      padding: 1rem 1.5rem;
      margin: 1.5rem 0;
      background: var(--color-accent-light);
      border-radius: 0 4px 4px 0;
    }
    .exec-summary ul { list-style: none; padding: 0; }
    .exec-summary li {
      padding: 0.4rem 0;
      border-bottom: 1px solid rgba(0,0,0,0.05);
    }
    .exec-summary li:last-child { border-bottom: none; }

    /* Section headings */
    h2 {
      color: var(--color-primary);
      font-size: 1.4rem;
      margin: 2rem 0 1rem;
      padding-bottom: 0.3rem;
      border-bottom: 1px solid var(--color-border);
    }
    h3 {
      color: var(--color-text);
      font-size: 1.1rem;
      margin: 1.5rem 0 0.5rem;
    }

    /* Tables */
    table {
      width: 100%;
      border-collapse: collapse;
      margin: 1rem 0;
      font-size: 0.9rem;
    }
    thead th {
      background: #{{BRAND.colors.tableHeaderBg}};
      color: #{{BRAND.colors.tableHeaderText}};
      padding: 0.6rem 0.8rem;
      text-align: left;
      font-weight: 600;
    }
    tbody td {
      padding: 0.5rem 0.8rem;
      border-bottom: 1px solid var(--color-border);
    }
    tbody tr:nth-child(even) {
      background: var(--color-alt-row);
    }
    tbody tr:hover {
      background: var(--color-accent-light);
    }

    /* Charts */
    .chart-container {
      position: relative;
      margin: 1.5rem 0;
      max-width: 100%;
    }
    .chart-container canvas {
      max-width: 100%;
    }
    .chart-caption {
      text-align: center;
      font-size: 0.85rem;
      color: var(--color-text-secondary);
      font-style: italic;
      margin-top: 0.5rem;
    }

    /* Sentiment badges */
    .sentiment-badge {
      display: inline-block;
      padding: 0.15rem 0.5rem;
      border-radius: 12px;
      font-size: 0.8rem;
      font-weight: 600;
      color: white;
    }
    .sentiment-positive { background: var(--color-positive); }
    .sentiment-negative { background: var(--color-negative); }
    .sentiment-neutral { background: var(--color-neutral); }

    /* Verbatim quotes */
    .verbatim {
      border-left: 3px solid var(--color-border);
      padding: 0.5rem 1rem;
      margin: 0.8rem 0;
      font-style: italic;
      color: var(--color-text);
    }
    .verbatim-meta {
      font-style: normal;
      font-size: 0.85rem;
      color: var(--color-text-secondary);
      margin-top: 0.3rem;
    }
    .verbatim-meta a {
      color: var(--color-accent);
      text-decoration: none;
    }
    .verbatim-meta a:hover {
      text-decoration: underline;
    }

    /* Recommendations */
    .recommendation {
      display: flex;
      gap: 1rem;
      margin: 0.8rem 0;
      padding: 1rem;
      background: #F8F9FA;
      border-radius: 4px;
    }
    .recommendation .priority {
      display: inline-block;
      padding: 0.2rem 0.6rem;
      border-radius: 4px;
      font-size: 0.75rem;
      font-weight: 700;
      color: white;
      text-transform: uppercase;
      white-space: nowrap;
      height: fit-content;
    }
    .priority-high { background: var(--color-negative); }
    .priority-medium { background: var(--color-accent); }
    .priority-low { background: var(--color-neutral); }

    /* Footer */
    .report-footer {
      margin-top: 3rem;
      padding-top: 1rem;
      border-top: 1px solid var(--color-border);
      display: flex;
      justify-content: space-between;
      align-items: center;
      font-size: 0.8rem;
      color: var(--color-text-secondary);
    }
    .report-footer a {
      color: var(--color-accent);
      text-decoration: none;
    }

    /* Print styles */
    @media print {
      body { max-width: 100%; padding: 1rem; }
      .chart-container { page-break-inside: avoid; }
      table { page-break-inside: avoid; }
      h2 { page-break-after: avoid; }
      .recommendation { page-break-inside: avoid; }
      a[href]:after { content: none; }
    }
  </style>
</head>
<body>

  <div class="report-header">
    <h1>{{REPORT_TITLE}}</h1>
    <p class="subtitle">{{DATE_RANGE}} | {{REGION}} | {{SCOPE}}</p>
  </div>

  <div class="exec-summary">
    <h2 style="border:none;margin:0 0 0.5rem;padding:0;">Executive Summary</h2>
    <ul>
      <!-- {{EXEC_SUMMARY_ITEMS}} -->
      <li>Key finding 1</li>
      <li>Key finding 2</li>
    </ul>
  </div>

  <!-- {{REPORT_SECTIONS}} -->
  <!-- Sections are generated dynamically based on report type -->

  <div class="report-footer">
    <span>Powered by <a href="https://enterpret.com">Enterpret</a> | via Claude Code</span>
    <span>Generated {{GENERATION_DATE}}</span>
  </div>

  <script>
    // Chart.js initialization
    // Charts are defined inline for each chart-container with a <canvas> element
    // Example:
    //
    // const ctx = document.getElementById('chart-themes').getContext('2d');
    // new Chart(ctx, {
    //   type: 'bar',
    //   data: { labels: [...], datasets: [...] },
    //   options: { ... }
    // });
    //
    // Use BRAND colors from CSS variables via getComputedStyle
    const style = getComputedStyle(document.documentElement);
    const COLORS = {
      primary: style.getPropertyValue('--color-primary').trim(),
      accent: style.getPropertyValue('--color-accent').trim(),
      positive: style.getPropertyValue('--color-positive').trim(),
      negative: style.getPropertyValue('--color-negative').trim(),
      neutral: style.getPropertyValue('--color-neutral').trim()
    };

    // {{CHART_SCRIPTS}}
  </script>

</body>
</html>
```

---

## Component Patterns

### Data Table

```html
<table>
  <thead>
    <tr>
      <th>Rank</th>
      <th>Theme</th>
      <th>Volume</th>
      <th>WoW</th>
      <th>Sentiment</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>1</td>
      <td>Theme Name</td>
      <td>12,345</td>
      <td>↑ 15%</td>
      <td><span class="sentiment-badge sentiment-negative">72% Negative</span></td>
    </tr>
  </tbody>
</table>
```

### Interactive Chart

```html
<div class="chart-container">
  <canvas id="chart-themes" width="720" height="400"></canvas>
  <p class="chart-caption">Top 10 Themes by Volume</p>
</div>

<script>
new Chart(document.getElementById('chart-themes'), {
  type: 'bar',
  data: {
    labels: ['Theme 1', 'Theme 2', ...],
    datasets: [{
      data: [1234, 5678, ...],
      backgroundColor: COLORS.primary,
      borderRadius: 4
    }]
  },
  options: {
    indexAxis: 'y',
    plugins: { legend: { display: false } },
    scales: {
      x: { grid: { color: 'rgba(0,0,0,0.06)' } },
      y: { grid: { display: false } }
    }
  }
});
</script>
```

### Verbatim Quote

```html
<div class="verbatim">
  "Customer feedback quote text here..."
  <div class="verbatim-meta">
    — 2026-03-01 &nbsp;
    <a href="{{CITATION_BASE_URL}}{{RECORD_ID}}">View in Enterpret</a>
  </div>
</div>
```

### Recommendation Card

```html
<div class="recommendation">
  <span class="priority priority-high">HIGH</span>
  <div>
    <strong>Action item headline</strong>
    <p>Detailed rationale and expected impact.</p>
  </div>
</div>
```

### Sentiment Donut Chart

```html
<div class="chart-container">
  <canvas id="chart-sentiment" width="400" height="400"></canvas>
</div>

<script>
new Chart(document.getElementById('chart-sentiment'), {
  type: 'doughnut',
  data: {
    labels: ['Positive', 'Negative', 'Neutral'],
    datasets: [{
      data: [45, 35, 20],
      backgroundColor: [COLORS.positive, COLORS.negative, COLORS.neutral],
      borderWidth: 2,
      borderColor: '#FFFFFF'
    }]
  },
  options: {
    cutout: '55%',
    plugins: {
      legend: { position: 'bottom' }
    }
  }
});
</script>
```

---

## Fallback: Base64 PNG Charts

If Chart.js CDN is unavailable or the report must work fully offline, embed charts as base64 PNG images instead:

```html
<div class="chart-container">
  <img src="data:image/png;base64,{{CHART_BASE64}}" alt="Top Themes by Volume" style="max-width:100%;">
  <p class="chart-caption">Top 10 Themes by Volume</p>
</div>
```

Generate the PNG using the same `generateChart()` function from `chart-patterns.md`, then base64-encode the buffer.

---

## Key Rules

1. **Self-contained** — Single HTML file, no external dependencies except Chart.js CDN
2. **Responsive** — Works on desktop and mobile; `max-width: 900px` centered layout
3. **Print-optimized** — `@media print` rules prevent chart/table splitting across pages
4. **CSS variables** — All brand colors via `:root` variables, easily swappable
5. **Citation links** — All verbatim quotes link to `{citationBaseUrl}{record_id}`
6. **Fallback** — If Chart.js CDN fails, charts degrade to static base64 PNGs
7. **File naming** — `{report_type}_{region}_{date}.html`
