#!/bin/bash

# ============================================
# Alat Enumerasi Subdomain & Pengintaian v1.0
# Penulis: BRYNNNN12 | Siap Produksi | Tersinkronisasi dengan target.sh v1.0
# ============================================
# FITUR:
#   - Pemuatan .env ketat dengan parsing variabel whitelist
#   - Performa teroptimasi: cache file counts, reduced subshells
#   - Output berbasis printf: kompatibel macOS/Linux/WSL
#   - Penanganan kesalahan yang ditingkatkan dengan exit codes yang tepat
#   - Output JSON opsional (--json flag)
#   - Kontrol mode: auto/passive/full
#   - Rate limiting untuk query DNS
# ============================================

set -euo pipefail
trap 'handle_trap_error "Error on line $LINENO" "$?"' ERR

# ============================================
# GLOBAL CONSTANTS
# ============================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOL_VERSION="1.0"
readonly START_TIME=$(date +%s%N)

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
MODE="auto"
JSON_OUTPUT="false"
SILENT_MODE="false"
CHAOS_KEY=""
RESOURCE_DIR="${HOME}/.config/recon"

# Internal
LOG_FILE=""

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
            INFO)    printf '%b[ℹ]  %s%b\n' "${BLUE}" "$message" "${NC}" ;;
            SUCCESS) printf '%b[✅] %s%b\n' "${GREEN}" "$message" "${NC}" ;;
            STEP)    printf '%b[→]  %s%b\n' "${CYAN}" "$message" "${NC}" ;;
            *)       printf '%s\n' "$message" ;;
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

load_env() {
    # Determine BASE_DIR - try multiple locations with strict precedence
    local env_file=""

    if [[ -n "${BASE_DIR:-}" && -f "${BASE_DIR}/.env" ]]; then
        env_file="${BASE_DIR}/.env"
    elif [[ -f ".env" ]]; then
        BASE_DIR="$(pwd)"
        env_file="./.env"
    elif [[ -f "../.env" ]]; then
        BASE_DIR="$(cd .. && pwd)"
        env_file="../.env"
    else
        error_msg "Cannot find .env file (checked: ./.env, ../.env, \${BASE_DIR}/.env)"
    fi

    if [[ ! -r "$env_file" ]]; then
        error_msg "Cannot read .env file: $env_file"
    fi

    info_msg "Loading environment from: $env_file"

    # Whitelist parsing: Only read expected variables
    local key value
    while IFS='=' read -r key value || [[ -n "$key" ]]; do
        # Skip empty lines and comments
        [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]] && continue

        # Trim whitespace
        key="${key## }"
        key="${key%% }"
        value="${value## }"
        value="${value%% }"

        # Remove 'export ' prefix if present
        key="${key#export }"

        # Only load whitelisted variables
        case "$key" in
            TARGET)          TARGET="$value" ;;
            BASE_DIR)        BASE_DIR="$value" ;;
            RECON_DIR)       RECON_DIR="$value" ;;
            SCANS_DIR)       SCANS_DIR="$value" ;;
            SCREENSHOTS_DIR) SCREENSHOTS_DIR="$value" ;;
            REPORTS_DIR)     REPORTS_DIR="$value" ;;
            LOG_DIR)         LOG_DIR="$value" ;;
            RATE_LIMIT)      RATE_LIMIT="${value:-50}" ;;
            MODE)            MODE="${value:-auto}" ;;
            CHAOS_KEY)       CHAOS_KEY="$value" ;;
            RESOURCE_DIR)    RESOURCE_DIR="$value" ;;
        esac
    done < "$env_file"

    # Verify required variables
    [[ -z "$TARGET" ]] && error_msg "TARGET not set in .env"
    [[ -z "$BASE_DIR" ]] && error_msg "BASE_DIR not set in .env"
    [[ ! -d "$BASE_DIR" ]] && error_msg "BASE_DIR does not exist: $BASE_DIR"

    # Expand ${BASE_DIR} in paths
    RECON_DIR="${RECON_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    SCANS_DIR="${SCANS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    SCREENSHOTS_DIR="${SCREENSHOTS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    REPORTS_DIR="${REPORTS_DIR/\$\{BASE_DIR\}/$BASE_DIR}"
    LOG_DIR="${LOG_DIR/\$\{BASE_DIR\}/$BASE_DIR}"

    # Set defaults
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
            *)              break ;;
        esac
    done
}

