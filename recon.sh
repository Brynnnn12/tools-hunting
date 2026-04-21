#!/bin/bash

# ============================================
# Alat Enumerasi Subdomain & Pengintaian v1.0
# Penulis: BRYNNNN12
# DevSecOps Audit: FIXED & HARDENED
# ============================================
# FITUR:
#   - Pemuatan .env ketat dengan parsing variabel whitelist
#   - Performa teroptimasi: cache file counts, reduced subshells
#   - Output berbasis printf: kompatibel macOS/Linux/WSL
#   - Penanganan kesalahan yang ditingkatkan dengan exit codes yang tepat
#   - Output JSON opsional (--json flag)
#   - Kontrol mode: auto/passive/full
#   - Rate limiting untuk query DNS
#   - HARDENED: Input validation, secure parsing, no silent failures
# ============================================

set -euo pipefail

# Temp files untuk cleanup
TEMP_FILES=()

cleanup_tempfiles() {
    local exit_code=$?
    if [[ ${#TEMP_FILES[@]} -gt 0 ]]; then
        for file in "${TEMP_FILES[@]}"; do
            [[ -f "$file" ]] && rm -f "$file" 2>/dev/null || true
        done
    fi
    return $exit_code
}

trap cleanup_tempfiles EXIT
trap 'handle_trap_error "Interrupted" 130' INT TERM
trap 'handle_trap_error "Error on line $LINENO" "$?"' ERR

# ============================================
# GLOBAL CONSTANTS
# ============================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOL_VERSION="1.1"

# Cross-platform epoch time (macOS/Linux compatible)
get_epoch() {
    if date +%s%N &>/dev/null 2>&1 | grep -q '^[0-9]'; then
        date +%s%N
    elif date -f '%s' '+%s000000000' &>/dev/null 2>&1; then
        date +%s000000000
    else
        printf '%d000000000' "$(date +%s)"
    fi
}
readonly START_TIME=$(get_epoch)

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

# Validation patterns (Bash ERE compatible - no lookahead/lookbehind)
# Ensures labels don't start/end with hyphen and have 1-63 chars
readonly DOMAIN_REGEX='^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*\.[a-z]{2,}$'
readonly NUMERIC_REGEX='^[0-9]+$'

# ============================================
# GLOBAL VARIABLES (from .env)
# ============================================

TARGET=""
BASE_DIR=""
RECON_DIR=""
SCANS_DIR=""
SCREENSHOTS_DIR=""
REPORTS_DIR=""
LOG_DIR=""
RATE_LIMIT="50"
WORDLIST_PATH="/usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt"
MODE="auto"
JSON_OUTPUT="false"
SILENT_MODE="false"
CHAOS_KEY=""

# Internal
LOG_FILE=""
DNS_CACHE_FILE=""

# ============================================
# ERROR HANDLING & LOGGING
# ============================================

handle_trap_error() {
    local message="$1"
    local exit_code="${2:-1}"
    printf '%b[❌] %s (Exit: %d)%b\n' "${RED}" "$message" "$exit_code" >&2
    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && printf '[ERROR] %s (Exit: %d)\n' "$message" "$exit_code" >> "$LOG_FILE"
    exit "$exit_code"
}

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_action() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)

    [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]] && printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE"

    if [[ "$SILENT_MODE" == "false" && "$JSON_OUTPUT" == "false" ]]; then
        case "$level" in
            ERROR)   printf '%b[❌] %s%b\n' "${RED}" "$message" "${NC}" >&2 ;;
            WARNING) printf '%b[⚠]  %s%b\n' "${YELLOW}" "$message" "${NC}" >&2 ;;
            INFO)    printf '%b[ℹ]  %s%b\n' "${BLUE}" "$message" "${NC}" >&2 ;;
            SUCCESS) printf '%b[✅] %s%b\n' "${GREEN}" "$message" "${NC}" >&2 ;;
            STEP)    printf '%b[→]  %s%b\n' "${CYAN}" "$message" "${NC}" >&2 ;;
            *)       printf '%s\n' "$message" >&2 ;;
        esac
    fi
}

