#!/bin/bash
# generate.sh — Founder Dashboard Generator
# Reads config.json, pulls git data from each repo, generates index.html
# Usage: cd /Users/sarath/dashboard && ./generate.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG="$SCRIPT_DIR/config.json"
OUTPUT="$SCRIPT_DIR/index.html"
GENERATED_AT="$(date '+%Y-%m-%d %H:%M:%S %Z')"

if [ ! -f "$CONFIG" ]; then
  echo "Error: config.json not found at $CONFIG"
  exit 1
fi

# Check for jq
if ! command -v jq &>/dev/null; then
  echo "Error: jq is required. Install with: brew install jq"
  exit 1
fi

# ── Gather git data for each project ──────────────────────────────

PROJECT_COUNT=$(jq '.projects | length' "$CONFIG")
declare -a GIT_BRANCH
declare -a GIT_LAST_DATE
declare -a GIT_LAST_MSG
declare -a GIT_UNCOMMITTED
declare -a GIT_UNTRACKED

for (( i=0; i<PROJECT_COUNT; i++ )); do
  REPO=$(jq -r ".projects[$i].repo" "$CONFIG")

  if [ -d "$REPO/.git" ]; then
    GIT_BRANCH[$i]=$(git -C "$REPO" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    GIT_LAST_DATE[$i]=$(git -C "$REPO" log -1 --format='%ai' 2>/dev/null | cut -d' ' -f1 || echo "no commits")
    GIT_LAST_MSG[$i]=$(git -C "$REPO" log -1 --format='%s' 2>/dev/null | head -c 80 || echo "no commits")
    GIT_UNCOMMITTED[$i]=$(git -C "$REPO" diff --numstat 2>/dev/null | wc -l | tr -d ' ')
    GIT_UNTRACKED[$i]=$(git -C "$REPO" ls-files --others --exclude-standard 2>/dev/null | wc -l | tr -d ' ')
  else
    GIT_BRANCH[$i]="no repo"
    GIT_LAST_DATE[$i]="—"
    GIT_LAST_MSG[$i]="Repository not found"
    GIT_UNCOMMITTED[$i]="—"
    GIT_UNTRACKED[$i]="—"
  fi
done

# ── Compute total revenue ─────────────────────────────────────────

TOTAL_REVENUE=$(jq -r '[.projects[].revenue] | map(gsub("[^0-9]";"")|tonumber) | add' "$CONFIG")
TOTAL_REVENUE="₹$(printf "%'d" "$TOTAL_REVENUE" 2>/dev/null || echo "$TOTAL_REVENUE")"

# ── Generate HTML ─────────────────────────────────────────────────

cat > "$OUTPUT" << 'HTMLHEAD'
<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Founder Dashboard — Sarath</title>
<style>
  :root {
    --bg: #0d1117;
    --surface: #161b22;
    --surface2: #1c2333;
    --border: #30363d;
    --text: #e6edf3;
    --text-dim: #8b949e;
    --accent: #58a6ff;
    --green: #3fb950;
    --amber: #d29922;
    --blue: #58a6ff;
    --red: #f85149;
    --purple: #bc8cff;
  }
  * { margin: 0; padding: 0; box-sizing: border-box; }
  body {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif;
    background: var(--bg);
    color: var(--text);
    line-height: 1.5;
    padding: 1.5rem;
    max-width: 1200px;
    margin: 0 auto;
  }
  a { color: var(--accent); text-decoration: none; }
  a:hover { text-decoration: underline; }

  /* Header */
  .header { margin-bottom: 2rem; }
  .header h1 {
    font-size: 1.5rem;
    font-weight: 600;
    color: var(--text);
    letter-spacing: -0.02em;
  }
  .header .subtitle { color: var(--text-dim); font-size: 0.875rem; margin-top: 0.25rem; }

  /* Summary bar */
  .summary {
    display: flex;
    gap: 1rem;
    margin-bottom: 2rem;
    flex-wrap: wrap;
  }
  .summary-card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 8px;
    padding: 1rem 1.5rem;
    flex: 1;
    min-width: 160px;
  }
  .summary-card .label { font-size: 0.75rem; color: var(--text-dim); text-transform: uppercase; letter-spacing: 0.05em; }
  .summary-card .value { font-size: 1.5rem; font-weight: 700; margin-top: 0.25rem; }
  .summary-card .value.green { color: var(--green); }

  /* Project cards */
  .projects { display: grid; gap: 1.25rem; grid-template-columns: repeat(auto-fit, minmax(340px, 1fr)); margin-bottom: 2rem; }
  .card {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    transition: border-color 0.2s;
  }
  .card:hover { border-color: var(--accent); }
  .card-head { display: flex; align-items: center; gap: 0.75rem; margin-bottom: 0.75rem; flex-wrap: wrap; }
  .card-head h2 { font-size: 1.125rem; font-weight: 600; }
  .badge {
    font-size: 0.6875rem;
    font-weight: 600;
    padding: 0.15rem 0.55rem;
    border-radius: 9999px;
    text-transform: uppercase;
    letter-spacing: 0.04em;
  }
  .badge-live { background: rgba(63,185,80,0.15); color: var(--green); }
  .badge-on-hold { background: rgba(210,153,34,0.15); color: var(--amber); }
  .badge-pre-launch { background: rgba(88,166,255,0.15); color: var(--blue); }

  .meta-row {
    display: flex;
    flex-wrap: wrap;
    gap: 0.5rem 1.25rem;
    font-size: 0.8125rem;
    color: var(--text-dim);
    margin-bottom: 0.75rem;
    padding-bottom: 0.75rem;
    border-bottom: 1px solid var(--border);
  }
  .meta-row span { white-space: nowrap; }
  .meta-row .git-val { color: var(--text); font-family: 'SF Mono', Menlo, monospace; font-size: 0.75rem; }

  .priority-box {
    background: rgba(88,166,255,0.08);
    border-left: 3px solid var(--accent);
    padding: 0.5rem 0.75rem;
    margin-bottom: 0.75rem;
    border-radius: 0 6px 6px 0;
    font-size: 0.8125rem;
  }
  .priority-box strong { color: var(--accent); }

  .blocker-box {
    background: rgba(248,81,73,0.08);
    border-left: 3px solid var(--red);
    padding: 0.5rem 0.75rem;
    margin-bottom: 0.75rem;
    border-radius: 0 6px 6px 0;
    font-size: 0.8125rem;
    color: #ffa198;
  }

  .checklist { list-style: none; padding: 0; }
  .checklist li {
    font-size: 0.8125rem;
    padding: 0.2rem 0;
    padding-left: 1.25rem;
    position: relative;
    color: var(--text-dim);
  }
  .checklist li::before {
    content: '';
    position: absolute;
    left: 0;
    top: 0.55rem;
    width: 10px;
    height: 10px;
    border: 1.5px solid var(--border);
    border-radius: 3px;
  }

  .section-title {
    font-size: 1rem;
    font-weight: 600;
    margin-bottom: 1rem;
    color: var(--text);
    padding-bottom: 0.5rem;
    border-bottom: 1px solid var(--border);
  }

  /* Weekly focus */
  .weekly {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    margin-bottom: 2rem;
  }
  .weekly-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 0.75rem; }
  .week-item {
    background: var(--surface2);
    padding: 0.75rem 1rem;
    border-radius: 8px;
    border: 1px solid var(--border);
  }
  .week-item .week-label { font-size: 0.6875rem; color: var(--purple); text-transform: uppercase; font-weight: 600; letter-spacing: 0.05em; }
  .week-item .week-text { font-size: 0.875rem; margin-top: 0.25rem; }

  /* Other tasks */
  .other-tasks {
    background: var(--surface);
    border: 1px solid var(--border);
    border-radius: 10px;
    padding: 1.25rem;
    margin-bottom: 2rem;
  }
  .task-item { padding: 0.5rem 0; border-bottom: 1px solid var(--border); }
  .task-item:last-child { border-bottom: none; }
  .task-item .task-name { font-weight: 600; font-size: 0.875rem; }
  .task-item .task-note { font-size: 0.8125rem; color: var(--text-dim); }
  .task-item .task-prio {
    font-size: 0.6875rem;
    color: var(--text-dim);
    background: var(--surface2);
    padding: 0.1rem 0.4rem;
    border-radius: 4px;
    margin-left: 0.5rem;
    text-transform: uppercase;
  }

  .footer {
    text-align: center;
    padding: 1.5rem 0;
    font-size: 0.75rem;
    color: var(--text-dim);
    border-top: 1px solid var(--border);
  }
  .footer code {
    background: var(--surface2);
    padding: 0.15rem 0.4rem;
    border-radius: 4px;
    font-family: 'SF Mono', Menlo, monospace;
    font-size: 0.75rem;
  }

  @media (max-width: 600px) {
    body { padding: 1rem; }
    .projects { grid-template-columns: 1fr; }
    .summary { flex-direction: column; }
  }
