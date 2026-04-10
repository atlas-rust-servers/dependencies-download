#!/bin/bash

JSON_FILE="external.json"
MAX_RETRIES=3
RETRY_DELAY=5
SCRIPT_START=$(date +%s)

# Colors
R='\033[0m'
B='\033[1m'
DIM='\033[2m'
GREEN='\033[38;5;114m'
RED='\033[38;5;210m'
YELLOW='\033[38;5;222m'
BLUE='\033[38;5;111m'
GRAY='\033[38;5;245m'
WHITE='\033[38;5;255m'
BG_GREEN='\033[48;5;22m'
BG_RED='\033[48;5;52m'
CYAN='\033[38;5;116m'

rm -f /tmp/atlas_failed_deps.txt /tmp/atlas_success_deps.txt

format_bytes() {
    local bytes=$1
    if [ "$bytes" -ge 1048576 ]; then
        awk "BEGIN {printf \"%.1f MB\", $bytes/1048576}"
    elif [ "$bytes" -ge 1024 ]; then
        awk "BEGIN {printf \"%.1f KB\", $bytes/1024}"
    else
        echo "${bytes} B"
    fi
}

format_duration() {
    local ms=$1
    if [ "$ms" -ge 1000 ]; then
        awk "BEGIN {printf \"%.1fs\", $ms/1000}"
    else
        echo "${ms}ms"
    fi
}

validate_file() {
    local path=$1
    if [ ! -f "$path" ]; then
        return 1
    fi
    local size
    size=$(stat -c%s "$path" 2>/dev/null || stat -f%z "$path" 2>/dev/null)
    if [ "$size" -le 0 ] 2>/dev/null; then
        rm -f "$path"
        return 1
    fi
    echo "$size"
    return 0
}