error_msg()   { log_action "ERROR" "$1"; exit 1; }
warning_msg() { log_action "WARNING" "$1"; }
info_msg()    { log_action "INFO" "$1"; }
success_msg() { log_action "SUCCESS" "$1"; }
step_msg()    { log_action "STEP" "$1"; }

# ============================================
# ENVIRONMENT & CONFIGURATION
# ============================================

setup_logging() {
    if [[ ! -d "$LOG_DIR" ]]; then
        mkdir -p "$LOG_DIR" || warning_msg "Cannot create LOG_DIR: $LOG_DIR"
        return 1
    fi

    LOG_FILE="${LOG_DIR}/recon.log"
    if ! touch "$LOG_FILE" 2>/dev/null; then
        warning_msg "Cannot create log file: $LOG_FILE"
        LOG_FILE=""
        return 1
    fi

    success_msg "Logging initialized"
}

# SECURE: Clean domain - single responsibility
clean_domain() {
    local domain="$1"
    
    # Strip protocol
    domain="${domain#*://}"
    # Strip path and fragments
    domain="${domain%%/*}"
    domain="${domain%%#*}"
    # Strip port
    domain="${domain%%:*}"
    # Strip www prefix
    domain="${domain#www.}"
    # Remove quotes
    domain="${domain%\"}"
    domain="${domain#\"}"
    domain="${domain%\'}"
    domain="${domain#\'}"
    
    # Trim whitespace and convert to lowercase
    domain=$(printf '%s' "$domain" | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' | tr '[:upper:]' '[:lower:]')
    
    printf '%s' "$domain"
}

# SECURE: Validate domain format
validate_domain_format() {
    local domain="$1"
    
    if [[ ! "$domain" =~ $DOMAIN_REGEX ]]; then
        return 1
    fi
    return 0
}

load_env() {
    local env_file=""
    local env_dir=""

    # SECURE: Find .env with strict precedence
    if [[ -n "${BASE_DIR:-}" && -f "${BASE_DIR}/.env" ]]; then
        env_file="${BASE_DIR}/.env"
        env_dir="$BASE_DIR"
    elif [[ -f ".env" ]]; then
        env_dir="$(pwd)"
        env_file="./.env"
    elif [[ -f "../.env" ]]; then
        env_dir="$(cd .. && pwd)"
        env_file="../.env"
    else
        error_msg "Cannot find .env file (checked: ./.env, ../.env, \${BASE_DIR}/.env)"
    fi

    # SECURE: Verify readability
    if [[ ! -r "$env_file" ]]; then
        error_msg "Cannot read .env file: $env_file"
    fi

    info_msg "Loading environment from: $env_file"

    # SECURE: Whitelist parsing - NO EVAL, NO UNSAFE SOURCE
    local key value
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        key="${key## }"
        key="${key%% }"
        value="${value## }"
        value="${value%% }"

        # Remove quotes (leading & trailing)
        value="${value%\"}"
        value="${value#\"}"
        value="${value%\'}"
        value="${value#\'}"

        # Remove 'export ' prefix
        key="${key#export }"

        # WHITELIST ONLY - no dynamic assignment
        case "$key" in
            TARGET)          TARGET="$value" ;;
            BASE_DIR)        BASE_DIR="$value" ;;
            RECON_DIR)       RECON_DIR="$value" ;;
            SCANS_DIR)       SCANS_DIR="$value" ;;
            SCREENSHOTS_DIR) SCREENSHOTS_DIR="$value" ;;
            REPORTS_DIR)     REPORTS_DIR="$value" ;;
            LOG_DIR)         LOG_DIR="$value" ;;
            RATE_LIMIT)      RATE_LIMIT="${value:-50}" ;;
            WORDLIST_PATH)   WORDLIST_PATH="$value" ;;
            MODE)            MODE="${value:-auto}" ;;
            CHAOS_KEY)       CHAOS_KEY="$value" ;;
        esac
    done < "$env_file"

    # SECURE: Verify required variables
    [[ -z "$TARGET" ]] && error_msg "TARGET not set in .env"
    [[ -z "$BASE_DIR" ]] && error_msg "BASE_DIR not set in .env"

    # SECURE: Clean TARGET domain (remove protocol, path, port, etc.)
    TARGET=$(clean_domain "$TARGET")
    [[ -z "$TARGET" ]] && error_msg "TARGET is empty after cleaning"

    # SECURE: Validate BASE_DIR exists or use fallback
    if [[ ! -d "$BASE_DIR" ]]; then
        warning_msg "BASE_DIR from .env not found: $BASE_DIR"
        warning_msg "Using .env directory as BASE_DIR instead"
        BASE_DIR="$env_dir"
    fi

    # SECURE: Expand ${BASE_DIR} in paths (safe parameter expansion)
    RECON_DIR="${RECON_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    SCANS_DIR="${SCANS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    SCREENSHOTS_DIR="${SCREENSHOTS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    REPORTS_DIR="${REPORTS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    LOG_DIR="${LOG_DIR/\$\{BASE_DIR\}/$BASE_DIR}"

    # Set defaults if not set
    RECON_DIR="${RECON_DIR:-$BASE_DIR/recon}"
    SCANS_DIR="${SCANS_DIR:-$BASE_DIR/scans}"
    SCREENSHOTS_DIR="${SCREENSHOTS_DIR:-$BASE_DIR/screenshots}"
    REPORTS_DIR="${REPORTS_DIR:-$BASE_DIR/reports}"
    LOG_DIR="${LOG_DIR:-$BASE_DIR/logs}"

    info_msg "Environment loaded: TARGET=$TARGET"
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --json)         JSON_OUTPUT="true"; shift ;;
            --mode)         MODE="$2"; shift 2 ;;
            --rate)         RATE_LIMIT="$2"; shift 2 ;;
            --silent)       SILENT_MODE="true"; shift ;;
            -h|--help)      show_help; exit 0 ;;
            -v|--version)   show_version; exit 0 ;;
            -*)             error_msg "Unknown option: $1" ;;
            auto|passive|full)  MODE="$1"; shift ;;
            *)              error_msg "Unknown argument: $1" ;;
        esac
    done
    
    # SECURE: Validate MODE
    case "$MODE" in
        auto|passive|full) ;;
        *) error_msg "Invalid MODE: $MODE (must be auto/passive/full)" ;;
    esac
    
    # SECURE: Validate RATE_LIMIT (numeric or with time unit)
    if [[ ! "$RATE_LIMIT" =~ $NUMERIC_REGEX ]]; then
        error_msg "RATE_LIMIT must be numeric (e.g., 50 or 50/s), got: $RATE_LIMIT"
    fi
    
    # SECURE: Validate conflicting options
    if [[ "$SILENT_MODE" == "true" && "$JSON_OUTPUT" == "true" ]]; then
        warning_msg "Both --silent and --json set; JSON will be used"
    fi
}