</style>
</head>
<body>
<div class="header">
  <h1>Founder Dashboard</h1>
HTMLHEAD

# Timestamp line
echo "  <div class=\"subtitle\">Last generated: $GENERATED_AT</div>" >> "$OUTPUT"
echo "</div>" >> "$OUTPUT"

# Summary bar
LIVE_COUNT=$(jq '[.projects[] | select(.status=="live")] | length' "$CONFIG")
cat >> "$OUTPUT" << SUMMARY
<div class="summary">
  <div class="summary-card">
    <div class="label">Total Revenue</div>
    <div class="value green">$TOTAL_REVENUE</div>
  </div>
  <div class="summary-card">
    <div class="label">Projects</div>
    <div class="value">$PROJECT_COUNT</div>
  </div>
  <div class="summary-card">
    <div class="label">Live</div>
    <div class="value" style="color:var(--green)">$LIVE_COUNT</div>
  </div>
</div>
SUMMARY

# Weekly Focus
WEEK1=$(jq -r '.weekly_focus.week1' "$CONFIG")
WEEK2=$(jq -r '.weekly_focus.week2' "$CONFIG")
WEEK3=$(jq -r '.weekly_focus.week3' "$CONFIG")

cat >> "$OUTPUT" << WEEKLY
<div class="weekly">
  <div class="section-title">3-Week Focus Plan</div>
  <div class="weekly-grid">
    <div class="week-item">
      <div class="week-label">Week 1</div>
      <div class="week-text">$WEEK1</div>
    </div>
    <div class="week-item">
      <div class="week-label">Week 2</div>
      <div class="week-text">$WEEK2</div>
    </div>
    <div class="week-item">
      <div class="week-label">Week 3</div>
      <div class="week-text">$WEEK3</div>
    </div>
  </div>
