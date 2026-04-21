#!/bin/bash

# ============================================
# Bug Bounty Target Setup Script v1.0
# Author: Bryan | BRYNNNN12
# ============================================

set -euo pipefail
trap 'handle_trap_error "Error on line $LINENO"' ERR

# ============================================
# GLOBAL CONSTANTS
# ============================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly TOOL_VERSION="1.0"
readonly DEFAULT_AUTHOR="Bryan"
readonly DEFAULT_TARGETS_DIR="${HOME}/bugbounty/targets"
readonly MIN_TLD_LENGTH=2

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

AUTHOR="${AUTHOR:-$DEFAULT_AUTHOR}"
TARGETS_DIR="${TARGETS_DIR:-$DEFAULT_TARGETS_DIR}"
LOG_FILE=""
SILENT_MODE=false
FORCE_MODE=false

# ============================================
# ERROR HANDLING
# ============================================

handle_trap_error() {
    local line="$1"
    local exit_code="${2:-$?}"
    log_error "$line (exit code: $exit_code)"
    exit "$exit_code"
}

# ============================================
# LOGGING FUNCTIONS
# ============================================

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

log_action() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)

    if [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]]; then
        printf '[%s] [%s] %s\n' "$timestamp" "$level" "$message" >> "$LOG_FILE"
    fi

    if [[ "$SILENT_MODE" == "false" ]]; then
        case "$level" in
            ERROR)   printf '%b[❌] %s%b\n' "${RED}" "$message" "${NC}" >&2 ;;
            WARNING) printf '%b[⚠]  %s%b\n' "${YELLOW}" "$message" "${NC}" >&2 ;;
            INFO)    printf '%b[ℹ]  %s%b\n' "${BLUE}" "$message" "${NC}" ;;
            SUCCESS) printf '%b[✅] %s%b\n' "${GREEN}" "$message" "${NC}" ;;
            *)       printf '%s\n' "$message" ;;
        esac
    fi
}

error_msg()   { log_action "ERROR" "$1"; exit 1; }
warning_msg() { log_action "WARNING" "$1"; }
info_msg()    { log_action "INFO" "$1"; }
success_msg() { log_action "SUCCESS" "$1"; }

# ============================================
# UTILITY FUNCTIONS
# ============================================

setup_logging() {
    if [[ ! -d "$TARGETS_DIR" ]]; then
        mkdir -p "$TARGETS_DIR" || error_msg "Cannot create TARGETS_DIR: $TARGETS_DIR"
    fi

    LOG_FILE="${TARGETS_DIR}/setup.log"
    if ! touch "$LOG_FILE" 2>/dev/null; then
        warning_msg "Cannot create log file: $LOG_FILE (continuing without logging)"
        LOG_FILE=""
    fi
}

# ============================================
# VALIDATION FUNCTIONS
# ============================================

