#!/bin/bash

# ============================================
# Subdomain Enumeration & Reconnaissance Tool v2.0
# Author: BRYNNNN12
# Version: 2.0 (Production-Ready)
# Fully Modularized | Security-Focused | Synchronized with target.sh
# ============================================

set -euo pipefail
trap 'handle_error "Error on line $LINENO"' ERR

# ============================================
# GLOBAL CONSTANTS
# ============================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOL_VERSION="2.0"
readonly START_TIME=$(date +%s)

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly WHITE='\033[1;37m'
readonly GRAY='\033[0;90m'
readonly NC='\033[0m'

# ============================================
# GLOBAL VARIABLES
# ============================================

# From .env file (will be loaded)
TARGET=""
BASE_DIR=""
RECON_DIR=""
SCANS_DIR=""
SCREENSHOTS_DIR=""
REPORTS_DIR=""
LOG_DIR=""
RATE_LIMIT="50"
MODE="auto"
RESOURCE_DIR="${HOME}/.config/recon"
CHAOS_KEY=""

# Internal variables
LOG_FILE=""
SILENT_MODE=false
OUTPUT_DIR=""

# ============================================
# ERROR HANDLING
# ============================================

handle_error() {
    log_error "$1 (exit code: $?)"
    exit 1
}

# ============================================
# LOGGING FUNCTIONS
# ============================================

log_info() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "[$ts] [INFO] $msg" >> "$LOG_FILE"
    [[ "$SILENT_MODE" == "false" ]] && echo -e "${CYAN}[ℹ]${NC} $msg"
}

log_warn() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "[$ts] [WARN] $msg" >> "$LOG_FILE"
    [[ "$SILENT_MODE" == "false" ]] && echo -e "${YELLOW}[⚠]${NC} $msg" >&2
}

log_error() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "[$ts] [ERROR] $msg" >> "$LOG_FILE"
    [[ "$SILENT_MODE" == "false" ]] && echo -e "${RED}[✖]${NC} $msg" >&2
}

log_success() {
    local msg="$1"
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "[$ts] [SUCCESS] $msg" >> "$LOG_FILE"
    [[ "$SILENT_MODE" == "false" ]] && echo -e "${GREEN}[✓]${NC} $msg"
}

log_step() {
    local current=$1
    local total=$2
    local msg=$3
    local ts
    ts=$(date '+%Y-%m-%d %H:%M:%S')
    
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && echo "[$ts] [STEP] $current/$total: $msg" >> "$LOG_FILE"
    
    if [[ "$SILENT_MODE" == "false" ]]; then
        local pct=$((current * 100 / total))
        local bar_w=40
        local filled=$((pct * bar_w / 100))
        local empty=$((bar_w - filled))
        
        local bar=""
        for ((i=0; i<filled; i++)); do bar+="█"; done
        for ((i=0; i<empty; i++)); do bar+="░"; done
        
        echo -e "${BLUE}[STEP $current/$total]${NC} ${GREEN}${bar}${NC} ${pct}% - $msg"
    fi
}

# ============================================
# ENVIRONMENT LOADING
# ============================================

load_env() {
    local env_file="${BASE_DIR}/.env"
    
    if [[ ! -f "$env_file" ]]; then
        log_error "Environment file not found: $env_file"
        log_error "Please run target.sh first to create project structure"
        exit 1
    fi

    log_info "Loading environment from: $env_file"

    # Safely source .env
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue
        
        key=$(echo "$key" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value=$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        value="${value//\$\{BASE_DIR\}/$BASE_DIR}"
        
        case "$key" in
            TARGET) TARGET="$value" ;;
            BASE_DIR) BASE_DIR="$value" ;;
            RECON_DIR) RECON_DIR="$value" ;;
            SCANS_DIR) SCANS_DIR="$value" ;;
            SCREENSHOTS_DIR) SCREENSHOTS_DIR="$value" ;;
            REPORTS_DIR) REPORTS_DIR="$value" ;;
            LOG_DIR) LOG_DIR="$value" ;;
            RATE_LIMIT) RATE_LIMIT="$value" ;;
            MODE) MODE="$value" ;;
            CHAOS_KEY) CHAOS_KEY="$value" ;;
        esac
    done < "$env_file"

    # Validate loaded variables
    if [[ -z "$TARGET" || -z "$BASE_DIR" ]]; then
        log_error "Invalid .env file: TARGET and BASE_DIR must be set"
        exit 1
    fi

    # Initialize LOG_FILE
    LOG_FILE="${LOG_DIR}/recon.log"
    mkdir -p "$LOG_DIR" 2>/dev/null || true
    
    log_info "Environment loaded successfully"
    log_info "Target: $TARGET"
    log_info "Base Directory: $BASE_DIR"
}