show_help() {
    printf '%bAlat Enumerasi Subdomain & Pengintaian v%s%b\n' "${CYAN}" "$TOOL_VERSION" "${NC}"
    printf '\n%bPEMAKAIAN:%b\n' "${GREEN}" "${NC}"
    printf '  %s [MODE] [OPSI]\n' "$SCRIPT_NAME"
    printf '\n%bMODE:%b\n' "${GREEN}" "${NC}"
    printf '  auto               Pasif jika <50 hasil, jika tidak full enumeration (default)\n'
    printf '  passive            Hanya enumerasi pasif\n'
    printf '  full               Enumerasi penuh termasuk brute force\n'
    printf '\n%bOPSI:%b\n' "${GREEN}" "${NC}"
    printf '  --json             Output hasil dalam format JSON\n'
    printf '  --mode MODE        Pilih mode: auto/passive/full (default: auto)\n'
    printf '  --rate LIMIT       Batas laju query DNS (default: 50)\n'
    printf '  --silent           Tanpa output berwarna\n'
    printf '  -h, --help         Tampilkan pesan bantuan ini\n'
    printf '  -v, --version      Tampilkan versi\n'
}

show_version() {
    printf '%s v%s\n' "$SCRIPT_NAME" "$TOOL_VERSION"
}