validate_domain() {
    local domain="$1"

    # Check for empty or whitespace-only domain
    if [[ -z "$domain" || "$domain" =~ ^[[:space:]]*$ ]]; then
        return 1
    fi

    # Check regex: valid domain format
    if ! [[ "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi

    # Must contain at least one dot
    if [[ "$domain" != *.* ]]; then
        return 1
    fi

    # TLD must be at least 2 characters
    local tld="${domain##*.}"
    if [[ ${#tld} -lt $MIN_TLD_LENGTH ]]; then
        return 1
    fi

    # Check for double dots
    if [[ "$domain" =~ \.\. ]]; then
        return 1
    fi

    return 0
}

sanitize_domain() {
    local domain="$1"

    # Remove protocol
    domain="${domain#http://}"
    domain="${domain#https://}"

    # Remove www prefix
    domain="${domain#www.}"

    # Remove path
    domain="${domain%%/*}"

    # Remove port
    domain="${domain%%:*}"

    # Lowercase
    domain="${domain,,}"

    echo "$domain"
}

validate_target_dir() {
    local base_dir="$1"

    # Must not be empty
    if [[ -z "$base_dir" ]]; then
        error_msg "BASE_DIR cannot be empty"
    fi

    # Must not be root
    if [[ "$base_dir" == "/" ]]; then
        error_msg "BASE_DIR cannot be root directory"
    fi

    # Must not be home (too broad)
    if [[ "$base_dir" == "$HOME" ]]; then
        error_msg "BASE_DIR cannot be home directory (too broad)"
    fi

    return 0
}

print_banner() {
    printf '%b' "${RED}"
    cat << 'BANNER'
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║   ██████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗            ║
║   ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗████╗  ██║            ║
║   ██████╔╝██████╔╝ ╚████╔╝ ███████║██╔██╗ ██║            ║
║   ██╔══██╗██╔══██╗  ╚██╔╝  ██╔══██║██║╚██╗██║            ║
║   ██████╔╝██║  ██║   ██║   ██║  ██║██║ ╚████║            ║
║   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝            ║
║                                                          ║
║         TARGET SETUP v1.0 - BY BRYNNNN12                 ║
╚══════════════════════════════════════════════════════════╝
BANNER
    printf '%b' "${NC}"
}

print_help() {
    printf '\n'
    cat << 'HELP'
PEMAKAIAN:
  target.sh [PERINTAH] [OPSI]

PERINTAH:
  new <domain>           Membuat target baru
  list                   Daftar semua target
  activate <domain>      Aktifkan target
  deactivate <domain>    Nonaktifkan target
  delete <domain>        Hapus target (tidak dapat dikembalikan)

OPSI:
  -f, --force            Lewati prompt konfirmasi
  -s, --silent           Mode senyap (tanpa output)
  -h, --help             Tampilkan pesan bantuan ini
  -v, --version          Tampilkan versi

CONTOH:
  target.sh new example.com
  target.sh list
  target.sh activate example.com

HELP
}

show_help() {
    print_banner
    print_help
}

show_version() {
    printf 'target.sh v%s\n' "$TOOL_VERSION"
}

# ============================================
# FILE OPERATIONS (Safe)
# ============================================

create_target_structure() {
    local target="$1"
    local base_dir="$2"

    info_msg "Creating directory structure..."

    mkdir -p "$base_dir/recon" \
             "$base_dir/scans" \
             "$base_dir/screenshots" \
             "$base_dir/reports" \
             "$base_dir/logs" || error_msg "Failed to create directories"

    success_msg "Directory structure created"
    log_action "INFO" "Created directory structure for $target"
}

create_env_file() {
    local target="$1"
    local base_dir="$2"
    local env_file="$base_dir/.env"
    local temp_env

    info_msg "Creating .env file..."

    # Create temp file first
    temp_env=$(mktemp) || error_msg "Cannot create temporary file"
    trap "rm -f '$temp_env'" RETURN

    cat > "$temp_env" << 'ENVEOF'
#!/bin/bash
# ============================================
# Environment Variables - Bug Bounty Target
# Production-Ready Environment File v1.0
# DO NOT MODIFY CORE VARIABLES
# ============================================

# CORE VARIABLES (REQUIRED - synchronized with recon.sh)
export TARGET="TARGET_PLACEHOLDER"
export BASE_DIR="BASEDIR_PLACEHOLDER"

# STANDARD DIRECTORIES (DO NOT MODIFY)
export RECON_DIR="${BASE_DIR}/recon"
export SCANS_DIR="${BASE_DIR}/scans"
export SCREENSHOTS_DIR="${BASE_DIR}/screenshots"
export REPORTS_DIR="${BASE_DIR}/reports"
export LOG_DIR="${BASE_DIR}/logs"

# RECON TOOL CONFIGURATIONS (Optional)
export RATE_LIMIT=50
export MODE="auto"
export TOOL_VERSION="1.0"

# API KEYS (Configure as needed - Keep secure!)
# export CHAOS_KEY="your_key_here"
# export SHODAN_KEY="your_key_here"

# RESOURCE DIRECTORY for shared files
export RESOURCE_DIR="${HOME}/.config/recon"
ENVEOF

    # Safe replacement using sed on temp file
    sed "s|TARGET_PLACEHOLDER|$target|g" "$temp_env" > "${temp_env}.1"
    sed "s|BASEDIR_PLACEHOLDER|$base_dir|g" "${temp_env}.1" > "$env_file"
    rm -f "${temp_env}.1"

    # Set secure permissions
    chmod 600 "$env_file" || error_msg "Cannot set permissions on .env file"

    success_msg "Environment file created"
    log_action "INFO" "Created .env file for $target"
}

create_notes_file() {
    local target="$1"
    local base_dir="$2"
    local notes_file="$base_dir/notes.txt"
    local temp_notes

    info_msg "Creating notes.txt..."

    temp_notes=$(mktemp) || error_msg "Cannot create temporary file"
    trap "rm -f '$temp_notes'" RETURN

    cat > "$temp_notes" << 'NOTES'
╔═══════════════════════════════════════════════════════════════════╗
║                    BUG BOUNTY NOTES                               ║
╚═══════════════════════════════════════════════════════════════════╝

📋 TARGET INFORMATION
═══════════════════════════════════════════════════════════════════
  Target Domain : TARGET_PLACEHOLDER
  Created On    : DATE_PLACEHOLDER
  Author        : AUTHOR_PLACEHOLDER
  Status        : ACTIVE

📁 FOLDER STRUCTURE
═══════════════════════════════════════════════════════════════════
  recon/          → Subdomain enumeration results
  scans/          → Tool scan results
  screenshots/    → Proof of concept evidence
  reports/        → Findings documentation
  logs/           → Execution logs

🚀 QUICK START
═══════════════════════════════════════════════════════════════════
  1. source .env
  2. ../recon.sh
  3. View results in recon/all_subdomains.txt

📝 IMPORTANT
═══════════════════════════════════════════════════════════════════
  ✏️  Document findings
  📸  Save screenshots
  🔐  Never commit API keys
  💾  Backup results
  📊  Check logs/recon.log

═══════════════════════════════════════════════════════════════════
NOTES

    # Safe replacement on temp file
    sed "s|TARGET_PLACEHOLDER|$target|g" "$temp_notes" > "${temp_notes}.1"
    sed "s|DATE_PLACEHOLDER|$(date)|g" "${temp_notes}.1" > "${temp_notes}.2"
    sed "s|AUTHOR_PLACEHOLDER|$AUTHOR|g" "${temp_notes}.2" > "$notes_file"
    rm -f "${temp_notes}.1" "${temp_notes}.2"

    success_msg "Notes file created"
}

create_readme_file() {
    local target="$1"
    local base_dir="$2"
    local readme_file="$base_dir/README.md"
    local temp_readme

    temp_readme=$(mktemp) || error_msg "Cannot create temporary file"
    trap "rm -f '$temp_readme'" RETURN

    cat > "$temp_readme" << 'README'
# 🎯 Bug Bounty Target: TARGET_PLACEHOLDER

**Author:** AUTHOR_PLACEHOLDER | **Created:** DATE_PLACEHOLDER | **Status:** ACTIVE

## 📁 Directory Structure

```
target/
├── recon/              # Enumeration results
├── scans/              # Tool scan results
├── screenshots/        # POC evidence
├── reports/            # Writeups & drafts
├── logs/               # Execution logs
├── .env                # Environment variables
├── notes.txt           # Documentation
└── README.md           # This file
```

## 🚀 Quick Start

```bash
source .env
../recon.sh
cat recon/all_subdomains.txt
```

## 📝 Important

- Never commit `.env` with real API keys
- Backup important scan results
- Check `logs/recon.log` for detailed output

---

Happy Hunting! 🎯
README

    # Safe replacement on temp file
    sed "s|TARGET_PLACEHOLDER|$target|g" "$temp_readme" > "${temp_readme}.1"
    sed "s|AUTHOR_PLACEHOLDER|$AUTHOR|g" "${temp_readme}.1" > "${temp_readme}.2"
    sed "s|DATE_PLACEHOLDER|$(date)|g" "${temp_readme}.2" > "$readme_file"
    rm -f "${temp_readme}.1" "${temp_readme}.2"

    info_msg "Created README.md"
}

deactivate_target() {
    local name="$1"
    local path="$TARGETS_DIR/$name"

    log_action "INFO" "Deactivating: $name"

    if [[ ! -d "$path" ]]; then
        error_msg "Target not found: $name"
    fi

    printf 'inactive\nDeactivated: %s\n' "$(date)" > "$path/status.txt"
    [[ -f "$path/.env" ]] && mv "$path/.env" "$path/.env.inactive"
    touch "$path/INACTIVE"

    success_msg "Target deactivated: $name"
}

activate_target() {
    local name="$1"
    local path="$TARGETS_DIR/$name"

    log_action "INFO" "Activating: $name"

    if [[ ! -d "$path" ]]; then
        error_msg "Target not found: $name"
    fi

    rm -f "$path/INACTIVE"
    printf 'active\nActivated: %s\n' "$(date)" > "$path/status.txt"
    [[ -f "$path/.env.inactive" ]] && mv "$path/.env.inactive" "$path/.env"

    success_msg "Target activated: $name"
}

delete_target() {
    local name="$1"
    local path="$TARGETS_DIR/$name"

    if [[ ! -d "$path" ]]; then
        error_msg "Target not found: $name"
    fi

    if [[ "$FORCE_MODE" == "false" ]]; then
        local answer
        printf 'Delete target %b%s%b? (y/N): ' "${RED}" "$name" "${NC}"
        read -r -n 1 answer
        printf '\n'
        if [[ ! "$answer" =~ ^[Yy]$ ]]; then
            info_msg "Deletion cancelled"
            return 0
        fi
    fi

    rm -rf "$path" || error_msg "Failed to delete target: $name"
    success_msg "Target deleted: $name"
    log_action "INFO" "Deleted: $name"
}

# ============================================
# TARGET MANAGEMENT
# ============================================

list_targets() {
    log_action "INFO" "Listing targets"

    printf '%b📋 Bug Bounty Targets:%b\n' "${CYAN}" "${NC}"
    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${PURPLE}" "${NC}"

    if [[ ! -d "$TARGETS_DIR" ]]; then
        printf '%bNo targets yet%b\n' "${YELLOW}" "${NC}"
        return 0
    fi

    local found=false
    local target_count=0
    for target_path in "$TARGETS_DIR"/*/; do
        [[ ! -d "$target_path" ]] && continue
        found=true
        ((target_count++))

        local name
        name=$(basename "$target_path")
        local status_file="$target_path/status.txt"
        local status="unknown"

        if [[ -f "$status_file" ]]; then
            status=$(head -n 1 "$status_file" 2>/dev/null || echo "unknown")
        fi

        case "$status" in
            active)   printf '%b● ACTIVE%b   - %s\n' "${GREEN}" "${NC}" "$name" ;;
            inactive) printf '%b○ INACTIVE%b - %s\n' "${GRAY}" "${NC}" "$name" ;;
            *)        printf '%b? UNKNOWN%b  - %s\n' "${YELLOW}" "${NC}" "$name" ;;
        esac
    done

    if [[ "$found" == "false" ]]; then
        printf '%bNo targets found%b\n' "${YELLOW}" "${NC}"
    else
        printf '%bTotal: %d%b\n' "${CYAN}" "$target_count" "${NC}"
    fi

    printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${PURPLE}" "${NC}"
}

# ============================================
# MAIN PROGRAM
# ============================================

main() {
    # Parse global options directly without subshell
    local -a remaining_args=()
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--force)  
                FORCE_MODE=true
                shift
                ;;
            -s|--silent) 
                SILENT_MODE=true
                shift
                ;;
            -h|--help)   
                print_banner
                print_help
                exit 0
                ;;
            -v|--version) 
                show_version
                exit 0
                ;;
            -*)          
                error_msg "Unknown option: $1"
                ;;
            *)           
                remaining_args+=("$1")
                shift
                ;;
        esac
    done

    setup_logging

    # Require at least one command
    if [[ ${#remaining_args[@]} -eq 0 ]]; then
        print_banner
        printf '%bDate: %s%b\n' "${CYAN}" "$(date)" "${NC}"
        printf '\n%bUsage: %s <command> [options]%b\n' "${YELLOW}" "$SCRIPT_NAME" "${NC}"
        printf '\nRun with --help for more information\n'
        exit 1
    fi

    local command="${remaining_args[0]}"
    local -a cmd_args=("${remaining_args[@]:1}")

    case "$command" in
        new)
            [[ ${#cmd_args[@]} -eq 0 ]] && error_msg "Domain required"
            print_banner
            printf '\n'

            local target="${cmd_args[0]}"
            target=$(sanitize_domain "$target")
            validate_domain "$target" || error_msg "Invalid domain: $target"

            local base_dir="$TARGETS_DIR/$target"
            validate_target_dir "$base_dir"

            printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${PURPLE}" "${NC}"
            info_msg "Target:        $target"
            info_msg "Base Directory: $base_dir"
            printf '%b━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━%b\n' "${PURPLE}" "${NC}"

            if [[ -d "$base_dir" ]]; then
                warning_msg "Target folder already exists"
                if [[ "$FORCE_MODE" == "false" ]]; then
                    local answer
                    printf 'Recreate? (y/N): '
                    read -r -n 1 answer
                    printf '\n'
                    if [[ ! "$answer" =~ ^[Yy]$ ]]; then
                        info_msg "Creation cancelled"
                        exit 0
                    fi
                fi
                rm -rf "$base_dir" || error_msg "Cannot remove existing directory"
                info_msg "Existing folder removed"
            fi

            mkdir -p "$base_dir" || error_msg "Cannot create base directory"
            create_target_structure "$target" "$base_dir"

            # Create status file
            printf 'active\nCreated: %s\n' "$(date)" > "$base_dir/status.txt"

            # Create configuration files
            create_env_file "$target" "$base_dir"
            create_notes_file "$target" "$base_dir"
            create_readme_file "$target" "$base_dir"

            printf '\n'
            printf '%b╔════════════════════════════════════════════════════╗%b\n' "${GREEN}" "${NC}"
            printf '%b║              ✅ SETUP COMPLETED ✅                 ║%b\n' "${GREEN}" "${NC}"
            printf '%b╚════════════════════════════════════════════════════╝%b\n' "${GREEN}" "${NC}"
            success_msg "Target created: $target"
            printf '%bLocation: %s%b\n' "${CYAN}" "$base_dir" "${NC}"
            printf '\n%bNEXT STEPS:%b\n' "${GREEN}" "${NC}"
            printf '  cd %s\n' "$base_dir"
            printf '  source .env\n'
            printf '  %s/recon.sh\n' "$SCRIPT_DIR"
            printf '\n'

            log_action "SUCCESS" "Target created: $target"
            ;;

        list)
            print_banner
            printf '%bDate: %s%b\n' "${CYAN}" "$(date)" "${NC}"
            printf '\n'
            list_targets
            ;;

        activate)
            [[ ${#cmd_args[@]} -eq 0 ]] && error_msg "Target name required for 'activate' command"
            activate_target "${cmd_args[0]}"
            ;;

        deactivate)
            [[ ${#cmd_args[@]} -eq 0 ]] && error_msg "Target name required for 'deactivate' command"
            deactivate_target "${cmd_args[0]}"
            ;;

        delete)
            [[ ${#cmd_args[@]} -eq 0 ]] && error_msg "Target name required for 'delete' command"
            delete_target "${cmd_args[0]}"
            ;;

        *)
            error_msg "Unknown command: $command"
            ;;
    esac
}

main "$@"
