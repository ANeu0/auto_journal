#!/usr/bin/env bash
set -euo pipefail

# Resolve paths (Git Bash / MSYS2 friendly)

sourceDir="$HOME/Documents/Obsidian_Vault/Obsidian_Vault/Templates/Planning"
targetDir="$HOME/Documents/Obsidian_Vault/Obsidian_Vault/$(date +%Y)"

DailyTemplate="$sourceDir/Daily.md"
WeeklyTemplate="$sourceDir/Weekly.md"
MonthlyTemplate="$sourceDir/Monthly.md"

mkdir -p "$targetDir"

# ------------------------------
# Helpers
# ------------------------------

# Extract a section starting at an exact header until --- or EOF
extract_section() {
  local header="$1"
  local file="$2"

  awk -v h="$header" '
    $0 == h { c=1 }
    c { print }
    /^---$/ && c { exit }
  ' "$file"
}

# Replace file content safely (no in-place editing)
replace_in_file() {
  local file="$1"
  shift

  local tmp
  tmp="$(mktemp)"

  sed "$@" "$file" > "$tmp"
  mv "$tmp" "$file"
}

# Inject content at placeholder safely
inject_section() {
  local placeholder="$1"
  local content="$2"
  local file="$3"

  local tmp_content tmp_out
  tmp_content="$(mktemp)"
  tmp_out="$(mktemp)"

  printf "%s\n" "$content" > "$tmp_content"

  sed "/$placeholder/{
    r $tmp_content
    d
  }" "$file" > "$tmp_out"

  mv "$tmp_out" "$file"
  rm "$tmp_content"
}

# ------------------------------
# Monthly note (last day of month)
# ------------------------------

MonthlyFileName="$targetDir/$(date +%B-%Y).md"

is_last_day=false
if date -d tomorrow >/dev/null 2>&1; then
  [[ "$(date -d tomorrow +%d)" == "01" ]] && is_last_day=true
else
  [[ "$(date -v+1d +%d)" == "01" ]] && is_last_day=true
fi

if  $is_last_day && [ ! -e "$MonthlyFileName" ]; then
  echo "Creating monthly note"

  cp "$MonthlyTemplate" "$MonthlyFileName"

  # Previous month goals
  if date -d 'last month' >/dev/null 2>&1; then
    LastMonthFileName="$targetDir/$(date -d 'last month' +%B-%Y).md"
  else
    LastMonthFileName="$targetDir/$(date -v-1m +%B-%Y).md"
  fi

  if [ -e "$LastMonthFileName" ]; then
    last_month_goals="$(extract_section "### Monthly Goals & Habits" "$LastMonthFileName")"
    inject_section "{{LASTMONTH_GOAL}}" "$last_month_goals" "$MonthlyFileName"
  fi

  replace_in_file "$MonthlyFileName" \
    -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
    -e "s/{{MONTH}}/$(date +%B)/g" \
    -e "s/{{YEAR}}/$(date +%Y)/g"
fi

# ------------------------------
# Weekly note
# ------------------------------
weekly_filename="$targetDir/$(date +%Y-W%V).md"
week_starting_day="7" #Sunday
if [[ "$(date +%u)" == $week_starting_day ]] && [ ! -e "$weekly_filename" ]; then
  echo "Creating weekly note"

  cp "$WeeklyTemplate" "$weekly_filename"

  # Current month goals
  if [ -e "$MonthlyFileName" ]; then
    current_month_goals="$(extract_section "### Monthly Goals & Habits" "$MonthlyFileName")"
    inject_section "{{CURRENTMONTH_GOAL}}" "$current_month_goals" "$weekly_filename"
  fi

  # Template last-week goals
  last_week_goals="$(extract_section "## {{YEAR}}--W{{WEEK_NUM}} Goals" "$WeeklyTemplate")"
  inject_section "{{LASTWEEK_GOAL}}" "$last_week_goals" "$weekly_filename"

  replace_in_file "$weekly_filename" \
    -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
    -e "s/{{MONTH}}/$(date +%B)/g" \
    -e "s/{{YEAR}}/$(date +%Y)/g" \
    -e "s/{{WEEK_NUM}}/$(date +%V)/g"
fi

# ------------------------------
# Daily note
# ------------------------------

today_fileName="$targetDir/$(date +%Y-%m-%d).md"

if [ ! -e "$today_fileName" ]; then
  echo "Creating daily note"

  cp "$DailyTemplate" "$today_fileName"

  week_num="$(date +%V)"
  year="$(date +%Y)"
  weekly_file="$targetDir/$year-W$week_num.md"

  if [ -e "$weekly_file" ]; then
    weekly_goals="$(extract_section "## $year--W$week_num Goals" "$weekly_file")"
    inject_section "{{WEEKLY_GOAL}}" "$weekly_goals" "$today_fileName"
  fi

  replace_in_file "$today_fileName" \
    -e "s/{{DATE}}/$(date +%Y-%m-%d)/g" \
    -e "s/{{MONTH}}/$(date +%A)/g" \
    -e "s/{{YEAR}}/$(date +%Y)/g"
fi