# ============================================
# VALIDATION & SETUP
# ============================================

check_tools() {
    step_msg "Checking required tools..."

    local tools=("subfinder" "assetfinder" "httpx")
    local missing=0

    for tool in "${tools[@]}"; do
        if command -v "$tool" &>/dev/null; then
            info_msg "Found: $tool"
        else
            warning_msg "Missing tool: $tool"
            ((missing++))
        fi
    done

    # Optional tools
    command -v shuffledns &>/dev/null && info_msg "Found: shuffledns" || warning_msg "shuffledns not found (optional)"
    command -v chaos &>/dev/null && info_msg "Found: chaos" || warning_msg "chaos not found (optional)"
    command -v puredns &>/dev/null && info_msg "Found: puredns" || warning_msg "puredns not found (optional)"

    if [[ $missing -gt 0 ]]; then
        warning_msg "Some required tools missing - some features may not work"
    fi
}

# SAFE: Count lines in file without crashing
safe_wc() {
    local file="$1"
    if [[ -f "$file" && -r "$file" ]]; then
        wc -l < "$file" 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# ============================================
# BANNER & HELP
# ============================================

show_banner() {
    printf '%b' "${CYAN}"
    cat << 'BANNER'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ███████╗ ██████╗ ██████╗ ██╗   ██╗             ║
║   ██╔══██╗██╔════╝██╔════╝██╔═══██╗██║   ██║             ║
║   ██████╔╝█████╗  ██║     ██║   ██║██║   ██║             ║
║   ██╔══██╗██╔══╝  ██║     ██║   ██║██║   ██║             ║
║   ██║  ██║███████╗╚██████╗╚██████╔╝╚██████╔╝             ║
║   ╚═╝  ╚═╝╚══════╝ ╚═════╝ ╚═════╝  ╚═════╝              ║
║                                                          ║
║             Subdomain Enumeration                        ║
╚══════════════════════════════════════════════════════════╝
BANNER
    printf '%b' "${NC}"
    printf 'Date: %s\n\n' "$(date)"
}

# ============================================
# PASSIVE ENUMERATION
# ============================================

run_passive_enumeration() {
    step_msg "Running passive enumeration..."

    local passive_subdomains="${RECON_DIR}/passive_subdomains.txt"
    > "$passive_subdomains" || error_msg "Cannot create passive_subdomains.txt"

    # Subfinder
    if command -v subfinder &> /dev/null; then
        info_msg "Running subfinder..."
        subfinder -d "$TARGET" -silent 2>/dev/null >> "$passive_subdomains" || warning_msg "Subfinder failed or returned no results"
        local sf_count
        sf_count=$(safe_wc "$passive_subdomains")
        info_msg "Subfinder found: $sf_count domains"
    fi

    # Assetfinder
    if command -v assetfinder &> /dev/null; then
        info_msg "Running assetfinder..."
        assetfinder --subs-only "$TARGET" 2>/dev/null >> "$passive_subdomains" || warning_msg "Assetfinder failed or returned no results"
        local af_count
        af_count=$(safe_wc "$passive_subdomains")
        info_msg "Assetfinder found: $af_count total domains so far"
    fi

    # Chaos (optional)
    if [[ -n "$CHAOS_KEY" ]] && command -v chaos &> /dev/null; then
        info_msg "Running chaos..."
        chaos -d "$TARGET" -key "$CHAOS_KEY" -silent 2>/dev/null >> "$passive_subdomains" || warning_msg "Chaos failed or returned no results"
    fi

    # Deduplicate
    info_msg "Deduplicating results..."
    sort -u "$passive_subdomains" -o "$passive_subdomains" || error_msg "Failed to deduplicate"
    
    local count
    count=$(safe_wc "$passive_subdomains")

    success_msg "Passive enumeration complete: $count subdomains"
    log_action "INFO" "Passive results: $count subdomains"

    echo "$count"
}

# ============================================
# ACTIVE ENUMERATION
# ============================================

run_active_enumeration() {
    step_msg "Running active enumeration..."

    local active_subdomains="${RECON_DIR}/active_subdomains.txt"
    > "$active_subdomains" || error_msg "Cannot create active_subdomains.txt"

    # Verify wordlist exists
    if [[ ! -f "$WORDLIST_PATH" ]]; then
        warning_msg "Wordlist not found at: $WORDLIST_PATH"
        warning_msg "Skipping active enumeration"
        return 0
    fi

    # Shuffledns (brute force) with rate limiting
    if command -v shuffledns &> /dev/null; then
        info_msg "Running shuffledns with rate limit $RATE_LIMIT/s (this may take a while)..."
        shuffledns -d "$TARGET" -w "$WORDLIST_PATH" -rate "$RATE_LIMIT" -silent 2>/dev/null >> "$active_subdomains" || warning_msg "Shuffledns failed or returned no results"
        info_msg "Shuffledns completed"
    else
        warning_msg "shuffledns not found - skipping active enumeration"
    fi

    # Deduplicate
    [[ -f "$active_subdomains" ]] && sort -u "$active_subdomains" -o "$active_subdomains"
    
    local count
    count=$(safe_wc "$active_subdomains")

    success_msg "Active enumeration complete: $count subdomains"
    log_action "INFO" "Active results: $count subdomains"

    echo "$count"
}

# ============================================
# LIVE DETECTION
# ============================================

run_live_check() {
    step_msg "Running live detection (optimized: DNS resolution + HTTP probe)..."

    local combined_file="${RECON_DIR}/all_subdomains.txt"
    local resolved_file="${RECON_DIR}/resolved_subdomains.txt"
    local live_file="${RECON_DIR}/live_subdomains.txt"

    # Combine all subdomains
    info_msg "Combining passive and active results..."
    cat "${RECON_DIR}/passive_subdomains.txt" "${RECON_DIR}/active_subdomains.txt" 2>/dev/null | sort -u > "$combined_file" || touch "$combined_file"

    local combined_count
    combined_count=$(safe_wc "$combined_file")
    
    if [[ $combined_count -eq 0 ]]; then
        info_msg "No subdomains to test"
        touch "$live_file"
        echo "0"
        return 0
    fi
    
    info_msg "Testing $combined_count subdomains for live hosts..."

    # Stage 1: DNS Resolution (dnsx)
    if command -v dnsx &> /dev/null; then
        info_msg "Stage 1/2: Running DNS resolution (dnsx)..."
        dnsx -l "$combined_file" -o "$resolved_file" -silent 2>/dev/null || warning_msg "DNS resolution had issues"
        
        local resolved_count
        resolved_count=$(safe_wc "$resolved_file")
        info_msg "Resolved: $resolved_count live DNS entries"
        
        # Stage 2: HTTP Probing (httpx only on resolved domains)
        if command -v httpx &> /dev/null && [[ $resolved_count -gt 0 ]]; then
            info_msg "Stage 2/2: Running HTTP probe (httpx)..."
            httpx -l "$resolved_file" -sc -title -o "$live_file" -silent 2>/dev/null || warning_msg "HTTP probing had issues"
            info_msg "HTTP probing completed"
        else
            [[ $resolved_count -gt 0 ]] && warning_msg "httpx not found - cannot probe resolved domains" || true
            touch "$live_file"
        fi
    else
        warning_msg "dnsx not found - falling back to httpx direct probing"
        if command -v httpx &> /dev/null; then
            info_msg "Running httpx (this may take a while)..."
            httpx -l "$combined_file" -sc -title -o "$live_file" -silent 2>/dev/null || warning_msg "Httpx failed"
            info_msg "Httpx completed"
        else
            warning_msg "httpx not found - skipping live detection"
            touch "$live_file"
        fi
    fi

    local live_count
    live_count=$(safe_wc "$live_file")
    success_msg "Live detection complete: $live_count live hosts"
    log_action "INFO" "Live results: $live_count hosts"

    echo "$live_count"
}

# ============================================
# MAIN ORCHESTRATION
# ============================================

main_recon() {
    step_msg "Starting reconnaissance pipeline..."
    log_action "INFO" "Target: $TARGET"
    log_action "INFO" "Mode: $MODE"

    # Ensure directories exist
    mkdir -p "$RECON_DIR" "$SCANS_DIR" "$SCREENSHOTS_DIR" "$REPORTS_DIR" "$LOG_DIR" || error_msg "Cannot create output directories"

    # Step 1: Passive enumeration
    local passive_count
    passive_count=$(run_passive_enumeration)

    # Step 2: Decide based on mode
    case "$MODE" in
        passive)
            info_msg "Mode: PASSIVE ONLY"
            touch "${RECON_DIR}/active_subdomains.txt"
            ;;
        full|active)
            info_msg "Mode: FULL ENUMERATION"
            run_active_enumeration 2>&1 | grep -v '^$' >&2 || true
            ;;
        auto)
            if [[ $passive_count -lt 50 ]]; then
                info_msg "Passive results ($passive_count) < threshold (50), running active enumeration..."
                run_active_enumeration 2>&1 | grep -v '^$' >&2 || true
            else
                info_msg "Passive results ($passive_count) >= threshold (50), skipping active"
                touch "${RECON_DIR}/active_subdomains.txt"
            fi
            ;;
        *)
            error_msg "Unknown mode: $MODE"
            ;;
    esac

    # Step 3: Live detection
    [[ ! -f "${RECON_DIR}/active_subdomains.txt" ]] && touch "${RECON_DIR}/active_subdomains.txt"
    run_live_check 2>&1 | grep -v '^$' >&2 || true

    step_msg "Reconnaissance complete"
}

