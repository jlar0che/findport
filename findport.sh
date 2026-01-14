#!/bin/bash
set -euo pipefail # fail fast: exit on error, unset vars, and pipeline failures

echo ""

# --------------------------------------------
# findport.sh v2.2 | by Jacques Laroche
# Searches for a port inside docker-compose files
# ONLY one directory deep (./<dir>/docker-compose.*)
# with a live progress bar.
# Excludes ./portainer/ (top-level) if present.
#
# Usage: ./findport.sh <port_number>
# --------------------------------------------

# -----------------------------
# Color (disable if not a TTY, or if NO_COLOR is set)
# -----------------------------
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  BOLD=$'\033[1m'
  DIM=$'\033[2m'
  RED=$'\033[31m'
  GREEN=$'\033[32m'
  YELLOW=$'\033[33m'
  BLUE=$'\033[34m'
  MAGENTA=$'\033[35m'
  CYAN=$'\033[36m'
  RESET=$'\033[0m'
else
  BOLD=""; DIM=""; RED=""; GREEN=""; YELLOW=""; BLUE=""; MAGENTA=""; CYAN=""; RESET=""
fi

# -----------------------------
# Args / input validation
# -----------------------------
if [[ $# -ne 1 ]]; then
  echo -e "${BOLD}FindPort:${RESET} v2.2"
  echo "--------------"
  echo -e "${BOLD}Usage:${RESET} $0 <port_number>"
  echo ""
  exit 1
fi

PORT="$1"

# digits only
if [[ ! "$PORT" =~ ^[0-9]+$ ]]; then
  echo -e "${RED}Error:${RESET} port must be a number between 1 and 65535."
  echo -e "${BOLD}Usage:${RESET} $0 <port_number>"
  echo ""
  exit 1
fi

# range 1..65535
if (( PORT < 1 || PORT > 65535 )); then
  echo -e "${RED}Error:${RESET} port must be between 1 and 65535."
  echo -e "${BOLD}Usage:${RESET} $0 <port_number>"
  echo ""
  exit 1
fi

# Portable grep (ERE) pattern: don't match inside a bigger number
REGEX="(^|[^0-9])${PORT}([^0-9]|$)"

# -----------------------------
# Count immediate child directories (one level down)
# -----------------------------
mapfile -d '' DIRS < <(
  find . \
    -mindepth 1 -maxdepth 1 \
    -type d \
    -not -path "./portainer" \
    -print0
)
DIR_COUNT=${#DIRS[@]}

# -----------------------------
# Collect docker-compose files exactly one directory deep
# Supports:
#   docker-compose.yml / docker-compose.yaml
# -----------------------------
mapfile -d '' FILES < <(
  find . \
    -mindepth 2 -maxdepth 2 \
    -type f \( -name "docker-compose.yml" -o -name "docker-compose.yaml" \) \
    -not -path "./portainer/*" \
    -print0
)

# Return no results (if there are no docker-compose files found)
TOTAL=${#FILES[@]}
if [[ $TOTAL -eq 0 ]]; then
  echo -e "${YELLOW}No docker-compose file(s) found${RESET} one directory deep (excluding ./portainer/)."
  echo ""
  exit 0
fi

# -----------------------------
# Progress bar
# -----------------------------
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

  printf "\r${GREEN}[%s%s]${RESET} %3d%% (%d/%d)" "$filled_str" "$empty_str" "$percent" "$current" "$total"

  if [[ "$current" -eq "$total" ]]; then
    printf "\n"
  fi
}

# -----------------------------
# Intro output
# -----------------------------
echo -e "${CYAN}Searching for port [${BOLD}${YELLOW}${PORT}${RESET}${CYAN}] ...${RESET}"
echo -e "${CYAN}[${RESET}${YELLOW}${DIR_COUNT}${RESET}${CYAN}] Directories found ...${RESET}"
echo -e "${CYAN}[${RESET}${YELLOW}${TOTAL}${RESET}${CYAN}] docker-compose file(s) found ...${RESET}"

TMP_OUT="$(mktemp)"
trap 'rm -f "$TMP_OUT"' EXIT

match_count=0
match_files=0
current=0

for file in "${FILES[@]}"; do
  current=$((current + 1))
  show_progress "$current" "$TOTAL"

  # Read matches with line numbers; keep grep from exiting non-zero when no matches
  mapfile -t matches < <(grep -n --color=always -E "$REGEX" "$file" 2>/dev/null || true)

  if [[ ${#matches[@]} -gt 0 ]]; then
    match_files=$((match_files + 1))
    match_count=$((match_count + ${#matches[@]}))

    {
      #printf "%bFound port '%b%s%b' in:%b %s\n" "$GREEN$BOLD" "$RED" "$PORT" "$GREEN$BOLD" "$RESET" "$file"
      printf "%bFound port '%b%s%b' in:%b %s%b\n" "$GREEN$BOLD" "$RED" "$PORT" "$GREEN$BOLD" "$MAGENTA" "$file" "$RESET"
      for m in "${matches[@]}"; do
        printf "Matched line: %s\n" "$m"
      done
      printf '%s\n' '---------------------------------------------------'
      echo ""
    } >> "$TMP_OUT"
  fi
done

# Clear the progress bar line if we were drawing inline
if [[ $SHOW_PROGRESS -eq 1 ]]; then
  printf "\033[K"
fi

if [[ $match_count -eq 0 ]]; then
  echo -e "${BOLD}${GREEN}Search complete!${RESET} ${YELLOW}No matches found${RESET} for port ${BOLD}${YELLOW}${PORT}${RESET}."
  echo ""
  exit 0
fi

echo -e "${BOLD}${GREEN}Search complete!${RESET} Found ${BOLD}${YELLOW}${match_count}${RESET} match(es) in ${BOLD}${YELLOW}${match_files}${RESET} file(s)."
echo
cat "$TMP_OUT"