</div>
WEEKLY

# Project cards
echo '<div class="section-title">Projects</div>' >> "$OUTPUT"
echo '<div class="projects">' >> "$OUTPUT"

for (( i=0; i<PROJECT_COUNT; i++ )); do
  NAME=$(jq -r ".projects[$i].name" "$CONFIG")
  URL=$(jq -r ".projects[$i].url" "$CONFIG")
  STATUS=$(jq -r ".projects[$i].status" "$CONFIG")
  REVENUE=$(jq -r ".projects[$i].revenue" "$CONFIG")
  PRIORITY=$(jq -r ".projects[$i].priority" "$CONFIG")
  BLOCKERS=$(jq -r ".projects[$i].blockers" "$CONFIG")

  # Status badge class
  case "$STATUS" in
    live)       BADGE_CLASS="badge-live" ;;
    on-hold)    BADGE_CLASS="badge-on-hold" ;;
    pre-launch) BADGE_CLASS="badge-pre-launch" ;;
    *)          BADGE_CLASS="badge-live" ;;
  esac

  # URL link
  if [ "$URL" = "Not deployed" ]; then
    URL_HTML="<span style=\"color:var(--text-dim)\">Not deployed</span>"
  else
    URL_HTML="<a href=\"$URL\" target=\"_blank\">$URL</a>"
  fi

  cat >> "$OUTPUT" << CARDSTART