# ============================================
# JSON OUTPUT (Optional)
# ============================================

output_json_results() {
    local passive="${RECON_DIR}/passive_subdomains.txt"
    local active="${RECON_DIR}/active_subdomains.txt"
    local live="${RECON_DIR}/live_subdomains.txt"

    local passive_count=$(safe_wc "$passive")
    local active_count=$(safe_wc "$active")
    local live_count=$(safe_wc "$live")

    local current_epoch
    current_epoch=$(get_epoch)
    local elapsed=$((current_epoch - START_TIME))

    printf '{\n'
    printf '  "target": "%s",\n' "$TARGET"
    printf '  "version": "%s",\n' "$TOOL_VERSION"
    printf '  "mode": "%s",\n' "$MODE"
    printf '  "results": {\n'
    printf '    "passive": %d,\n' "$passive_count"
    printf '    "active": %d,\n' "$active_count"
    printf '    "live": %d\n' "$live_count"
    printf '  },\n'
    printf '  "duration_ms": %d,\n' "$((elapsed / 1000000))"
    printf '  "timestamp": "%s"\n' "$(get_timestamp)"
    printf '}\n'
}

# ============================================
# MAIN ENTRY POINT
# ============================================

main() {
    parse_arguments "$@"

    show_banner
    load_env
    setup_logging

    # SECURE: Validate and clean TARGET domain
    TARGET=$(clean_domain "$TARGET")
    validate_domain_format "$TARGET" || error_msg "Invalid target domain: $TARGET"

    check_tools
    main_recon

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '\n' >&2
        output_json_results
    fi

    success_msg "All tasks complete!"
    log_action "SUCCESS" "Reconnaissance complete"
}

main "$@"