download_public() {
    local url=$1
    local path=$2
    local name
    name=$(basename "$path")
    local attempt=1

    mkdir -p "$(dirname "$path")"

    while [ $attempt -le $MAX_RETRIES ]; do
        if [ $attempt -gt 1 ]; then
            printf "  ${YELLOW}↻${R} ${DIM}retry ${attempt}/${MAX_RETRIES}${R}\n"
        fi

        local start_ms=$(($(date +%s%N 2>/dev/null || date +%s)/ 1000000))
        curl -sL --fail --connect-timeout 10 --max-time 300 -o "$path" "$url" &
        local pid=$!

        wait "$pid" 2>/dev/null

        local result
        result=$(validate_file "$path")
        if [ $? -eq 0 ]; then
            local formatted
            formatted=$(format_bytes "$result")
            echo -e "${BG_GREEN} ${GREEN}${B}OK${R}${BG_GREEN} ${R} ${WHITE}${name}${R}  ${DIM}${formatted}${R}"
            return 0
        fi

        echo -e "${BG_RED} ${RED}${B}!!${R}${BG_RED} ${R} ${RED}${name}${R}  ${DIM}attempt ${attempt}/${MAX_RETRIES}${R}"

        if [ $attempt -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
        attempt=$((attempt + 1))
    done

    echo -e "${BG_RED} ${RED}${B}FAIL${R}${BG_RED} ${R} ${RED}${name}${R}"
    return 1
}

download_private() {
    local token=$1
    local repo=$2
    local file=$3
    local path=$4
    local attempt=1

    mkdir -p "$(dirname "$path")"

    local latest_release_api_url="https://api.github.com/repos/$repo/releases/latest"

    local asset_id
    asset_id=$(curl -sS -H "Authorization: token $token" -H "Accept: application/vnd.github.v3+json" --fail --connect-timeout 10 "$latest_release_api_url" | jq -r ".assets[] | select(.name==\"$file\") | .id")

    if [ -z "$asset_id" ] || [ "$asset_id" = "null" ]; then
        echo -e "${BG_RED} ${RED}${B}!!${R}${BG_RED} ${R} ${RED}${file}${R}  ${DIM}asset not found in ${repo}${R}"
        return 1
    fi

    local download_url="https://api.github.com/repos/$repo/releases/assets/$asset_id"

    while [ $attempt -le $MAX_RETRIES ]; do
        if [ $attempt -gt 1 ]; then
            printf "  ${YELLOW}↻${R} ${DIM}retry ${attempt}/${MAX_RETRIES}${R}\n"
        fi

        local start_ms=$(($(date +%s%N 2>/dev/null || date +%s) / 1000000))
        curl -sJL -H "Authorization: token $token" -H "Accept: application/octet-stream" \
            --fail --connect-timeout 10 --max-time 300 \
            -o "$path" "$download_url" &
        local pid=$!

        wait "$pid" 2>/dev/null

        local result
        result=$(validate_file "$path")
        if [ $? -eq 0 ]; then
            local formatted
            formatted=$(format_bytes "$result")
            echo -e "${BG_GREEN} ${GREEN}${B}OK${R}${BG_GREEN} ${R} ${WHITE}${file}${R}  ${DIM}${formatted}${R}"
            return 0
        fi

        echo -e "${BG_RED} ${RED}${B}!!${R}${BG_RED} ${R} ${RED}${file}${R}  ${DIM}attempt ${attempt}/${MAX_RETRIES}${R}"

        if [ $attempt -lt $MAX_RETRIES ]; then
            sleep $RETRY_DELAY
        fi
        attempt=$((attempt + 1))
    done

    echo -e "${BG_RED} ${RED}${B}FAIL${R}${BG_RED} ${R} ${RED}${file}${R}"
    return 1
}

# ── Header ──────────────────────────────────────────
echo ""
echo -e "  ${BLUE}╔═══════════════════════════════════════╗${R}"
echo -e "  ${BLUE}║${R}   ${B}${WHITE}Atlas Dependency Manager${R}            ${BLUE}║${R}"
echo -e "  ${BLUE}╚═══════════════════════════════════════╝${R}"
echo ""

pub_count=$(jq '.["public-repo"] | length' "$JSON_FILE" 2>/dev/null || echo 0)
priv_count=$(jq '.["private-repo"] | length' "$JSON_FILE" 2>/dev/null || echo 0)
TOTAL=$((pub_count + priv_count))

echo -e "  ${GRAY}dependencies${R}  ${WHITE}${B}${TOTAL}${R}"
echo ""

CURRENT=0

# ── Public ──────────────────────────────────────────
if [ "$pub_count" -gt 0 ]; then
    jq -r '.["public-repo"][] | "\(.url) \(.["output-path"])"' "$JSON_FILE" | while read -r url path; do
        CURRENT=$((CURRENT + 1))
        if download_public "$url" "$path"; then
            echo "$(basename "$path")" >> /tmp/atlas_success_deps.txt
        else
            echo "$path" >> /tmp/atlas_failed_deps.txt
        fi
    done
fi

# ── Private ─────────────────────────────────────────
if [ "$priv_count" -gt 0 ]; then
    jq -r '.["private-repo"][] | "\(.["token"]) \(.repo) \(.file) \(.["output-path"])"' "$JSON_FILE" | while read -r token repo file path; do
        CURRENT=$((CURRENT + 1))
        if download_private "$token" "$repo" "$file" "$path"; then
            echo "$file" >> /tmp/atlas_success_deps.txt
        else
            echo "$path" >> /tmp/atlas_failed_deps.txt
        fi
    done
fi

# ── Result ──────────────────────────────────────────
SCRIPT_END=$(date +%s)
ELAPSED=$((SCRIPT_END - SCRIPT_START))

rm -f /tmp/atlas_success_deps.txt

if [ -f /tmp/atlas_failed_deps.txt ]; then
    echo -e "${BG_RED} ${RED}${B} Failed ${R}${BG_RED} ${R}  ${RED}${TOTAL} dependencies${R}  ${DIM}${ELAPSED}s${R}"
    echo ""
    while IFS= read -r dep; do
        echo -e "    ${RED}•${R} ${DIM}${dep}${R}"
    done < /tmp/atlas_failed_deps.txt
    rm -f /tmp/atlas_failed_deps.txt
    echo ""
    echo -e "${BG_RED} ${RED}${B} EXIT ${R}${BG_RED} ${R}  ${RED}Cannot start without missing dependencies.${R}"
    echo ""
    exit 1
fi

echo -e "${BG_GREEN} ${GREEN}${B} Successful ${R}${BG_GREEN} ${R}  ${GREEN}${TOTAL} dependencies${R}  ${DIM}${ELAPSED}s${R}"
echo ""
exit 0