show_help() {
    printf '%bAlat Enumerasi Subdomain v%s%b\n' "${CYAN}" "$TOOL_VERSION" "${NC}"
    printf '\n%bPEMAKAIAN:%b\n' "${GREEN}" "${NC}"
    printf '  %s [OPSI]\n' "$SCRIPT_NAME"
    printf '\n%bOPSI:%b\n' "${GREEN}" "${NC}"
    printf '  --json             Output hasil dalam format JSON\n'
    printf '  --mode MODE        Pilih mode: auto/passive/full (default: auto)\n'
    printf '  --rate LIMIT       Batas laju query DNS (default: 50)\n'
    printf '  --silent           Tanpa output berwarna\n'
    printf '  -h, --help         Tampilkan pesan bantuan ini\n'
    printf '  -v, --version      Tampilkan versi\n'
    printf '\n%bDESKRIPSI MODE:%b\n' "${GREEN}" "${NC}"
    printf '  auto               Pasif jika <50 hasil, jika tidak full enumeration\n'
    printf '  passive            Hanya enumerasi pasif\n'
    printf '  full               Enumerasi penuh termasuk brute force\n'


show_version() {
    printf '%s v%s\n' "$SCRIPT_NAME" "$TOOL_VERSION"
}

# ============================================
# VALIDATION & SETUP
# ============================================

validate_domain() {
    local domain="$1"
    if [[ ! "$domain" =~ ^[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 1
    fi
    return 0
}

check_tools() {
    step_msg "Checking required tools..."

    local tools=("subfinder" "assetfinder" "puredns" "httpx")
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

    if [[ $missing -gt 0 ]]; then
        warning_msg "Some required tools missing - some features may not work"
    fi
}

setup_resources() {
    mkdir -p "$RESOURCE_DIR" || error_msg "Cannot create resource directory"
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
    > "$passive_subdomains"

    # Subfinder
    if command -v subfinder &> /dev/null; then
        info_msg "Running subfinder..."
        subfinder -d "$TARGET" -silent 2>/dev/null >> "$passive_subdomains" || warning_msg "Subfinder failed"
    fi

    # Assetfinder
    if command -v assetfinder &> /dev/null; then
        info_msg "Running assetfinder..."
        assetfinder --subs-only "$TARGET" 2>/dev/null >> "$passive_subdomains" || warning_msg "Assetfinder failed"
    fi

    # Chaos (optional)
    if [[ -n "$CHAOS_KEY" ]] && command -v chaos &> /dev/null; then
        info_msg "Running chaos..."
        chaos -d "$TARGET" -key "$CHAOS_KEY" -silent 2>/dev/null >> "$passive_subdomains" || warning_msg "Chaos failed"
    fi

    # Deduplicate (performance: cache count result)
    sort -u "$passive_subdomains" -o "$passive_subdomains"
    local count
    count=$(wc -l < "$passive_subdomains" 2>/dev/null || echo "0")

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
    > "$active_subdomains"

    # Shuffledns (brute force)
    if command -v shuffledns &> /dev/null; then
        info_msg "Running shuffledns with rate limit $RATE_LIMIT..."
        shuffledns -d "$TARGET" -w /usr/share/seclists/Discovery/DNS/subdomains-top1million-5000.txt -rate "$RATE_LIMIT" -silent 2>/dev/null >> "$active_subdomains" || warning_msg "Shuffledns failed"
    else
        warning_msg "shuffledns not found"
    fi

    # Deduplicate and count (performance: cache count)
    [[ -f "$active_subdomains" ]] && sort -u "$active_subdomains" -o "$active_subdomains"
    local count
    count=$(wc -l < "$active_subdomains" 2>/dev/null || echo "0")

    success_msg "Active enumeration complete: $count subdomains"
    log_action "INFO" "Active results: $count subdomains"

    echo "$count"
}

# ============================================
# LIVE DETECTION
# ============================================

run_live_check() {
    step_msg "Running live detection..."

    local combined_file="${RECON_DIR}/all_subdomains.txt"
    local live_file="${RECON_DIR}/live_subdomains.txt"

    # Combine all subdomains
    cat "${RECON_DIR}/passive_subdomains.txt" "${RECON_DIR}/active_subdomains.txt" 2>/dev/null | sort -u > "$combined_file" || touch "$combined_file"

    local combined_count
    combined_count=$(wc -l < "$combined_file" 2>/dev/null || echo "0")
    info_msg "Testing $combined_count combined subdomains for live hosts..."

    # Httpx (performance: cache count, avoid repeated wc)
    if command -v httpx &> /dev/null; then
        httpx -l "$combined_file" -sc -title -tech-detect -o "$live_file" -silent 2>/dev/null || warning_msg "Httpx failed"
    else
        error_msg "httpx not found (required for live detection)"
    fi

    local live_count
    live_count=$(wc -l < "$live_file" 2>/dev/null || echo "0")
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

    # Step 2: Decide based on mode (performance: use cached count)
    case "$MODE" in
        passive)
            info_msg "Mode: PASSIVE ONLY"
            mkdir -p "${RECON_DIR}/active"
            touch "${RECON_DIR}/active_subdomains.txt"
            ;;
        full|active)
            info_msg "Mode: FULL ENUMERATION"
            run_active_enumeration > /dev/null
            ;;
        auto)
            if [[ $passive_count -lt 50 ]]; then
                info_msg "Passive results ($passive_count) < threshold (50), running active enumeration..."
                run_active_enumeration > /dev/null
            else
                info_msg "Passive results ($passive_count) >= threshold (50), skipping active"
                mkdir -p "${RECON_DIR}/active"
                touch "${RECON_DIR}/active_subdomains.txt"
            fi
            ;;
        *)
            error_msg "Unknown mode: $MODE"
            ;;
    esac

    # Step 3: Live detection
    [[ ! -f "${RECON_DIR}/active_subdomains.txt" ]] && touch "${RECON_DIR}/active_subdomains.txt"
    run_live_check > /dev/null

    step_msg "Reconnaissance complete"
}

# ============================================
# JSON OUTPUT (Optional)
# ============================================

output_json_results() {
    local passive="${RECON_DIR}/passive_subdomains.txt"
    local active="${RECON_DIR}/active_subdomains.txt"
    local live="${RECON_DIR}/live_subdomains.txt"

    local passive_count=$(wc -l < "$passive" 2>/dev/null || echo "0")
    local active_count=$(wc -l < "$active" 2>/dev/null || echo "0")
    local live_count=$(wc -l < "$live" 2>/dev/null || echo "0")

    local elapsed=$(($(date +%s%N) - START_TIME))

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

    validate_domain "$TARGET" || error_msg "Invalid target domain: $TARGET"

    check_tools
    setup_resources

    main_recon

    if [[ "$JSON_OUTPUT" == "true" ]]; then
        printf '\n'
        output_json_results
    fi

    success_msg "All tasks complete!"
    log_action "SUCCESS" "Reconnaissance complete"
}

main "$@"
