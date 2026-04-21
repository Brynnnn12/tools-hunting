#!/bin/bash

# ============================================
# Bug Bounty Target Setup Script v2.0
# Author: Bryan | BRYNNNN12
# Version: 2.0 (Production-Ready)
# Fully Modularized | Security-Focused | Enterprise-Grade
# ============================================

set -euo pipefail

# ============================================
# GLOBAL CONSTANTS
# ============================================

readonly SCRIPT_NAME="$(basename "${BASH_SOURCE[0]}")"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DEFAULT_AUTHOR="Bryan"
readonly DEFAULT_TOOL_VERSION="2.0"
readonly DEFAULT_TARGETS_DIR="${HOME}/bugbounty/targets"

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
TOOL_VERSION="${TOOL_VERSION:-$DEFAULT_TOOL_VERSION}"
TARGETS_DIR="${TARGETS_DIR:-$DEFAULT_TARGETS_DIR}"
LOG_FILE=""
SILENT_MODE=false

# ============================================
# UTILITY FUNCTIONS
# ============================================

get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Initialize logging system
setup_logging() {
    if [[ ! -d "$TARGETS_DIR" ]]; then
        mkdir -p "$TARGETS_DIR" || {
            echo -e "${RED}[❌] ERROR: Cannot create TARGETS_DIR: $TARGETS_DIR${NC}" >&2
            exit 1
        }
    fi

    LOG_FILE="${TARGETS_DIR}/setup.log"
    touch "$LOG_FILE" 2>/dev/null || {
        echo -e "${YELLOW}[⚠] WARNING: Cannot create log file${NC}" >&2
    }
}

# Log action to file and console
log_action() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(get_timestamp)

    if [[ -n "$LOG_FILE" && -w "$LOG_FILE" ]]; then
        echo "[$timestamp] [$level] $message" >> "$LOG_FILE"
    fi

    if [[ "$SILENT_MODE" == "false" ]]; then
        case "$level" in
            ERROR) echo -e "${RED}[❌] $message${NC}" >&2 ;;
            WARNING) echo -e "${YELLOW}[⚠] $message${NC}" >&2 ;;
            INFO) echo -e "${BLUE}[ℹ] $message${NC}" ;;
            SUCCESS) echo -e "${GREEN}[✅] $message${NC}" ;;
            *) echo -e "$message" ;;
        esac
    fi
}

# Convenience functions
error_msg() { log_action "ERROR" "$1"; exit 1; }
warning_msg() { log_action "WARNING" "$1"; }
info_msg() { log_action "INFO" "$1"; }
success_msg() { log_action "SUCCESS" "$1"; }

# ============================================
# DOMAIN VALIDATION
# ============================================