<div class="card">
  <div class="card-head">
    <h2>$NAME</h2>
    <span class="badge $BADGE_CLASS">$STATUS</span>
  </div>
  <div style="font-size:0.8125rem;margin-bottom:0.75rem">$URL_HTML</div>
  <div class="meta-row">
    <span>Branch: <span class="git-val">${GIT_BRANCH[$i]}</span></span>
    <span>Last commit: <span class="git-val">${GIT_LAST_DATE[$i]}</span></span>
    <span>Modified: <span class="git-val">${GIT_UNCOMMITTED[$i]}</span></span>
    <span>Untracked: <span class="git-val">${GIT_UNTRACKED[$i]}</span></span>
  </div>
  <div style="font-size:0.75rem;color:var(--text-dim);margin-top:-0.5rem;margin-bottom:0.75rem;font-family:'SF Mono',Menlo,monospace;overflow:hidden;text-overflow:ellipsis;white-space:nowrap">
    ${GIT_LAST_MSG[$i]}
  </div>
  <div style="font-size:0.8125rem;margin-bottom:0.75rem">Revenue: <strong style="color:var(--green)">$REVENUE</strong></div>
  <div class="priority-box"><strong>Priority:</strong> $PRIORITY</div>
CARDSTART

  # Blockers
  if [ -n "$BLOCKERS" ] && [ "$BLOCKERS" != "null" ]; then
    echo "  <div class=\"blocker-box\"><strong>Blocker:</strong> $BLOCKERS</div>" >> "$OUTPUT"
  fi

  # Next actions
  NEXT_COUNT=$(jq ".projects[$i].next | length" "$CONFIG")
  if [ "$NEXT_COUNT" -gt 0 ]; then
    echo '  <ul class="checklist">' >> "$OUTPUT"
    for (( j=0; j<NEXT_COUNT; j++ )); do
      ITEM=$(jq -r ".projects[$i].next[$j]" "$CONFIG")
      echo "    <li>$ITEM</li>" >> "$OUTPUT"
    done
    echo '  </ul>' >> "$OUTPUT"
  fi

  echo '</div>' >> "$OUTPUT"
done

echo '</div>' >> "$OUTPUT"

# Other tasks
OTHER_COUNT=$(jq '.other_tasks | length' "$CONFIG")
if [ "$OTHER_COUNT" -gt 0 ]; then
  echo '<div class="other-tasks">' >> "$OUTPUT"
  echo '  <div class="section-title" style="border-bottom:none;margin-bottom:0.5rem">Other Tasks</div>' >> "$OUTPUT"
  for (( k=0; k<OTHER_COUNT; k++ )); do
    T_NAME=$(jq -r ".other_tasks[$k].name" "$CONFIG")
    T_PRIO=$(jq -r ".other_tasks[$k].priority" "$CONFIG")
    T_NOTE=$(jq -r ".other_tasks[$k].note" "$CONFIG")
    cat >> "$OUTPUT" << TASK
  <div class="task-item">
    <div><span class="task-name">$T_NAME</span><span class="task-prio">$T_PRIO</span></div>
    <div class="task-note">$T_NOTE</div>
  </div>
TASK
  done
  echo '</div>' >> "$OUTPUT"
fi

# Footer
cat >> "$OUTPUT" << 'FOOTER'
<div class="footer">
  Run <code>./generate.sh</code> to refresh git data &middot; Edit <code>config.json</code> to update priorities and notes
</div>
</body>
</html>
FOOTER

echo "Dashboard generated: $OUTPUT"
echo "Open with: open $OUTPUT"