find_env_file() {
    # Try current directory first
    if [[ -f ".env" ]]; then
        BASE_DIR="$(pwd)"
        return 0
    fi

    # Try parent directory
    if [[ -f "../.env" ]]; then
        BASE_DIR="$(cd .. && pwd)"
        return 0
    fi

    # Try TARGETS_DIR structure
    local targets_dir="${HOME}/bugbounty/targets"
    if [[ -d "$targets_dir" ]]; then
        for target_dir in "$targets_dir"/*/; do
            if [[ -f "$target_dir/.env" ]]; then
                BASE_DIR="$target_dir"
                return 0
            fi
        done
    fi

    return 1
}

# ============================================
# VALIDATION FUNCTIONS
# ============================================

validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

check_tools() {
    log_info "Checking required tools..."
    
    local missing=0
    local tools=("subfinder" "assetfinder" "shuffledns" "puredns" "httpx")
    
    for tool in "${tools[@]}"; do
        if ! command -v "$tool" &>/dev/null; then
            log_warn "Missing tool: $tool"
            ((missing++))
        else
            log_info "Found: $tool"
        fi
    done

    # Check for chaos
    if ! command -v chaos &>/dev/null; then
        log_warn "chaos not found (optional - requires CHAOS_KEY anyway)"
    fi

    # Check for altdns
    if ! find_altdns_bin; then
        log_warn "altdns not found (optional for permutation stage)"
    fi

    if [[ $missing -gt 0 ]]; then
        log_warn "Some tools are missing. Some features may not work."
    fi
}

find_altdns_bin() {
    if command -v altdns &>/dev/null; then
        ALT_DNS_BIN=$(command -v altdns)
        return 0
    fi

    local paths=(
        "$HOME/bugbounty/tools/altdns/venv/bin/altdns"
        "$HOME/tools/altdns/venv/bin/altdns"
        "/opt/altdns/venv/bin/altdns"
        "$HOME/.local/bin/altdns"
    )

    for path in "${paths[@]}"; do
        if [[ -x "$path" ]]; then
            ALT_DNS_BIN="$path"
            return 0
        fi
    done

    return 1
}

setup_resources() {
    mkdir -p "$RESOURCE_DIR" || {
        log_error "Cannot create resource directory: $RESOURCE_DIR"
        exit 1
    }

    # Download resolvers if missing
    local resolvers_file="$RESOURCE_DIR/resolvers.txt"
    if [[ ! -f "$resolvers_file" ]]; then
        log_info "Downloading resolvers..."
        if curl -s https://raw.githubusercontent.com/projectdiscovery/public-resolvers/main/resolvers.txt -o "$resolvers_file"; then
            log_success "Resolvers downloaded"
        else
            log_error "Failed to download resolvers"
            exit 1
        fi
    fi
}

# ============================================
# BANNER
# ============================================

show_banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║   ██████╗ ███████╗ ██████╗ ██████╗ ███╗   ██╗            ║"
    echo "║   ██╔══██╗██╔════╝██╔════╝██╔═══██╗████╗  ██║            ║"
    echo "║   ██████╔╝█████╗  ██║     ██║   ██║██╔██╗ ██║            ║"
    echo "║   ██╔══██╗██╔══╝  ██║     ██║   ██║██║╚██╗██║            ║"
    echo "║   ██║  ██║███████╗╚██████╗╚██████╔╝██║ ╚████║            ║"
    echo "║   ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝  ╚═══╝            ║"
    echo "║                                                          ║"
    echo "║              RECON TOOL v$TOOL_VERSION - BY BRYNNNN12   ║"
    echo "║         Production-Ready | Fully Synchronized            ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}📅 Date: $(date)${NC}"
    echo ""
}

show_help() {
    show_banner
    echo -e "${YELLOW}📖 USAGE GUIDE${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}USAGE:${NC}"
    echo "  $SCRIPT_NAME [options]"
    echo ""
    echo -e "${CYAN}OPTIONS:${NC}"
    echo "  --mode <mode>    : auto (default), passive, or full"
    echo "  --rate <number>  : DNS query rate limit (default: 50)"
    echo "  --silent         : Silent mode (no colored output)"
    echo "  --help, -h       : Show this help message"
    echo "  --version        : Show version"
    echo ""
    echo -e "${CYAN}WORKFLOW:${NC}"
    echo "  1. Source .env in target directory"
    echo "  2. Run this script"
    echo "  3. Results saved in BASE_DIR structure"
    echo ""
    echo -e "${CYAN}MODES:${NC}"
    echo "  passive  : Only passive enumeration"
    echo "  active   : Passive + active brute force"
    echo "  auto     : Choose based on passive results"
    echo ""
    echo -e "${CYAN}OUTPUT FILES:${NC}"
    echo "  recon/all_subdomains.txt   : All unique subdomains"
    echo "  recon/live_subdomains.txt  : Live subdomains with details"
    echo "  logs/recon.log             : Detailed execution log"
    echo ""
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
}

# ============================================
# RECONNAISSANCE WORKFLOW
# ============================================

run_passive_enumeration() {
    log_step 1 6 "🕵️  PASSIVE ENUMERATION"
    
    mkdir -p "$RECON_DIR/passive"
    local passive_dir="$RECON_DIR/passive"
    
    log_info "Running subfinder..."
    if subfinder -d "$TARGET" -silent -o "$passive_dir/subfinder.txt" 2>/dev/null; then
        local cnt=$(wc -l < "$passive_dir/subfinder.txt")
        log_success "subfinder found $cnt subdomains"
    else
        touch "$passive_dir/subfinder.txt"
        log_warn "subfinder failed or found nothing"
    fi
    
    log_info "Running assetfinder..."
    if assetfinder --subs-only "$TARGET" > "$passive_dir/assetfinder.txt" 2>/dev/null; then
        local cnt=$(wc -l < "$passive_dir/assetfinder.txt")
        log_success "assetfinder found $cnt subdomains"
    else
        touch "$passive_dir/assetfinder.txt"
        log_warn "assetfinder failed"
    fi
    
    if [[ -n "$CHAOS_KEY" ]]; then
        log_info "Running chaos-client..."
        if chaos -d "$TARGET" -silent -o "$passive_dir/chaos.txt" 2>/dev/null; then
            local cnt=$(wc -l < "$passive_dir/chaos.txt")
            log_success "chaos found $cnt subdomains"
        else
            touch "$passive_dir/chaos.txt"
            log_warn "chaos failed or not found"
        fi
    else
        touch "$passive_dir/chaos.txt"
        log_warn "CHAOS_KEY not set, skipping chaos-client"
    fi
    
    cat "$passive_dir"/{subfinder,assetfinder,chaos}.txt 2>/dev/null | sort -u > "$passive_dir/passive_all.txt"
    local total=$(wc -l < "$passive_dir/passive_all.txt")
    log_success "Total unique passive results: $total"
    
    echo "$total"
}

run_active_enumeration() {
    log_step 3 6 "💪 ACTIVE BRUTE FORCE"
    
    mkdir -p "$RECON_DIR/active"
    local active_dir="$RECON_DIR/active"
    local resolvers="$RESOURCE_DIR/resolvers.txt"
    local wordlist="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
    
    [[ ! -f "$wordlist" ]] && wordlist="$RESOURCE_DIR/wordlist.txt"
    
    log_info "Running shuffledns..."
    if shuffledns -d "$TARGET" -w "$wordlist" -r "$resolvers" -o "$active_dir/brute.txt" -rate-limit "$RATE_LIMIT" 2>/dev/null; then
        log_success "shuffledns completed"
        local cnt=$(wc -l < "$active_dir/brute.txt")
        log_success "Found $cnt potential subdomains"
    else
        touch "$active_dir/brute.txt"
        log_warn "shuffledns failed"
    fi
    
    if [[ -s "$active_dir/brute.txt" ]]; then
        log_info "Resolving active results..."
        if puredns resolve "$active_dir/brute.txt" -r "$resolvers" -l "$RATE_LIMIT" -o "$active_dir/brute_resolved.txt" 2>/dev/null; then
            local cnt=$(wc -l < "$active_dir/brute_resolved.txt")
            log_success "Resolved $cnt subdomains from brute force"
        else
            touch "$active_dir/brute_resolved.txt"
        fi
    else
        touch "$active_dir/brute_resolved.txt"
    fi
    
    wc -l < "$active_dir/brute_resolved.txt"
}

run_live_check() {
    log_step 6 6 "🌐 CHECKING LIVE SUBDOMAINS"
    
    local all_subs="$RECON_DIR/all_subdomains.txt"
    
    if [[ ! -s "$all_subs" ]]; then
        log_warn "No subdomains to check"
        touch "$RECON_DIR/live_subdomains.txt"
        return
    fi
    
    log_info "Running httpx for live detection..."
    if httpx -l "$all_subs" -silent -status-code -title -tech-detect -follow-redirects -timeout 10 -retries 2 -threads 50 -o "$RECON_DIR/live_subdomains.txt" 2>/dev/null; then
        local cnt=$(wc -l < "$RECON_DIR/live_subdomains.txt")
        log_success "Found $cnt live subdomains"
    else
        touch "$RECON_DIR/live_subdomains.txt"
        log_warn "httpx had issues"
    fi
}

# ============================================
# MAIN RECON WORKFLOW
# ============================================

main_recon() {
    log_info "Starting reconnaissance for: $TARGET"
    log_info "Base directory: $BASE_DIR"
    log_info "Mode: $MODE"
    
    mkdir -p "$RECON_DIR" "$SCANS_DIR" "$SCREENSHOTS_DIR" "$REPORTS_DIR"
    
    # Setup resources
    setup_resources
    
    # Step 1: Passive enumeration
    local passive_cnt
    passive_cnt=$(run_passive_enumeration)
    
    # Step 2: Resolve passive results
    log_step 2 6 "🔍 RESOLVING PASSIVE RESULTS"
    mkdir -p "$RECON_DIR/passive"
    
    local resolvers="$RESOURCE_DIR/resolvers.txt"
    if puredns resolve "$RECON_DIR/passive/passive_all.txt" -r "$resolvers" -l "$RATE_LIMIT" -o "$RECON_DIR/passive/resolved.txt" 2>/dev/null; then
        local cnt=$(wc -l < "$RECON_DIR/passive/resolved.txt")
        log_success "Resolved $cnt valid subdomains"
    else
        touch "$RECON_DIR/passive/resolved.txt"
    fi
    
    # Determine if we should do active
    local active_cnt=0
    if [[ "$MODE" == "auto" ]]; then
        if [[ $passive_cnt -lt 50 ]]; then
            log_info "AUTO mode: passive results < 50, running active scan"
            active_cnt=$(run_active_enumeration)
        else
            log_info "AUTO mode: passive results >= 50, skipping active"
            mkdir -p "$RECON_DIR/active"
            touch "$RECON_DIR/active/brute_resolved.txt"
        fi
    elif [[ "$MODE" == "full" ]]; then
        active_cnt=$(run_active_enumeration)
    else
        mkdir -p "$RECON_DIR/active"
        touch "$RECON_DIR/active/brute_resolved.txt"
    fi
    
    # Step 4: Combine results
    log_step 5 6 "📦 COMBINING RESULTS"
    cat "$RECON_DIR/passive/resolved.txt" "$RECON_DIR/active/brute_resolved.txt" 2>/dev/null | sort -u > "$RECON_DIR/all_subdomains.txt"
    local total=$(wc -l < "$RECON_DIR/all_subdomains.txt")
    log_success "Total unique subdomains: $total"
    
    # Step 6: Live check
    run_live_check
    
    # Summary
    local elapsed=$(($(date +%s) - START_TIME))
    log_success "Reconnaissance completed in $((elapsed/60))m $((elapsed%60))s"
    
    display_summary "$total" "$passive_cnt" "$active_cnt"
}

display_summary() {
    local total=$1
    local passive=$2
    local active=$3
    local live
    live=$(wc -l < "$RECON_DIR/live_subdomains.txt" 2>/dev/null || echo "0")
    
    echo ""
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}📊 RECONNAISSANCE SUMMARY${NC}"
    echo -e "${PURPLE}════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "${CYAN}📈 STATISTICS:${NC}"
    echo -e "  Passive enumeration : ${GREEN}$passive${NC} subdomains"
    echo -e "  Active brute force  : ${GREEN}$active${NC} subdomains"
    echo -e "  Total unique        : ${GREEN}$total${NC} subdomains"
    echo -e "  Live subdomains     : ${GREEN}$live${NC} confirmed"
    echo ""
    echo -e "${CYAN}📁 OUTPUT FILES:${NC}"
    echo -e "  ${RECON_DIR}/all_subdomains.txt      → All subdomains"
    echo -e "  ${RECON_DIR}/live_subdomains.txt     → Live with details"
    echo -e "  ${LOG_FILE}  → Execution log"
    echo ""
    
    if [[ $live -gt 0 ]]; then
        echo -e "${CYAN}🔗 Sample live subdomains (first 5):${NC}"
        head -5 "$RECON_DIR/live_subdomains.txt" | while read -r line; do
            echo -e "  ${GREEN}➜${NC} $line"
        done
    fi
    
    echo ""
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}✨ RECON COMPLETE! Results saved to: $BASE_DIR ✨${NC}"
    echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
}

# ============================================
# MAIN PROGRAM
# ============================================

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --mode) MODE="$2"; shift 2 ;;
        --rate) RATE_LIMIT="$2"; shift 2 ;;
        --silent) SILENT_MODE=true; shift ;;
        --help|-h) show_help; exit 0 ;;
        --version) echo "recon.sh v$TOOL_VERSION"; exit 0 ;;
        *) log_error "Unknown option: $1"; exit 1 ;;
    esac
done

clear
show_banner

# Find and load environment
if ! find_env_file; then
    log_error "Cannot find .env file"
    log_error "Please run target.sh first to create project structure"
    log_error "Usage: cd to target directory and run: ../recon.sh"
    exit 1
fi

load_env

# Validate
validate_domain "$TARGET" || {
    log_error "Invalid target domain: $TARGET"
    exit 1
}

# Check tools
check_tools

# Run recon
main_recon

echo ""
log_success "Thank you for using RECON v$TOOL_VERSION by BRYNNNN12"
