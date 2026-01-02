#!/bin/bash
set -euo pipefail # turn on “strict mode” for Bash so the script fails fast instead of silently doing the wrong thing
echo ""

# --------------------------------------------
# findport.sh v2.0
# Searches for a port inside docker-compose.yml files
# ONLY one directory deep (./<dir>/docker-compose.yml),
# with a live progress bar.
# Excludes ./portainer/ (top-level) if present.
#
# Usage: ./findport.sh <port_number>
# --------------------------------------------

# Check if a port number was provided as an argument
if [[ $# -ne 1 ]]; then
  echo "Usage: $0 <port_number>"
  echo ""
  exit 1
fi

PORT="$1"
REGEX="(^|[^0-9])${PORT}([^0-9]|$)"

# INPUT VALIDATION [BEGIN] ---------------------------------------
# Validate: digits only
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo "Usage: $0 <port_number>"
  echo "Error: port must be a number between 1 and 65535."
  echo ""
  exit 1
fi

# Validate: range 1..65535
if (( PORT < 1 || PORT > 65535 )); then
  echo "Error: port must be between 1 and 65535."
  echo "Usage: $0 <port_number>"
  exit 1
fi
# INPUT VALIDATION [END] ------------------------------------------

# Collect docker-compose.yml files exactly one directory deep:
#   i.e. ./something/docker-compose.yml
mapfile -d '' FILES < <(
  find . \
    -mindepth 2 -maxdepth 2 \
    -type f -name "docker-compose.yml" \
    -not -path "./portainer/*" \
    -print0
)

# Returning no results (if there are no docker-compose.yml files at all)
TOTAL=${#FILES[@]}
if [[ $TOTAL -eq 0 ]]; then
  echo "No docker-compose.yml files found (excluding ./portainer/)."
  exit 0
fi

# PROGRESS BAR [BEGIN] --------------------------------------------
# Progress bar (only if stdout is a TTY)
BAR_WIDTH=50
SHOW_PROGRESS=0
[[ -t 1 ]] && SHOW_PROGRESS=1

show_progress() {
  [[ $SHOW_PROGRESS -eq 1 ]] || return 0

  local current="$1" total="$2"
  local percent=$(( current * 100 / total ))
  local filled=$(( percent * BAR_WIDTH / 100 ))
  local empty=$(( BAR_WIDTH - filled ))

  local filled_str empty_str
  filled_str=$(printf '%*s' "$filled" '' | tr ' ' '=')
  empty_str=$(printf '%*s' "$empty" '' | tr ' ' ' ')

  printf "\r[%s%s] %3d%% (%d/%d)" "$filled_str" "$empty_str" "$percent" "$current" "$total"

  if [[ "$current" -eq "$total" ]]; then
    printf "\n"
  fi
}
# PROGRESS BAR [END] ----------------------------------------------

echo "Searching for port $PORT in $TOTAL docker-compose.yml file(s) ..."

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

match_count=0
match_files=0
current=0

for file in "${FILES[@]}"; do
  current=$((current + 1))
  show_progress "$current" "$TOTAL"

  # Read matches with line numbers; keep grep from exiting non-zero when no matches
  mapfile -t matches < <(grep -n --color=always -P "$REGEX" "$file" 2>/dev/null || true)

  if [[ ${#matches[@]} -gt 0 ]]; then
    match_files=$((match_files + 1))
    match_count=$((match_count + ${#matches[@]}))

    {
      printf "Found port '%s' in: %s\n" "$PORT" "$file"
      for m in "${matches[@]}"; do
        printf "Matched line: %s\n" "$m"
      done
      printf '%s\n' '----------------------------------------'
      echo ""
    } >> "$TMP_OUT"
  fi
done

# Clear the progress bar line if we were drawing inline
if [[ $SHOW_PROGRESS -eq 1 ]]; then
  printf "\033[K"
fi

if [[ $match_count -eq 0 ]]; then
  echo "Search complete! No matches found for port $PORT."
  echo ""
  exit 0
fi

echo "Search complete! Found $match_count match(es) in $match_files file(s)."
echo
cat "$TMP_OUT"