validate_domain() {
    local domain="$1"

    if [[ ! "$domain" =~ ^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 1
    fi

    if [[ "$domain" != *.* ]]; then
        return 1
    fi

    local tld="${domain##*.}"
    if [[ ${#tld} -lt 2 ]]; then
        return 1
    fi

    return 0
}

sanitize_domain() {
    local domain="$1"

    domain="${domain#http://}"
    domain="${domain#https://}"
    domain="${domain#www.}"
    domain="${domain%%/*}"
    domain="${domain%%:*}"
    domain="${domain,,}"

    echo "$domain"
}

# ============================================
# BANNER
# ============================================

show_banner() {
    echo -e "${RED}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║                                                          ║"
    echo "║   ██████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗            ║"
    echo "║   ██╔══██╗██╔══██╗╚██╗ ██╔╝██╔══██╗████╗  ██║            ║"
    echo "║   ██████╔╝██████╔╝ ╚████╔╝ ███████║██╔██╗ ██║            ║"
    echo "║   ██╔══██╗██╔══██╗  ╚██╔╝  ██╔══██║██║╚██╗██║            ║"
    echo "║   ██████╔╝██║  ██║   ██║   ██║  ██║██║ ╚████║            ║"
    echo "║   ╚═════╝ ╚═╝  ╚═╝   ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═══╝            ║"
    echo "║                                                          ║"
    echo "║              TARGET SETUP v$TOOL_VERSION - BY $AUTHOR    ║"
    echo "║         Production-Ready | Fully Modularized             ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo -e "${CYAN}📅 Date: $(date)${NC}"
    echo ""
}

# ============================================
# TARGET MANAGEMENT
# ============================================

list_targets() {
    log_action "INFO" "Listing all targets"

    echo -e "${CYAN}📋 Bug Bounty Targets List:${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

    if [[ ! -d "$TARGETS_DIR" ]]; then
        echo -e "  ${YELLOW}No targets yet${NC}"
    else
        local found=false
        for target in "$TARGETS_DIR"/*/; do
            if [[ -d "$target" ]]; then
                found=true
                local name
                name=$(basename "$target")
                local status_file="$target/status.txt"

                if [[ -f "$status_file" ]]; then
                    local status
                    status=$(head -n 1 "$status_file" 2>/dev/null || echo "unknown")
                    if [[ "$status" == "active" ]]; then
                        echo -e "  ${GREEN}● ACTIVE${NC}   - $name"
                    else
                        echo -e "  ${GRAY}○ INACTIVE${NC} - $name"
                    fi
                else
                    echo -e "  ${YELLOW}? UNKNOWN${NC}  - $name"
                fi
            fi
        done

        if [[ "$found" == false ]]; then
            echo -e "  ${YELLOW}No targets yet${NC}"
        fi
    fi

    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

create_target_structure() {
    local target="$1"
    local base_dir="$2"

    info_msg "Creating directory structure..."

    mkdir -p "$base_dir/recon"
    mkdir -p "$base_dir/scans"
    mkdir -p "$base_dir/screenshots"
    mkdir -p "$base_dir/reports"
    mkdir -p "$base_dir/logs"

    success_msg "Directory structure created"
    log_action "INFO" "Created directory structure for $target"
}

create_env_file() {
    local target="$1"
    local base_dir="$2"
    local env_file="$base_dir/.env"

    info_msg "Creating .env file..."

    cat > "$env_file" << EOF
#!/bin/bash
# ============================================
# Environment Variables - Bug Bounty Target
# Production-Ready Environment File v2.0
# ============================================

# TARGET INFORMATION (REQUIRED - Do not modify)
export TARGET="$target"
export BASE_DIR="$base_dir"

# STANDARD DIRECTORIES (Synchronized with recon.sh)
export RECON_DIR="\${BASE_DIR}/recon"
export SCANS_DIR="\${BASE_DIR}/scans"
export SCREENSHOTS_DIR="\${BASE_DIR}/screenshots"
export REPORTS_DIR="\${BASE_DIR}/reports"
export LOG_DIR="\${BASE_DIR}/logs"

# RECON TOOL CONFIGURATIONS (Optional - Customize as needed)
export RATE_LIMIT=50
export MODE="auto"
export TOOL_VERSION="2.0"

# API KEYS (Add your keys here - Keep secure!)
# export CHAOS_KEY="your_chaos_api_key_here"
# export SHODAN_KEY="your_shodan_api_key_here"

# RESOURCE DIRECTORY for shared files
export RESOURCE_DIR="\${HOME}/.config/recon"

# AUTO-LOAD MESSAGE (disable by setting to 'false')
if [[ "\${_ENV_LOADED:-}" != "true" ]]; then
    export _ENV_LOADED=true
    if [[ "\${BASH_SUBSHELL}" == "0" ]]; then
        echo -e "\033[0;36m═══════════════════════════════════════════════════════════\033[0m"
        echo -e "\033[1;32m✅ Environment Loaded Successfully\033[0m"
        echo -e "\033[0;36m───────────────────────────────────────────────────────────\033[0m"
        echo -e "\033[0;34m🎯 Target:\033[0m           \${TARGET}"
        echo -e "\033[0;34m📁 Base Directory:\033[0m    \${BASE_DIR}"
        echo -e "\033[0;34m🔍 Recon Directory:\033[0m   \${RECON_DIR}"
        echo -e "\033[0;34m🛡️  Scans Directory:\033[0m   \${SCANS_DIR}"
        echo -e "\033[0;34m📋 Logs Directory:\033[0m    \${LOG_DIR}"
        echo -e "\033[0;36m═══════════════════════════════════════════════════════════\033[0m"
    fi
fi
EOF

    success_msg "Environment file created"
    log_action "INFO" "Created .env file for $target"
}

create_notes_file() {
    local target="$1"
    local base_dir="$2"

    info_msg "Creating notes.txt..."

    cat > "$base_dir/notes.txt" << 'NOTES'
╔═══════════════════════════════════════════════════════════════════╗
║                    BUG BOUNTY NOTES                               ║
╚═══════════════════════════════════════════════════════════════════╝

📋 TARGET INFORMATION
═══════════════════════════════════════════════════════════════════
  Target Domain : PLACEHOLDER_DOMAIN
  Created On    : PLACEHOLDER_DATE
  Author        : PLACEHOLDER_AUTHOR
  Status        : ACTIVE

📁 FOLDER STRUCTURE
═══════════════════════════════════════════════════════════════════
  recon/          → Subdomain, IP, URL enumeration results
  scans/          → Tool scan results (nmap, nuclei, ffuf)
  screenshots/    → Visual proof of concept screenshots
  reports/        → Draft reports and writeups
  logs/           → Execution logs from recon.sh

🚀 QUICK START WORKFLOW
═══════════════════════════════════════════════════════════════════
  1. Load Environment:
     $ source .env

  2. Run Reconnaissance:
     $ ../recon.sh
     (recon.sh will read TARGET and BASE_DIR from .env)

  3. View Results:
     $ cat recon/all_subdomains.txt
     $ cat recon/live_subdomains.txt

  4. Manual Testing:
     $ cat recon/live_subdomains.txt | httpx -sc -title
     $ nmap -sCV -oA scans/nmap/results $(head -1 recon/subdomains.txt)

  5. Vulnerability Scanning:
     $ nuclei -l recon/live_subdomains.txt -o scans/nuclei/results.txt

📝 IMPORTANT NOTES
═══════════════════════════════════════════════════════════════════
  ✏️  Document all findings
  📸  Save screenshots in screenshots/
  📄  Create reports in reports/
  🔄  Update tools regularly: go install -u all
  💾  Backup important results
  🔐  Never commit API keys
  📊  Check logs/ for detailed logs

💡 FILE REFERENCE
═══════════════════════════════════════════════════════════════════
  recon/subdomains.txt      → All unique subdomains
  recon/ip_addresses.txt    → IP addresses of targets
  recon/urls.txt            → URLs discovered
  scans/nmap/*.xml          → Nmap scan results
  scans/nuclei/results.txt  → Vulnerability findings
  logs/recon.log            → Recon tool execution log

═══════════════════════════════════════════════════════════════════
  Last Updated: PLACEHOLDER_DATE
═══════════════════════════════════════════════════════════════════
NOTES

    # Replace placeholders
    sed -i "s|PLACEHOLDER_DOMAIN|$target|g" "$base_dir/notes.txt"
    sed -i "s|PLACEHOLDER_DATE|$(date)|g" "$base_dir/notes.txt"
    sed -i "s|PLACEHOLDER_AUTHOR|$AUTHOR|g" "$base_dir/notes.txt"

    success_msg "Notes file created"
}

create_readme_file() {
    local target="$1"
    local base_dir="$2"

    cat > "$base_dir/README.md" << 'README'
# 🎯 Bug Bounty Target: PLACEHOLDER_DOMAIN

**Author:** PLACEHOLDER_AUTHOR | **Created:** PLACEHOLDER_DATE | **Status:** ACTIVE

---

## 📁 Directory Structure

```
target/
├── recon/              # Enumeration results
├── scans/              # Tool scan results
│   ├── nmap/
│   ├── nuclei/
│   └── ffuf/
├── screenshots/        # POC evidence
├── reports/            # Writeups & drafts
├── logs/               # Execution logs
├── .env                # Environment variables
├── notes.txt           # Documentation
└── README.md           # This file
```

## 🚀 Quick Start

```bash
# Load environment
source .env

# Run reconnaissance
../recon.sh

# View results
cat recon/all_subdomains.txt
```

## 🛠 Tools Used

- **Subfinder** - Passive enumeration
- **Assetfinder** - Asset discovery
- **Httpx** - HTTP probing
- **Nuclei** - Vulnerability scanning
- **Nmap** - Port scanning
- **FFUF** - Directory fuzzing

## 📖 Workflow

1. **Source environment:** `source .env`
2. **Run recon:** `../recon.sh`
3. **Check results:** View `recon/live_subdomains.txt`
4. **Manual testing:** Perform targeted vulnerability assessment
5. **Document:** Save findings and screenshots

## 📝 Important

- 📸 Save proof screenshots in `screenshots/`
- 📄 Document findings in `notes.txt`
- 🔐 Never commit `.env` with real API keys
- 💾 Backup important scan results
- 📊 Check `logs/recon.log` for detailed output

---

Happy Hunting! 🎯
README

    sed -i "s|PLACEHOLDER_DOMAIN|$target|g" "$base_dir/README.md"
    sed -i "s|PLACEHOLDER_DATE|$(date)|g" "$base_dir/README.md"
    sed -i "s|PLACEHOLDER_AUTHOR|$AUTHOR|g" "$base_dir/README.md"

    info_msg "Created README.md"
}

deactivate_target() {
    local name="$1"
    local path="$TARGETS_DIR/$name"

    log_action "INFO" "Deactivating: $name"

    if [[ ! -d "$path" ]]; then
        error_msg "Target not found: $name"
    fi

    echo "inactive" > "$path/status.txt"
    echo "Deactivated: $(date)" >> "$path/status.txt"

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
    echo "active" > "$path/status.txt"
    echo "Activated: $(date)" >> "$path/status.txt"

    [[ -f "$path/.env.inactive" ]] && mv "$path/.env.inactive" "$path/.env"

    success_msg "Target activated: $name"
}

# ============================================
# MAIN PROGRAM
# ============================================

setup_logging

if [[ $# -eq 0 ]]; then
    show_banner
    echo -e "${YELLOW}Usage: $SCRIPT_NAME <command> [options]${NC}"
    echo ""
    echo -e "${CYAN}Commands:${NC}"
    echo "  new <domain>        Create new target"
    echo "  list                List all targets"
    echo "  activate <domain>   Activate target"
    echo "  deactivate <domain> Deactivate target"
    echo "  delete <domain>     Delete target (irreversible!)"
    echo ""
    echo -e "${CYAN}Examples:${NC}"
    echo "  $SCRIPT_NAME new example.com"
    echo "  $SCRIPT_NAME list"
    echo "  $SCRIPT_NAME activate example.com"
    echo ""
    exit 1
fi

COMMAND="$1"

case "$COMMAND" in
    new)
        [[ -z "${2:-}" ]] && error_msg "Domain required!"
        TARGET="$2"
        ;;
    list)
        list_targets
        exit 0
        ;;
    activate)
        [[ -z "${2:-}" ]] && error_msg "Target name required!"
        activate_target "$2"
        exit 0
        ;;
    deactivate)
        [[ -z "${2:-}" ]] && error_msg "Target name required!"
        deactivate_target "$2"
        exit 0
        ;;
    delete)
        [[ -z "${2:-}" ]] && error_msg "Target name required!"
        read -p "Delete target '$2'? (y/N): " -n 1 -r answer
        echo
        if [[ "$answer" =~ ^[Yy]$ ]] && [[ -d "$TARGETS_DIR/$2" ]]; then
            rm -rf "$TARGETS_DIR/$2"
            success_msg "Target deleted: $2"
        fi
        exit 0
        ;;
    *)
        error_msg "Unknown command: $COMMAND"
        ;;
esac

# ============================================
# NEW TARGET CREATION
# ============================================

show_banner

log_action "INFO" "Creating new target: $TARGET"

TARGET=$(sanitize_domain "$TARGET")
validate_domain "$TARGET" || error_msg "Invalid domain: $TARGET"

readonly BASE_DIR="$TARGETS_DIR/$TARGET"

echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
info_msg "Target:        ${WHITE}$TARGET${NC}"
info_msg "Base Directory: ${WHITE}$BASE_DIR${NC}"
echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"

if [[ -d "$BASE_DIR" ]]; then
    warning_msg "Target folder already exists!"
    read -p "Recreate? (y/N): " -n 1 -r answer
    echo
    if [[ "$answer" =~ ^[Yy]$ ]]; then
        rm -rf "$BASE_DIR"
        info_msg "Folder removed"
    fi
fi

# Create structure
mkdir -p "$BASE_DIR"
create_target_structure "$TARGET" "$BASE_DIR"

# Create files
echo "active" > "$BASE_DIR/status.txt"
echo "Created: $(date)" >> "$BASE_DIR/status.txt"

create_env_file "$TARGET" "$BASE_DIR"
create_notes_file "$TARGET" "$BASE_DIR"
create_readme_file "$TARGET" "$BASE_DIR"

# Final output
echo ""
echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              ✅ SETUP COMPLETED ✅                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
echo ""
success_msg "Target created: ${WHITE}$TARGET${NC}"
echo -e "${CYAN}📂 Location: ${WHITE}$BASE_DIR${NC}"
echo ""
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo -e "${WHITE}🚀 NEXT STEPS:${NC}"
echo -e "${CYAN}  cd $BASE_DIR${NC}"
echo -e "${CYAN}  source .env${NC}"
echo -e "${CYAN}  cd $SCRIPT_DIR && ./recon.sh${NC}"
echo -e "${GREEN}════════════════════════════════════════════════════════════${NC}"
echo ""

log_action "SUCCESS" "Target created: $TARGET"
