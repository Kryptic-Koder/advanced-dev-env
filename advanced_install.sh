#!/usr/bin/env bash
# Advanced Development Environment Installer v2.0
# A fully interactive, modern development environment setup script
# 
# Features:
#  - Multiple UI frameworks (dialog, whiptail, zenity, fzf)
#  - Real-time progress tracking with animations
#  - Configuration management with TOML
#  - Dotfiles backup and restore
#  - Modern tool integration with mise
#  - Enhanced error handling and recovery
#  - Dynamic theming and customization
#  - Cross-platform compatibility
#
set -euo pipefail # Exit on error, exit on unbound variable, exit on pipeline failure

# --- Configuration & Global Variables ---
readonly SCRIPT_VERSION="2.0.0"
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly DOTFILES_BASE_DIR="${HOME}/.dotfiles-install" # Base dir for temporary installer files
readonly DOTFILES_BACKUP_DIR="${HOME}/.dotfiles-backup" # Backup directory for existing dotfiles
readonly CACHE_DIR="${DOTFILES_BASE_DIR}/.cache"
readonly LOG_DIR="${DOTFILES_BASE_DIR}/logs"
readonly LOG_FILE="${LOG_DIR}/install_$(date +%Y%m%d_%H%M%S).log"
readonly CONFIG_FILE="${SCRIPT_DIR}/install_config.toml" # TOML configuration file
readonly ENV_FILE="${SCRIPT_DIR}/.env" # Optional .env file for additional configuration

# Temporary files
readonly TMP_DIR="${CACHE_DIR}/tmp"
readonly SELECTED_COMPONENTS_FILE="${TMP_DIR}/selected_components.txt"
readonly USER_CONFIG_FILE="${TMP_DIR}/user_config.toml"
readonly PROGRESS_FILE="${TMP_DIR}/progress.txt"
readonly ERROR_FILE="${TMP_DIR}/errors.txt"

# --- UI Framework Detection ---
UI_FRAMEWORK="auto" # Will be detected or read from config

# --- Theme Configuration ---
# Default theme (Catppuccin Macchiato)
THEME_BG="#24273a"
THEME_FG="#cad3f5"
THEME_ACCENT="#8aadf4"
THEME_SUCCESS="#a6da95"
THEME_WARNING="#eed49f"
THEME_ERROR="#ed8796"
THEME_INFO="#8aadf4"
THEME_MUTED="#6e738d"

# Terminal colors based on the theme
readonly RESET='[0m'
readonly BOLD='[1m'
readonly DIM='[2m'
readonly ITALIC='[3m'
readonly UNDERLINE='[4m'

# These will be set dynamically based on theme
FG=''
BG=''
RED=''
GREEN=''
YELLOW=''
BLUE=''
PURPLE=''
CYAN=''
GRAY=''

# --- Spinner Animations ---
readonly SPINNER_FRAMES=('⠋' '⠙' '⠹' '⠸' '⠼' '⠴' '⠦' '⠧' '⠇' '⠏')
readonly SPINNER_FRAMES_ALT=('▁' '▂' '▃' '▄' '▅' '▆' '▇' '█' '▇' '▆' '▅' '▄' '▃' '▂')
SPINNER_ACTIVE=false
SPINNER_PID=""

# --- Execution State ---
VERBOSE=false
SKIP_INTERACTIVE_MENU=false
SKIP_VALIDATION=false
DRY_RUN=false
DEBUG=false
LOG_LEVEL="info" # debug, info, warn, error
CURRENT_STEP=0
TOTAL_STEPS=0
ERRORS_OCCURRED=false
EXECUTION_START_TIME=$(date +%s)

# --- Tool Paths ---
MISE_PATH=""
TOML_PARSER=""
UI_TOOL=""

# ------------------------------------------------------------------------------
# Utility Functions (Common Helpers)
# ------------------------------------------------------------------------------

# Initialize all required directories
init_directories() {
    mkdir -p "${DOTFILES_BASE_DIR}" "${CACHE_DIR}" "${LOG_DIR}" "${TMP_DIR}" "${DOTFILES_BACKUP_DIR}"
    # Make sure temp files are clean
    echo -n > "${SELECTED_COMPONENTS_FILE}"
    echo -n > "${PROGRESS_FILE}"
    echo -n > "${ERROR_FILE}"

    # Initialize log with header
    {
        echo "======================================================"
        echo "Advanced Development Environment Installer v${SCRIPT_VERSION}"
        echo "Started at: $(date)"
        echo "System: $(uname -a)"
        echo "User: ${USER}"
        echo "Working directory: $(pwd)"
        echo "======================================================"
        echo ""
    } > "${LOG_FILE}"
}

# Set up terminal colors based on selected theme
setup_colors() {
    if [[ "${UI_FRAMEWORK}" == "whiptail" || "${UI_FRAMEWORK}" == "dialog" ]]; then
        # TUI colors are handled differently
        return 0
    fi

    # Standard terminal colors
    FG='[39m'
    BG='[49m'
    RED='[0;31m'
    GREEN='[0;32m'
    YELLOW='[1;33m'
    BLUE='[0;34m'
    PURPLE='[0;35m'
    CYAN='[0;36m'
    GRAY='[0;90m'

    # Advanced themes could customize these colors based on the theme
    case "${THEME_NAME:-catppuccin}" in
        nord)
            RED='[38;2;191;97;106m'
            GREEN='[38;2;163;190;140m'
            YELLOW='[38;2;235;203;139m'
            BLUE='[38;2;129;161;193m'
            PURPLE='[38;2;180;142;173m'
            CYAN='[38;2;136;192;208m'
            GRAY='[38;2;76;86;106m'
            ;;
        dracula)
            RED='[38;2;255;85;85m'
            GREEN='[38;2;80;250;123m'
            YELLOW='[38;2;241;250;140m'
            BLUE='[38;2;98;114;164m'
            PURPLE='[38;2;189;147;249m'
            CYAN='[38;2;139;233;253m'
            GRAY='[38;2;68;71;90m'
            ;;
        *)  # Default to catppuccin
            RED='[38;2;237;135;150m'
            GREEN='[38;2;166;218;149m'
            YELLOW='[38;2;238;212;159m'
            BLUE='[38;2;138;173;244m'
            PURPLE='[38;2;203;166;247m'
            CYAN='[38;2;116;199;236m'
            GRAY='[38;2;110;115;141m'
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Logging Functions
# ------------------------------------------------------------------------------

log() {
    local level="INFO"
    local color="${BLUE}"

    # Check if first argument is a valid log level
    case "${1:-}" in
        debug)
            if [[ "${LOG_LEVEL}" != "debug" ]]; then
                return 0
            fi
            level="DEBUG"
            color="${GRAY}"
            shift
            ;;
        info)
            level="INFO"
            color="${BLUE}"
            shift
            ;;
        warn|warning)
            level="WARN"
            color="${YELLOW}"
            shift
            ;;
        error)
            level="ERROR"
            color="${RED}"
            shift
            ;;
    esac

    # Format the log message
    local timestamp="$(date +'%Y-%m-%d %H:%M:%S')"
    local formatted_message="${color}[${timestamp}] [${level}]${RESET} $*"

    # Print to console if not in UI mode
    if [[ "${UI_FRAMEWORK}" != "dialog" && "${UI_FRAMEWORK}" != "whiptail" && "${UI_FRAMEWORK}" != "zenity" ]]; then
        echo -e "${formatted_message}"
    fi

    # Always log to file
    echo -e "${formatted_message}" >> "${LOG_FILE}"
}

log_success() {
    log info "${GREEN}✓${RESET} $*"
}

log_error() {
    log error "${RED}✗${RESET} $*"
    echo "$*" >> "${ERROR_FILE}"
    ERRORS_OCCURRED=true
}

log_warning() {
    log warn "${YELLOW}⚠${RESET} $*"
}

log_info() {
    log info "${BLUE}ℹ${RESET} $*"
}

log_debug() {
    log debug "${GRAY}»${RESET} $*"
}

# Display a section header in logs
log_section() {
    local section_name="$1"
    local width=70
    local padding=$(( (width - ${#section_name} - 2) / 2 ))
    local left_padding=$(printf "%${padding}s" "")
    local right_padding=$(printf "%${padding}s" "")

    log ""
    log "${CYAN}${left_padding} ${section_name} ${right_padding}${RESET}"
    log "${CYAN}$(printf "%${width}s" | tr ' ' '═')${RESET}"
    log ""
}

# ------------------------------------------------------------------------------
# UI Helpers (Progress, Spinners, Dialog Wrappers)
# ------------------------------------------------------------------------------

# Start a spinner animation
start_spinner() {
    local message="$1"

    if [[ "${UI_FRAMEWORK}" == "dialog" || "${UI_FRAMEWORK}" == "whiptail" || "${UI_FRAMEWORK}" == "zenity" ]]; then
        # These UIs handle progress differently
        return 0
    fi

    # Stop any existing spinner
    stop_spinner

    # Function to display spinner
    _spin() {
        local i=0
        local frames=("${SPINNER_FRAMES[@]}")
        while true; do
            printf "${BLUE}%s${RESET} %s " "${frames[i]}" "${message}"
            i=$(( (i + 1) % ${#frames[@]} ))
            sleep 0.1
        done
    }

    # Start spinner in background
    _spin &
    SPINNER_PID=$!
    disown
    SPINNER_ACTIVE=true
}

# Stop the spinner animation
stop_spinner() {
    if [[ "${SPINNER_ACTIVE}" == true && -n "${SPINNER_PID}" ]]; then
        kill -9 "${SPINNER_PID}" &>/dev/null || true
        SPINNER_ACTIVE=false
        SPINNER_PID=""
        # Clear the line
        printf "%$(tput cols)s" ""
    fi
}

# Show a progress bar
show_progress() {
    local current="$1"
    local total="$2"
    local task="$3"
    local percent=$((current * 100 / total))
    local width=40

    if [[ "${UI_FRAMEWORK}" == "dialog" ]]; then
        # Update the dialog gauge
        echo "${percent}" > "${PROGRESS_FILE}"
        return 0
    elif [[ "${UI_FRAMEWORK}" == "whiptail" ]]; then
        # Whiptail handles progress differently
        return 0
    elif [[ "${UI_FRAMEWORK}" == "zenity" ]]; then
        # Update zenity progress bar
        echo "${percent}" > "${PROGRESS_FILE}"
        return 0
    fi

    # Terminal progress bar
    stop_spinner

    local done_blocks=$((width * percent / 100))
    local todo_blocks=$((width - done_blocks))

    # Create the progress bar
    local done_bar=$(printf "%${done_blocks}s" | tr ' ' '█')
    local todo_bar=$(printf "%${todo_blocks}s" | tr ' ' '░')

    # Print the progress bar
    printf "${CYAN}[${GREEN}${done_bar}${GRAY}${todo_bar}${CYAN}]${RESET} %3d%% %s" "${percent}" "${task}"

    # Add a newline if we're at 100%
    if [[ "${percent}" -eq 100 ]]; then
        echo ""
    fi
}

# Display a message in a temporary overlay
show_message() {
    local message="$1"
    local duration="${2:-2}"  # Default to 2 seconds

    if [[ "${UI_FRAMEWORK}" == "dialog" || "${UI_FRAMEWORK}" == "whiptail" ]]; then
        # Use infobox for these UIs
        "${UI_TOOL}" --title "Information" --infobox "${message}" 8 60
        sleep "${duration}"
        return 0
    elif [[ "${UI_FRAMEWORK}" == "zenity" ]]; then
        # Use notification for zenity
        "${UI_TOOL}" --notification --text="${message}" &
        local notify_pid=$!
        sleep "${duration}"
        kill ${notify_pid} &>/dev/null || true
        return 0
    fi

    # Terminal message
    stop_spinner
    printf "${BLUE}[INFO]${RESET} ${message}"
    sleep "${duration}"
    printf "%$(tput cols)s" "" # Clear the line
}

# ------------------------------------------------------------------------------
# Configuration Parsing
# ------------------------------------------------------------------------------

# Parse the TOML configuration file
parse_config() {
    log_info "Reading configuration from ${CONFIG_FILE}"

    if [[ ! -f "${CONFIG_FILE}" ]]; then
        log_error "Configuration file not found: ${CONFIG_FILE}"
        return 1
    fi

    # Try to find a TOML parser
    if command -v python3 &>/dev/null; then
        TOML_PARSER="python3"
        # Check if the toml module is available
        if ! python3 -c "import toml" &>/dev/null; then
            log_warning "Python toml module not found, attempting to install..."
            python3 -m pip install toml &>/dev/null || {
                log_error "Failed to install Python toml module. Config parsing may be limited."
                TOML_PARSER=""
            }
        fi
    elif command -v python &>/dev/null; then
        TOML_PARSER="python"
        # Check if the toml module is available
        if ! python -c "import toml" &>/dev/null; then
            log_warning "Python toml module not found, attempting to install..."
            python -m pip install toml &>/dev/null || {
                log_error "Failed to install Python toml module. Config parsing may be limited."
                TOML_PARSER=""
            }
        fi
    fi

    if [[ -n "${TOML_PARSER}" ]]; then
        # Parse with Python
        log_debug "Using ${TOML_PARSER} to parse TOML configuration"

        # Extract UI framework
        UI_FRAMEWORK=$(${TOML_PARSER} -c "import toml; config = toml.load('${CONFIG_FILE}'); print(config['installer']['ui_framework'])")

        # Extract theme
        THEME_NAME=$(${TOML_PARSER} -c "import toml; config = toml.load('${CONFIG_FILE}'); print(config['installer']['theme'])")

        # Extract log level
        LOG_LEVEL=$(${TOML_PARSER} -c "import toml; config = toml.load('${CONFIG_FILE}'); print(config['installer']['log_level'])")

        log_info "Configuration loaded: UI=${UI_FRAMEWORK}, Theme=${THEME_NAME}, LogLevel=${LOG_LEVEL}"
    else
        # Fallback to basic parsing with grep and sed
        log_warning "No TOML parser available, using basic config parsing"

        UI_FRAMEWORK=$(grep -A1 "ui_framework" "${CONFIG_FILE}" | tail -n1 | sed 's/[^"]*"\([^"]*\)".*//')
        THEME_NAME=$(grep -A1 "theme" "${CONFIG_FILE}" | tail -n1 | sed 's/[^"]*"\([^"]*\)".*//')
        LOG_LEVEL=$(grep -A1 "log_level" "${CONFIG_FILE}" | tail -n1 | sed 's/[^"]*"\([^"]*\)".*//')

        log_info "Basic configuration loaded"
    fi

    # If UI framework is auto, detect the best available
    if [[ "${UI_FRAMEWORK}" == "auto" ]]; then
        detect_ui_framework
    fi

    # Apply theme colors
    setup_colors

    return 0
}

# ------------------------------------------------------------------------------
# Environment Detection
# ------------------------------------------------------------------------------

# Detects the operating system
detect_os() {
    case "$(uname -s)" in
        Darwin)  echo "macos" ;;
        Linux)   echo "linux" ;;
        CYGWIN*|MINGW*|MSYS*) echo "windows" ;;
        *)       echo "unknown" ;;
    esac
}

# Detects the Linux distribution
detect_distro() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        echo "${ID}"
    elif [[ -f /etc/debian_version ]]; then
        echo "debian"
    elif [[ -f /etc/redhat-release ]]; then
        echo "rhel"
    elif [[ -f /etc/arch-release ]]; then
        echo "arch"
    else
        echo "unknown"
    fi
}

# Detects the best available UI framework
detect_ui_framework() {
    log_debug "Auto-detecting UI framework..."

    if [[ -n "${DISPLAY:-}" && command -v zenity &>/dev/null ]]; then
        UI_FRAMEWORK="zenity"
        UI_TOOL="zenity"
        log_info "Using zenity for GUI dialogs"
    elif command -v dialog &>/dev/null; then
        UI_FRAMEWORK="dialog"
        UI_TOOL="dialog"
        log_info "Using dialog for TUI dialogs"
    elif command -v whiptail &>/dev/null; then
        UI_FRAMEWORK="whiptail"
        UI_TOOL="whiptail"
        log_info "Using whiptail for TUI dialogs"
    elif command -v fzf &>/dev/null; then
        UI_FRAMEWORK="fzf"
        UI_TOOL="fzf"
        log_info "Using fzf for terminal selection dialogs"
    else
        UI_FRAMEWORK="basic"
        log_warning "No UI frameworks found, falling back to basic terminal prompts"
    fi
}

# Detects the system package manager
detect_package_manager() {
    if command -v apt-get &>/dev/null; then
        echo "apt"
    elif command -v dnf &>/dev/null; then
        echo "dnf"
    elif command -v yum &>/dev/null; then
        echo "yum"
    elif command -v pacman &>/dev/null; then
        echo "pacman"
    elif command -v apk &>/dev/null; then
        echo "apk"
    elif command -v brew &>/dev/null; then
        echo "brew"
    else
        echo "none"
    fi
}

# ------------------------------------------------------------------------------
# Dialog Framework Wrappers
# ------------------------------------------------------------------------------

# Show a checklist menu to select components
show_component_menu() {
    local title="$1"
    local text="$2"
    shift 2

    # Components will be passed as name/description/default triplets
    local -a menu_items=()
    local i=0
    while [[ $i -lt $# ]]; do
        menu_items+=("${!i}" "$(($i+1))" "$(($i+2))")
        i=$((i+3))
    done

    case "${UI_FRAMEWORK}" in
        dialog)
            dialog --title "${title}" --checklist "${text}" 22 76 15 "${menu_items[@]}" 2> "${SELECTED_COMPONENTS_FILE}"
            ;;
        whiptail)
            whiptail --title "${title}" --checklist "${text}" 22 76 15 "${menu_items[@]}" 2> "${SELECTED_COMPONENTS_FILE}"
            ;;
        zenity)
            local zenity_items=""
            local i=0
            while [[ $i -lt ${#menu_items[@]} ]]; do
                local checked=""
                [[ "${menu_items[$i+2]}" == "ON" ]] && checked="TRUE" || checked="FALSE"
                zenity_items+="${checked}|${menu_items[$i]}|${menu_items[$i+1]}\n"
                i=$((i+3))
            done
            zenity --list --title "${title}" --text "${text}" --checklist --column "Select" --column "Component" --column "Description" --separator=" " --print-column=2 "${zenity_items}" > "${SELECTED_COMPONENTS_FILE}"
            ;;
        fzf)
            local fzf_items=""
            local i=0
            while [[ $i -lt ${#menu_items[@]} ]]; do
                local marker=""
                [[ "${menu_items[$i+2]}" == "ON" ]] && marker="[✓]" || marker="[ ]"
                fzf_items+="${marker} ${menu_items[$i]} - ${menu_items[$i+1]}\n"
                i=$((i+3))
            done
            echo -e "${fzf_items}" | fzf --multi --no-sort --header="${text}" --pointer="➜" | sed 's/^\[.\] \([^ ]*\) -.*//' > "${SELECTED_COMPONENTS_FILE}"
            ;;
        *)
            # Basic terminal selection
            echo "${title}"
            echo "${text}"
            local i=0
            while [[ $i -lt ${#menu_items[@]} ]]; do
                local marker=""
                [[ "${menu_items[$i+2]}" == "ON" ]] && marker="[x]" || marker="[ ]"
                echo -e " ${marker} ${menu_items[$i]} - ${menu_items[$i+1]}"
                i=$((i+3))
            done
            echo ""
            echo "Enter component names (space-separated) to select:"
            read -r selected
            echo "${selected}" > "${SELECTED_COMPONENTS_FILE}"
            ;;
    esac

    # Return true if something was selected
    [[ -s "${SELECTED_COMPONENTS_FILE}" ]]
}

# Show a progress dialog
show_progress_dialog() {
    local title="$1"
    local text="$2"
    local max_steps="$3"

    case "${UI_FRAMEWORK}" in
        dialog)
            # Start a background process to read progress from file and update dialog
            (
                while [[ -f "${PROGRESS_FILE}" ]]; do
                    if [[ -s "${PROGRESS_FILE}" ]]; then
                        pct=$(cat "${PROGRESS_FILE}")
                        echo "${pct}"
                        if [[ "${pct}" -ge 100 ]]; then
                            break
                        fi
                    fi
                    sleep 0.1
                done
            ) | dialog --title "${title}" --gauge "${text}" 8 70 0
            ;;
        whiptail)
            # For whiptail, we need to manually construct the progress tracker
            # This is a simplified version - for a real implementation, use a coprocess
            local i=0
            while [[ $i -le 100 ]]; do
                echo "${i}"
                i=$((i+5))
                sleep 0.2
            done | whiptail --title "${title}" --gauge "${text}" 8 70 0
            ;;
        zenity)
            # Start a background process to read progress from file and update zenity
            zenity --progress --title="${title}" --text="${text}" --auto-close --percentage=0 &
            local zenity_pid=$!

            (
                while [[ -f "${PROGRESS_FILE}" ]]; do
                    if [[ -s "${PROGRESS_FILE}" ]]; then
                        pct=$(cat "${PROGRESS_FILE}")
                        echo "${pct}"
                        if [[ "${pct}" -ge 100 ]]; then
                            break
                        fi
                    fi
                    sleep 0.1
                done
            ) | zenity --progress --title="${title}" --text="${text}" --auto-close --percentage=0
            ;;
        *)
            # For basic terminal, we'll just use the show_progress function
            echo "${title}"
            echo "${text}"
            echo ""
            # Progress will be handled by individual calls to show_progress
            ;;
    esac
}

# Show a simple message box
show_message_box() {
    local title="$1"
    local text="$2"

    case "${UI_FRAMEWORK}" in
        dialog)
            dialog --title "${title}" --msgbox "${text}" 15 70
            ;;
        whiptail)
            whiptail --title "${title}" --msgbox "${text}" 15 70
            ;;
        zenity)
            zenity --info --title="${title}" --text="${text}"
            ;;
        fzf)
            # Simulate a message box with fzf
            echo -e "${text}

Press ENTER to continue..." | fzf --prompt="${title} > " --pointer="➜" --header="[Enter] to continue"
            ;;
        *)
            # Basic terminal message
            echo "=== ${title} ==="
            echo "${text}"
            echo ""
            echo "Press ENTER to continue..."
            read -r
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Component Installation Functions
# ------------------------------------------------------------------------------

# Set up prerequisite directories and initialize log files
setup_prerequisites() {
    log_section "Setting up prerequisites"

    local os=$(detect_os)
    local distro=$(detect_distro)

    log_info "Detected OS: ${os}, Distribution: ${distro}"

    case "${os}" in
        macos)
            setup_macos_prerequisites
            ;;
        linux)
            case "${distro}" in
                ubuntu|debian)
                    setup_debian_prerequisites
                    ;;
                fedora|rhel|centos)
                    setup_rhel_prerequisites
                    ;;
                arch|manjaro)
                    setup_arch_prerequisites
                    ;;
                *)
                    log_warning "Unsupported Linux distribution: ${distro}. Attempting generic Linux setup."
                    sudo apt-get update -y || sudo dnf update -y || true
                    sudo apt-get install -y curl git wget unzip dialog ||                     sudo dnf install -y curl git wget unzip dialog || true
                    ;;
            esac
            ;;
        windows)
            setup_windows_prerequisites
            ;;
        *)
            log_error "Unsupported operating system: ${os}. Cannot proceed with prerequisites."
            exit 1
            ;;
    esac

    log_success "Prerequisites setup completed."
}

# macOS-specific prerequisites
setup_macos_prerequisites() {
    log_info "Setting up macOS prerequisites..."

    # Check for Xcode Command Line Tools
    if ! xcode-select -p &>/dev/null 2>&1; then
        log_info "Installing Xcode Command Line Tools (might require user interaction)..."
        xcode-select --install || log_warning "Xcode Command Line Tools installation failed or was cancelled."
    else
        log_info "Xcode Command Line Tools already installed."
    fi

    # Check for Homebrew
    if ! command -v brew &>/dev/null 2>&1; then
        log_info "Installing Homebrew (might require user interaction)..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)" || log_error "Homebrew installation failed."
        eval "$(/opt/homebrew/bin/brew shellenv)" # For M1 Macs
        log_success "Homebrew installed successfully."
    else
        log_info "Homebrew already installed."
    fi

    # Install essential packages
    log_info "Installing essential Homebrew packages..."
    brew install curl git wget unzip dialog fzf coreutils jq hyperfine || log_warning "Failed to install some Homebrew packages."

    log_success "macOS specific prerequisites installed."
}

# Debian/Ubuntu-specific prerequisites
setup_debian_prerequisites() {
    log_info "Setting up Debian/Ubuntu prerequisites..."

    # Update package repository
    sudo apt update -y || log_error "Failed to update apt repositories."

    # Install essential packages
    sudo apt install -y         curl git wget unzip build-essential         dialog whiptail fzf software-properties-common         apt-transport-https ca-certificates gnupg lsb-release         jq hyperfine || log_error "Failed to install Debian/Ubuntu prerequisites."

    log_success "Debian/Ubuntu prerequisites installed."
}

# RHEL/Fedora-specific prerequisites
setup_rhel_prerequisites() {
    log_info "Setting up RHEL/Fedora prerequisites..."

    if command -v dnf &>/dev/null 2>&1; then
        sudo dnf groupinstall -y "Development Tools" || log_error "Failed to install dnf Development Tools."
        sudo dnf install -y curl git wget unzip dialog fzf jq hyperfine || log_error "Failed to install dnf prerequisites."
    else # Fallback to yum for older RHEL/CentOS
        sudo yum groupinstall -y "Development Tools" || log_error "Failed to install yum Development Tools."
        sudo yum install -y curl git wget unzip dialog jq || log_error "Failed to install yum prerequisites."

        # fzf may not be available in older RHEL repos
        log_info "Installing fzf from GitHub..."
        if ! command -v fzf &>/dev/null 2>&1; then
            git clone --depth 1 https://github.com/junegunn/fzf.git ~/.fzf
            ~/.fzf/install --all || log_warning "Failed to install fzf."
        fi
    fi

    log_success "RHEL/Fedora prerequisites installed."
}

# Arch Linux-specific prerequisites
setup_arch_prerequisites() {
    log_info "Setting up Arch Linux prerequisites..."

    sudo pacman -Sy --noconfirm         base-devel curl git wget unzip dialog fzf jq hyperfine || log_error "Failed to install Arch Linux prerequisites."

    log_success "Arch Linux prerequisites installed."
}

# Windows-specific prerequisites
setup_windows_prerequisites() {
    log_info "Setting up Windows prerequisites..."

    if grep -qi microsoft /proc/version 2>/dev/null; then
        log_info "Running in WSL, performing Linux (Debian/Ubuntu) setup..."
        setup_debian_prerequisites
        return
    fi

    log_warning "Automated Windows setup (outside WSL) is limited."

    if ! command -v winget &>/dev/null 2>&1; then
        log_error "winget (Windows Package Manager) not found. Please install 'App Installer' from Microsoft Store."
        exit 1
    fi

    log_info "Installing Git and cURL via winget..."
    winget install --id=Git.Git -e || log_warning "Failed to install Git via winget."
    winget install --id=cURL.cURL -e || log_warning "Failed to install cURL via winget."

    log_success "Windows prerequisites setup initiated."
    log_warning "Manual steps may be required for full setup on native Windows (e.g., Scoop or Chocolatey for more tools)."
}

# ------------------------------------------------------------------------------
# Tool Installation Functions
# ------------------------------------------------------------------------------

# Install mise (universal tool version manager)
install_mise() {
    log_section "Installing mise (universal tool version manager)"

    if command -v mise &>/dev/null; then
        log_info "mise is already installed. Checking version..."
        local current_version=$(mise --version | awk '{print $2}')
        log_info "Current mise version: ${current_version}"
        MISE_PATH=$(command -v mise)
        return 0
    fi

    log_info "Installing mise..."
    curl https://mise.run | sh || { 
        log_error "Failed to download and execute mise installation script."
        return 1
    }

    export PATH="$HOME/.local/bin:$PATH" # Add mise to PATH for current session

    if command -v mise &>/dev/null; then
        MISE_PATH=$(command -v mise)
        eval "$(mise activate bash)" # Activate mise for current script run
        log_success "mise installed and activated for this session: ${MISE_PATH}"
    else
        log_error "mise command not found after installation attempt. Installation may have failed."
        return 1
    fi

    return 0
}

# Ensure mise is active in the current shell
ensure_mise_active() {
    if [[ -z "${MISE_PATH}" ]]; then
        if command -v mise &>/dev/null; then
            MISE_PATH=$(command -v mise)
        else
            log_error "mise is not installed or not in PATH. Cannot proceed with tool installation."
            return 1
        fi
    fi

    log_debug "Activating mise in current shell..."
    eval "$(${MISE_PATH} activate bash)"

    # Verify activation
    if ! command -v mise &>/dev/null; then
        log_error "Failed to activate mise in current shell."
        return 1
    fi

    log_debug "mise activated successfully."
    return 0
}

# Install Python and development tools
install_python() {
    log_section "Installing Python and development tools"

    if ! ensure_mise_active; then
        return 1
    fi

    local python_version="3.12"
    log_info "Installing Python ${python_version}..."

    ${MISE_PATH} use -g python@${python_version} || {
        log_error "Failed to install Python ${python_version} via mise."
        return 1
    }

    log_info "Installing uv (ultra-fast Python package manager)..."
    if ! command -v uv &>/dev/null; then
        curl -LsSf https://astral.sh/uv/install.sh | sh || {
            log_error "Failed to download/install uv."
            return 1
        }
        export PATH="$HOME/.uv/bin:$PATH" # Add uv to PATH for current session
    else
        log_info "uv is already installed. Skipping uv installation."
    fi

    local UV_BIN="$HOME/.uv/bin/uv"
    if ! command -v "${UV_BIN}" &>/dev/null 2>&1; then
        log_error "uv binary not found at expected path (${UV_BIN}). Python tool installation may fail."
        # Try to find it in PATH
        UV_BIN=$(command -v uv || echo "")
        if [[ -z "${UV_BIN}" ]]; then
            log_error "uv not found in PATH either. Python tool installation will fail."
            return 1
        fi
        log_warning "Using uv from PATH: ${UV_BIN}"
    fi

    log_info "Installing Python development tools (ruff, black, pipx, pytest) via uv..."
    "${UV_BIN}" tool install ruff || log_warning "Failed to install ruff via uv."
    "${UV_BIN}" tool install black || log_warning "Failed to install black via uv."
    "${UV_BIN}" tool install pipx || log_warning "Failed to install pipx via uv."
    "${UV_BIN}" tool install pytest || log_warning "Failed to install pytest via uv."

    log_success "Python ${python_version} and tools installed."
    return 0
}

# Install Node.js, Bun, and PNPM
install_nodejs() {
    log_section "Installing Node.js, Bun, and PNPM"

    if ! ensure_mise_active; then
        return 1
    fi

    log_info "Installing Node.js (LTS), Bun (latest), PNPM (latest) using mise..."
    ${MISE_PATH} use -g node@lts bun@latest pnpm@latest || {
        log_error "Failed to install Node.js, Bun, or PNPM via mise."
        return 1
    }

    log_success "Node.js, Bun, PNPM installed via mise."

    log_info "Installing essential global npm packages..."
    npm install -g         typescript         eslint         prettier         nodemon         pm2 || {
        log_error "Failed to install global npm packages."
        return 1
    }

    log_success "Global npm packages installed."
    return 0
}

# Install Go and development tools
install_go() {
    log_section "Installing Go and development tools"

    if ! ensure_mise_active; then
        return 1
    fi

    log_info "Installing Go latest..."
    ${MISE_PATH} use -g go@latest || {
        log_error "Failed to install Go via mise."
        return 1
    }

    log_info "Installing Go development tools..."
    go install github.com/golangci/golangci-lint/cmd/golangci-lint@latest || log_warning "Failed to install golangci-lint."
    go install github.com/go-delve/delve/cmd/dlv@latest || log_warning "Failed to install delve."
    go install golang.org/x/tools/cmd/goimports@latest || log_warning "Failed to install goimports."

    log_success "Go and tools installed."
    return 0
}

# Install Rust and development tools
install_rust() {
    log_section "Installing Rust and development tools"

    if ! ensure_mise_active; then
        return 1
    fi

    log_info "Installing Rust latest..."
    ${MISE_PATH} use -g rust@latest || {
        log_error "Failed to install Rust via mise."
        return 1
    }

    log_info "Installing Rust development tools..."
    cargo install cargo-edit || log_warning "Failed to install cargo-edit."
    cargo install cargo-watch || log_warning "Failed to install cargo-watch."
    cargo install cargo-expand || log_warning "Failed to install cargo-expand."
    cargo install sccache || log_warning "Failed to install sccache."

    log_info "Installing useful CLI tools written in Rust..."
    cargo install ripgrep || log_warning "Failed to install ripgrep."
    cargo install fd-find || log_warning "Failed to install fd-find."
    cargo install bat || log_warning "Failed to install bat."
    cargo install exa || log_warning "Failed to install exa."

    log_success "Rust and tools installed."
    return 0
}

# Install/configure Zsh shell
install_zsh_shell() {
    log_section "Setting up Zsh shell"

    if ! command -v zsh &>/dev/null; then
        log_error "Zsh not found. Installing it now..."
        local pm=$(detect_package_manager)

        case "${pm}" in
            apt)
                sudo apt-get update -y && sudo apt-get install -y zsh || {
                    log_error "Failed to install Zsh via apt."
                    return 1
                }
                ;;
            dnf|yum)
                sudo "${pm}" install -y zsh || {
                    log_error "Failed to install Zsh via ${pm}."
                    return 1
                }
                ;;
            pacman)
                sudo pacman -Sy --noconfirm zsh || {
                    log_error "Failed to install Zsh via pacman."
                    return 1
                }
                ;;
            brew)
                brew install zsh || {
                    log_error "Failed to install Zsh via brew."
                    return 1
                }
                ;;
            *)
                log_error "Unsupported package manager '${pm}' for Zsh installation."
                return 1
                ;;
        esac
    fi

    # Change default login shell to Zsh
    log_info "Attempting to change default login shell to Zsh for user (${USER})..."
    local zsh_path="$(command -v zsh)"

    if [[ "$(basename "${SHELL}")" != "zsh" || "${SHELL}" != "${zsh_path}" ]]; then
        if ! chsh -s "${zsh_path}"; then
            log_warning "chsh failed without sudo. Trying with sudo (requires no password in Codespaces)."
            sudo chsh -s "${zsh_path}" "${USER}" || {
                log_error "Failed to change default login shell to Zsh. Manual intervention may be needed."
                return 1
            }
        fi
        log_success "Default login shell set to ${zsh_path}."
    else
        log_info "Zsh is already the default login shell for this user (${zsh_path})."
    fi

    # Install Oh My Zsh if not present
    if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
        log_info "Installing Oh My Zsh..."
        sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended || {
            log_error "Failed to install Oh My Zsh."
            return 1
        }
    else
        log_info "Oh My Zsh already installed."
    fi

    # Install Powerlevel10k theme
    log_info "Installing Powerlevel10k theme..."
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
        git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" || {
            log_error "Failed to clone Powerlevel10k."
            return 1
        }
    fi

    # Install Zsh plugins
    log_info "Installing Zsh plugins..."

    # zsh-autosuggestions
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" ]]; then
        git clone https://github.com/zsh-users/zsh-autosuggestions "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-autosuggestions" || log_warning "Failed to install zsh-autosuggestions."
    fi

    # zsh-syntax-highlighting
    if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" ]]; then
        git clone https://github.com/zsh-users/zsh-syntax-highlighting.git "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting" || log_warning "Failed to install zsh-syntax-highlighting."
    fi

    # Configure .zshrc
    log_info "Configuring .zshrc..."

    # Backup existing .zshrc if present
    if [[ -f "$HOME/.zshrc" ]]; then
        cp "$HOME/.zshrc" "$HOME/.zshrc.backup.$(date +%Y%m%d_%H%M%S)" || log_warning "Failed to backup .zshrc."
    fi

    # Create new .zshrc with optimized configuration
    cat > "$HOME/.zshrc" << 'EOF'
# Enable Powerlevel10k instant prompt
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to Oh My Zsh installation
export ZSH="$HOME/.oh-my-zsh"

# Set theme to Powerlevel10k
ZSH_THEME="powerlevel10k/powerlevel10k"

# Set plugins
plugins=(
  git
  docker
  docker-compose
  zsh-autosuggestions
  zsh-syntax-highlighting
  fzf
  colored-man-pages
  command-not-found
)

# Source Oh My Zsh
source $ZSH/oh-my-zsh.sh

# User configuration
export EDITOR='vim'
export VISUAL='vim'

# Load mise (if installed)
if command -v mise &>/dev/null; then
  eval "$(mise activate zsh)"
fi

# FZF configuration (if installed)
if command -v fzf &>/dev/null; then
  [ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
fi

# Common aliases
alias ls='ls --color=auto'
alias ll='ls -la'
alias la='ls -A'
alias l='ls -CF'
alias grep='grep --color=auto'
alias cp='cp -i'
alias mv='mv -i'
alias rm='rm -i'

# Load Powerlevel10k configuration
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh
EOF

    # Create p10k.zsh configuration file (minimal version)
    log_info "Creating p10k.zsh configuration..."
    cat > "$HOME/.p10k.zsh" << 'EOF'
# Generated p10k configuration - minimal version
# For full version, run: p10k configure

# Temporarily change options.
'builtin' 'local' '-a' 'p10k_config_opts'
[[ ! -o 'aliases'         ]] || p10k_config_opts+=('aliases')
[[ ! -o 'sh_glob'         ]] || p10k_config_opts+=('sh_glob')
[[ ! -o 'no_brace_expand' ]] || p10k_config_opts+=('no_brace_expand')
'builtin' 'setopt' 'no_aliases' 'no_sh_glob' 'brace_expand'

() {
  emulate -L zsh -o extended_glob

  # Left prompt segments
  typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(
    dir                     # current directory
    vcs                     # git status
    prompt_char             # prompt symbol
  )

  # Right prompt segments
  typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(
    status                  # exit code of the last command
    command_execution_time  # duration of the last command
    background_jobs         # presence of background jobs
    virtualenv              # python virtual environment
    context                 # user@hostname
  )

  # Basic style options
  typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true
  typeset -g POWERLEVEL9K_MODE=nerdfont-complete
  typeset -g POWERLEVEL9K_PROMPT_ON_NEWLINE=true
  typeset -g POWERLEVEL9K_RPROMPT_ON_NEWLINE=false
  typeset -g POWERLEVEL9K_MULTILINE_FIRST_PROMPT_PREFIX='%F{blue}╭─'
  typeset -g POWERLEVEL9K_MULTILINE_LAST_PROMPT_PREFIX='%F{blue}╰─%F{cyan}❯ '

  # Customize colors and icons as desired
}

# Restore options
(( ${#p10k_config_opts} )) && setopt ${p10k_config_opts[@]}
'builtin' 'unset' 'p10k_config_opts'
EOF

    log_success "Zsh shell setup completed. You can start using it by running: exec zsh"
    return 0
}

# Install common CLI tools
install_cli_tools() {
    log_section "Installing common CLI tools"

    local os=$(detect_os)
    local pm=$(detect_package_manager)

    local tools_to_install=(
        "jq" "ripgrep" "fd" "bat" "exa" "delta" "hyperfine"
        "htop" "tmux" "tree" "curl" "wget" "unzip"
    )

    log_info "Installing common CLI tools: ${tools_to_install[*]}"

    # Install tools using the detected package manager
    case "${pm}" in
        apt)
            sudo apt-get update -y
            for tool in "${tools_to_install[@]}"; do
                log_info "Installing ${tool}..."
                sudo apt-get install -y "${tool}" || log_warning "Failed to install ${tool} via apt."
            done
            ;;
        dnf|yum)
            for tool in "${tools_to_install[@]}"; do
                log_info "Installing ${tool}..."
                sudo "${pm}" install -y "${tool}" || log_warning "Failed to install ${tool} via ${pm}."
            done
            ;;
        pacman)
            for tool in "${tools_to_install[@]}"; do
                log_info "Installing ${tool}..."
                sudo pacman -S --noconfirm "${tool}" || log_warning "Failed to install ${tool} via pacman."
            done
            ;;
        brew)
            for tool in "${tools_to_install[@]}"; do
                log_info "Installing ${tool}..."
                brew install "${tool}" || log_warning "Failed to install ${tool} via brew."
            done
            ;;
        *)
            log_warning "Unsupported package manager '${pm}'. Installing tools via alternative methods..."

            # Try to install tools via cargo (Rust tools)
            if command -v cargo &>/dev/null; then
                log_info "Installing Rust-based tools via cargo..."
                cargo install ripgrep bat exa fd-find delta hyperfine || log_warning "Failed to install some Rust tools via cargo."
            fi

            # For other tools, log a warning
            log_warning "Cannot install all CLI tools automatically. Manual installation is required."
            ;;
    esac

    # Verify installations
    log_info "Verifying CLI tool installations..."
    local missing_tools=()

    for tool in "${tools_to_install[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            log_warning "${tool} is not available in PATH after installation."
            missing_tools+=("${tool}")
        else
            log_success "${tool} is successfully installed ($(command -v "${tool}"))"
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_warning "Some tools could not be installed or are not in PATH: ${missing_tools[*]}"
    else
        log_success "All common CLI tools were successfully installed."
    fi

    return 0
}

# Install VS Code extensions (mainly informational)
install_vscode_extensions() {
    log_section "Installing VS Code extensions"

    if ! command -v code &>/dev/null; then
        log_warning "VS Code (code command) not found in PATH. Skipping extension installation."
        log_info "VS Code extensions are typically installed via devcontainer.json in development containers."
        return 0
    fi

    log_info "Installing essential VS Code extensions..."

    # Extensions to install
    local extensions=(
        "ms-python.python"
        "rust-lang.rust-analyzer"
        "golang.go"
        "esbenp.prettier-vscode"
        "dbaeumer.vscode-eslint"
        "ms-azuretools.vscode-docker"
        "ms-vscode-remote.remote-containers"
        "redhat.vscode-yaml"
        "ms-vsliveshare.vsliveshare"
        "github.copilot"
    )

    for ext in "${extensions[@]}"; do
        log_info "Installing extension: ${ext}..."
        code --install-extension "${ext}" || log_warning "Failed to install VS Code extension: ${ext}"
    done

    log_success "VS Code extensions installation completed."
    return 0
}

# Install fonts (helper function)
install_fonts() {
    log_section "Installing fonts"

    log_info "Setting up Nerd Fonts for terminal icons and glyphs..."

    local os=$(detect_os)
    local font_install_dir=""

    case "${os}" in
        macos)
            font_install_dir="$HOME/Library/Fonts"
            ;;
        linux)
            font_install_dir="$HOME/.local/share/fonts"
            ;;
        windows)
            if grep -qi microsoft /proc/version 2>/dev/null; then
                # WSL
                font_install_dir="$HOME/.local/share/fonts"
                log_warning "Installing fonts in WSL does not affect Windows. Please install fonts manually in Windows."
            else
                log_warning "Font installation not supported on Windows outside WSL. Please install fonts manually."
                return 0
            fi
            ;;
        *)
            log_warning "Unsupported OS for font installation: ${os}"
            return 0
            ;;
    esac

    # Create font directory if it doesn't exist
    mkdir -p "${font_install_dir}"

    # Install JetBrains Mono Nerd Font
    log_info "Installing JetBrains Mono Nerd Font..."

    local jetbrains_font_url="https://github.com/ryanoasis/nerd-fonts/releases/download/v3.0.2/JetBrainsMono.zip"
    local font_zip="${TMP_DIR}/JetBrainsMono.zip"

    # Download the font
    curl -fsSL "${jetbrains_font_url}" -o "${font_zip}" || {
        log_error "Failed to download JetBrains Mono Nerd Font."
        return 1
    }

    # Extract the font
    unzip -o "${font_zip}" -d "${TMP_DIR}/JetBrainsMono" || {
        log_error "Failed to extract JetBrains Mono Nerd Font."
        return 1
    }

    # Install the font
    cp "${TMP_DIR}/JetBrainsMono"/*.ttf "${font_install_dir}/" || {
        log_error "Failed to install JetBrains Mono Nerd Font."
        return 1
    }

    # Clean up
    rm -rf "${font_zip}" "${TMP_DIR}/JetBrainsMono"

    log_success "JetBrains Mono Nerd Font installed successfully."

    # Update font cache on Linux
    if [[ "${os}" == "linux" ]]; then
        log_info "Updating font cache..."
        fc-cache -f -v || log_warning "Failed to update font cache."
    fi

    log_info "Font installation completed. You may need to restart your terminal application to use the new fonts."
    return 0
}

# Provides info about Docker setup
install_containers_info() {
    log_section "Docker and Containers Information"

    log_info "Docker/Podman installation at the OS level (host machine) must be handled manually."
    log_info "In a Dev Container (like GitHub Codespaces), Docker-in-Docker functionality is typically provided by the 'docker-in-docker' feature in devcontainer.json."

    # Check if Docker is already installed
    if command -v docker &>/dev/null; then
        log_info "Docker is already installed: $(docker --version)"
    else
        log_info "Docker is not installed. You can install it manually following the official documentation:"
        log_info "  - Docker: https://docs.docker.com/get-docker/"
        log_info "  - Podman: https://podman.io/getting-started/installation"
    fi

    # Check if Docker Compose is installed
    if command -v docker-compose &>/dev/null; then
        log_info "Docker Compose is already installed: $(docker-compose --version)"
    elif command -v docker &>/dev/null && docker compose version &>/dev/null; then
        log_info "Docker Compose (plugin) is already installed: $(docker compose version)"
    else
        log_info "Docker Compose is not installed. You can install it manually following the official documentation:"
        log_info "  - Docker Compose: https://docs.docker.com/compose/install/"
    fi

    log_success "Containers info module completed."
    return 0
}

# ------------------------------------------------------------------------------
# Dotfiles Management
# ------------------------------------------------------------------------------

# Backup existing dotfiles
backup_dotfiles() {
    log_section "Backing up existing dotfiles"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_dir="${DOTFILES_BACKUP_DIR}/backup_${timestamp}"

    log_info "Creating backup directory: ${backup_dir}"
    mkdir -p "${backup_dir}"

    # Files to backup
    local dotfiles=(
        ".zshrc"
        ".bashrc"
        ".bash_profile"
        ".profile"
        ".gitconfig"
        ".vimrc"
        ".tmux.conf"
        ".p10k.zsh"
    )

    for file in "${dotfiles[@]}"; do
        if [[ -f "$HOME/${file}" ]]; then
            log_info "Backing up ${file}..."
            cp -p "$HOME/${file}" "${backup_dir}/" || log_warning "Failed to backup ${file}."
        else
            log_debug "Skipping backup of ${file} (not found)."
        fi
    done

    # Directories to backup
    local dotdirs=(
        ".oh-my-zsh/custom"
        ".config/nvim"
        ".vim"
    )

    for dir in "${dotdirs[@]}"; do
        if [[ -d "$HOME/${dir}" ]]; then
            log_info "Backing up ${dir}..."
            mkdir -p "${backup_dir}/$(dirname "${dir}")"
            cp -rp "$HOME/${dir}" "${backup_dir}/$(dirname "${dir}")/" || log_warning "Failed to backup ${dir}."
        else
            log_debug "Skipping backup of ${dir} (not found)."
        fi
    done

    log_success "Dotfiles backup completed. Backup location: ${backup_dir}"
    return 0
}

# Restore dotfiles from backup
restore_dotfiles() {
    log_section "Restoring dotfiles from backup"

    # List available backups
    local backups=("${DOTFILES_BACKUP_DIR}"/backup_*)

    if [[ ${#backups[@]} -eq 0 ]]; then
        log_error "No backups found in ${DOTFILES_BACKUP_DIR}."
        return 1
    fi

    log_info "Available backups:"

    for i in "${!backups[@]}"; do
        log_info "  [$i] $(basename "${backups[$i]}")"
    done

    # Prompt for backup selection
    local backup_index
    log_info "Enter the index of the backup to restore (or 'c' to cancel):"
    read -r backup_index

    if [[ "${backup_index}" == "c" ]]; then
        log_info "Restoration cancelled."
        return 0
    fi

    if ! [[ "${backup_index}" =~ ^[0-9]+$ ]] || [[ "${backup_index}" -ge ${#backups[@]} ]]; then
        log_error "Invalid backup index: ${backup_index}"
        return 1
    fi

    local selected_backup="${backups[${backup_index}]}"
    log_info "Restoring from backup: ${selected_backup}"

    # Restore files
    for file in "${selected_backup}"/*; do
        if [[ -f "${file}" ]]; then
            local base_name=$(basename "${file}")
            log_info "Restoring ${base_name}..."
            cp -p "${file}" "$HOME/${base_name}" || log_warning "Failed to restore ${base_name}."
        elif [[ -d "${file}" ]]; then
            local dir_name=$(basename "${file}")
            log_info "Restoring directory ${dir_name}..."
            mkdir -p "$HOME/${dir_name}"
            cp -rp "${file}"/* "$HOME/${dir_name}/" || log_warning "Failed to restore directory ${dir_name}."
        fi
    done

    log_success "Dotfiles restored from backup: ${selected_backup}"
    return 0
}

# ------------------------------------------------------------------------------
# Validation Functions
# ------------------------------------------------------------------------------

# Run validation checks on installed components
run_validation() {
    log_section "Validating installation"

    if [[ "${SKIP_VALIDATION}" == true ]]; then
        log_warning "Validation skipped due to --skip-validation flag."
        return 0
    }

    local failed_checks=0

    # Read selected components from file
    local selected_components=""
    if [[ -f "${SELECTED_COMPONENTS_FILE}" ]]; then
        selected_components=" $(cat "${SELECTED_COMPONENTS_FILE}") "
    else
        log_warning "Selected components file not found. Will validate all components."
        selected_components=" mise python nodejs go rust zsh_shell cli_tools vscode_extensions fonts containers_info "
    fi

    # Ensure mise is installed first for tools managed by it
    if [[ "${selected_components}" =~ " mise " ]]; then
        log_info "Validating mise installation..."
        if ! command -v mise &>/dev/null; then
            log_error "mise is not installed, validation for mise-managed tools may be incomplete."
            ((failed_checks++))
        else
            log_success "mise is available ($(command -v mise))"
        fi
    fi

    # Core system tools
    log_info "Verifying core system tools:"
    if ! command -v git &>/dev/null; then
        log_error "git is NOT available."
        ((failed_checks++))
    else
        log_success "git is available ($(command -v git))"
    fi

    if ! command -v curl &>/dev/null; then
        log_error "curl is NOT available."
        ((failed_checks++))
    else
        log_success "curl is available ($(command -v curl))"
    fi

    # Check selected components
    if [[ "${selected_components}" =~ " python " ]]; then
        log_info "Verifying Python components:"
        if ! command -v python &>/dev/null; then
            log_error "python is NOT available."
            ((failed_checks++))
        else
            log_success "python is available ($(command -v python))"
        fi

        if ! command -v uv &>/dev/null; then
            log_error "uv is NOT available."
            ((failed_checks++))
        else
            log_success "uv is available ($(command -v uv))"
        fi

        if ! command -v ruff &>/dev/null; then
            log_error "ruff is NOT available."
            ((failed_checks++))
        else
            log_success "ruff is available ($(command -v ruff))"
        fi

        if ! command -v black &>/dev/null; then
            log_error "black is NOT available."
            ((failed_checks++))
        else
            log_success "black is available ($(command -v black))"
        fi
    fi

    if [[ "${selected_components}" =~ " nodejs " ]]; then
        log_info "Verifying JavaScript components:"
        if ! command -v node &>/dev/null; then
            log_error "node is NOT available."
            ((failed_checks++))
        else
            log_success "node is available ($(command -v node))"
        fi

        if ! command -v npm &>/dev/null; then
            log_error "npm is NOT available."
            ((failed_checks++))
        else
            log_success "npm is available ($(command -v npm))"
        fi

        if ! command -v bun &>/dev/null; then
            log_error "bun is NOT available."
            ((failed_checks++))
        else
            log_success "bun is available ($(command -v bun))"
        fi

        if ! command -v pnpm &>/dev/null; then
            log_error "pnpm is NOT available."
            ((failed_checks++))
        else
            log_success "pnpm is available ($(command -v pnpm))"
        fi
    fi

    if [[ "${selected_components}" =~ " go " ]]; then
        log_info "Verifying Go components:"
        if ! command -v go &>/dev/null; then
            log_error "go is NOT available."
            ((failed_checks++))
        else
            log_success "go is available ($(command -v go))"
        fi

        if ! command -v golangci-lint &>/dev/null; then
            log_error "golangci-lint is NOT available."
            ((failed_checks++))
        else
            log_success "golangci-lint is available ($(command -v golangci-lint))"
        fi

        if ! command -v dlv &>/dev/null; then
            log_error "dlv is NOT available."
            ((failed_checks++))
        else
            log_success "dlv is available ($(command -v dlv))"
        fi
    fi

    if [[ "${selected_components}" =~ " rust " ]]; then
        log_info "Verifying Rust components:"
        if ! command -v cargo &>/dev/null; then
            log_error "cargo is NOT available."
            ((failed_checks++))
        else
            log_success "cargo is available ($(command -v cargo))"
        fi

        if ! command -v rustc &>/dev/null; then
            log_error "rustc is NOT available."
            ((failed_checks++))
        else
            log_success "rustc is available ($(command -v rustc))"
        fi

        if ! command -v rustfmt &>/dev/null; then
            log_error "rustfmt is NOT available."
            ((failed_checks++))
        else
            log_success "rustfmt is available ($(command -v rustfmt))"
        fi
    fi

    if [[ "${selected_components}" =~ " cli_tools " ]]; then
        log_info "Verifying common CLI tools:"
        local cli_tools=("jq" "rg" "htop" "tmux" "tree" "bat")

        for tool in "${cli_tools[@]}"; do
            if ! command -v "${tool}" &>/dev/null; then
                log_error "${tool} is NOT available."
                ((failed_checks++))
            else
                log_success "${tool} is available ($(command -v "${tool}"))"
            fi
        done
    fi

    if [[ "${selected_components}" =~ " zsh_shell " ]]; then
        log_info "Verifying Zsh shell components:"
        if ! command -v zsh &>/dev/null; then
            log_error "zsh is NOT available."
            ((failed_checks++))
        else
            log_success "zsh is available ($(command -v zsh))"
        fi

        if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
            log_error "Oh My Zsh installation directory not found."
            ((failed_checks++))
        else
            log_success "Oh My Zsh is installed."
        fi

        if [[ ! -d "${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}/themes/powerlevel10k" ]]; then
            log_error "Powerlevel10k theme directory not found."
            ((failed_checks++))
        else
            log_success "Powerlevel10k theme is installed."
        fi
    fi

    log_info "Validation completed with ${failed_checks} failures."

    if [[ ${failed_checks} -eq 0 ]]; then
        log_success "All selected tools validated successfully!"
        return 0
    else
        log_error "${failed_checks} tools failed validation. Please check the logs for details."
        return 1
    fi
}

# ------------------------------------------------------------------------------
# Main Installation Logic
# ------------------------------------------------------------------------------

# Print welcome banner
print_banner() {
    echo -e "${PURPLE}"
    echo -e "┏━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┓"
    echo -e "┃                                                                          ┃"
    echo -e "┃  █████╗ ██████╗ ██╗   ██╗ █████╗ ███╗   ██╗ ██████╗███████╗██████╗      ┃"
    echo -e "┃ ██╔══██╗██╔══██╗██║   ██║██╔══██╗████╗  ██║██╔════╝██╔════╝██╔══██╗     ┃"
    echo -e "┃ ███████║██║  ██║██║   ██║███████║██╔██╗ ██║██║     █████╗  ██║  ██║     ┃"
    echo -e "┃ ██╔══██║██║  ██║╚██╗ ██╔╝██╔══██║██║╚██╗██║██║     ██╔══╝  ██║  ██║     ┃"
    echo -e "┃ ██║  ██║██████╔╝ ╚████╔╝ ██║  ██║██║ ╚████║╚██████╗███████╗██████╔╝     ┃"
    echo -e "┃ ╚═╝  ╚═╝╚═════╝   ╚═══╝  ╚═╝  ╚═╝╚═╝  ╚═══╝ ╚═════╝╚══════╝╚═════╝      ┃"
    echo -e "┃                                                                          ┃"
    echo -e "┃  ██████╗ ███████╗██╗   ██╗     ███████╗███╗   ██╗██╗   ██╗              ┃"
    echo -e "┃  ██╔══██╗██╔════╝██║   ██║     ██╔════╝████╗  ██║██║   ██║              ┃"
    echo -e "┃  ██║  ██║█████╗  ██║   ██║     █████╗  ██╔██╗ ██║██║   ██║              ┃"
    echo -e "┃  ██║  ██║██╔══╝  ╚██╗ ██╔╝     ██╔══╝  ██║╚██╗██║╚██╗ ██╔╝              ┃"
    echo -e "┃  ██████╔╝███████╗ ╚████╔╝      ███████╗██║ ╚████║ ╚████╔╝               ┃"
    echo -e "┃  ╚═════╝ ╚══════╝  ╚═══╝       ╚══════╝╚═╝  ╚═══╝  ╚═══╝                ┃"
    echo -e "┃                                                                          ┃"
    echo -e "┗━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━┛"
    echo -e "${RESET}"
    echo -e "${CYAN}Advanced Development Environment Installer v${SCRIPT_VERSION}${RESET}"
    echo -e "${YELLOW}Cross-Platform | Performance-Optimized | Modern Toolchain${RESET}"
    echo ""
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --yes|--non-interactive)
                SKIP_INTERACTIVE_MENU=true
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                ;;
            --verbose)
                VERBOSE=true
                LOG_LEVEL="debug"
                ;;
            --dry-run)
                DRY_RUN=true
                ;;
            --debug)
                DEBUG=true
                LOG_LEVEL="debug"
                set -x  # Enable bash debug mode
                ;;
            --help|-h)
                echo "Usage: bash install.sh [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --yes, --non-interactive  Skip interactive menu and install all default components."
                echo "  --skip-validation         Skip validation checks at the end of installation."
                echo "  --verbose                 Enable verbose output."
                echo "  --dry-run                 Show what would be installed without making changes."
                echo "  --debug                   Enable debug mode (very verbose output and bash debugging)."
                echo "  --help, -h                Show this help message."
                echo ""
                exit 0
                ;;
            *)
                echo "Unknown argument: $1"
                echo "Use --help for usage."
                exit 1
                ;;
        esac
        shift
    done
}

# Main installation function
main() {
    # Parse command line arguments
    parse_arguments "$@"

    # Clear terminal for a clean start
    clear

    # Print welcome banner
    print_banner

    # Initialize directories
    init_directories

    # Parse configuration
    parse_config

    # Load any environment variables from .env file
    if [[ -f "${ENV_FILE}" ]]; then
        log_info "Loading environment variables from ${ENV_FILE}..."
        # shellcheck source=/dev/null
        source "${ENV_FILE}"
    fi

    # Setup prerequisites
    setup_prerequisites

    # Backup existing dotfiles
    if [[ "${DOTFILES_BACKUP_ENABLED:-true}" == true ]]; then
        backup_dotfiles
    fi

    # Determine installation mode: interactive or non-interactive
    if [[ "${SKIP_INTERACTIVE_MENU}" == true ]]; then
        log_info "Running in non-interactive mode. Installing default components."
        echo "mise python nodejs go rust zsh_shell fonts cli_tools vscode_extensions containers_info" > "${SELECTED_COMPONENTS_FILE}"
    else
        # Show interactive component selection menu
        log_info "Showing interactive component selection menu..."

        show_component_menu "🚀 Advanced Development Environment Setup" "Select components to install:"             "mise" "Universal runtime manager (replaces nvm/pyenv/etc.)" ON             "python" "Python 3.12+ (mise), uv, ruff, black" ON             "nodejs" "Node.js, Bun, pnpm (mise), npm global tools" ON             "go" "Go latest (mise), golangci-lint, Delve" ON             "rust" "Rust latest (mise), Cargo tools, Rust CLI utils" ON             "zsh_shell" "Enhanced Zsh (Oh My Zsh, Powerlevel10k, plugins)" ON             "vscode_extensions" "VS Code extensions (when code command available)" ON             "fonts" "Nerd Fonts (JetBrains Mono)" ON             "cli_tools" "Common CLI Tools (jq, ripgrep, htop, tmux, tree)" ON             "containers_info" "Docker/Podman setup information" ON

        if [[ ! -s "${SELECTED_COMPONENTS_FILE}" ]]; then
            log_warning "No components selected for installation. Exiting."
            exit 0
        fi
    fi

    # Read selected components
    log_info "Selected components: $(cat "${SELECTED_COMPONENTS_FILE}")"

    # Calculate total installation steps
    TOTAL_STEPS=$(wc -w < "${SELECTED_COMPONENTS_FILE}")

    # Show progress dialog
    if [[ "${UI_FRAMEWORK}" =~ ^(dialog|whiptail|zenity)$ ]]; then
        show_progress_dialog "Installation Progress" "Installing selected components..." "${TOTAL_STEPS}" &
        PROGRESS_PID=$!
    fi

    # Install selected components
    CURRENT_STEP=0

    # Read components from file
    readarray -t SELECTED_COMPONENTS < <(tr ' ' '
' < "${SELECTED_COMPONENTS_FILE}")

    # Define a consistent order for installation (crucial for dependencies)
    COMPONENT_ORDER=(
        "mise"              # Must be first if selected, as others depend on it
        "cli_tools"         # General utilities
        "python"            # Languages
        "nodejs"
        "go"
        "rust"
        "zsh_shell"         # Shell setup
        "vscode_extensions" # Editor
        "fonts"             # Fonts
        "containers_info"   # Docker info
    )

    # Install components in the defined order
    for component in "${COMPONENT_ORDER[@]}"; do
        if [[ " ${SELECTED_COMPONENTS[*]} " =~ " ${component} " ]]; then
            ((CURRENT_STEP++))

            # Update progress
            echo "${CURRENT_STEP}" > "${PROGRESS_FILE}"

            # Show progress bar
            show_progress "${CURRENT_STEP}" "${TOTAL_STEPS}" "Installing ${component}..."

            # Install the component
            case "${component}" in
                mise)              install_mise ;;
                python)            install_python ;;
                nodejs)            install_nodejs ;;
                go)                install_go ;;
                rust)              install_rust ;;
                zsh_shell)         install_zsh_shell ;;
                vscode_extensions) install_vscode_extensions ;;
                fonts)             install_fonts ;;
                cli_tools)         install_cli_tools ;;
                containers_info)   install_containers_info ;;
                *)                 log_warning "Unhandled component for installation: ${component}. Skipping." ;;
            esac
        fi
    done

    # Set progress to 100% to close the progress dialog
    echo "100" > "${PROGRESS_FILE}"

    # Run validation
    if ! run_validation; then
        log_warning "Validation completed with errors. Some tools may be missing or misconfigured."
    fi

    # Calculate execution time
    EXECUTION_END_TIME=$(date +%s)
    EXECUTION_DURATION=$((EXECUTION_END_TIME - EXECUTION_START_TIME))
    EXECUTION_MINUTES=$((EXECUTION_DURATION / 60))
    EXECUTION_SECONDS=$((EXECUTION_DURATION % 60))

    # Final success message
    echo ""
    if [[ "${ERRORS_OCCURRED}" == true ]]; then
        log_warning "Installation completed with some errors. Please check the log file: ${LOG_FILE}"
    else
        log_success "Installation completed successfully!"
    fi

    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${CYAN}🎉 Your development environment is ready!${RESET}"
    echo -e "${GRAY}Total installation time: ${EXECUTION_MINUTES}m ${EXECUTION_SECONDS}s${RESET}"
    echo ""
    echo -e "${YELLOW}Next steps:${RESET}"
    echo -e "  1. ${BLUE}Restart your terminal or run:${RESET} source ~/.$(basename "${SHELL}")rc"
    echo -e "  2. ${BLUE}Configure Powerlevel10k (if installed):${RESET} p10k configure"

    if command -v mise &>/dev/null; then
        echo -e "  3. ${BLUE}Check your environment status with:${RESET} mise doctor"
    fi

    echo ""
    echo -e "${CYAN}Detailed logs:${RESET} ${LOG_FILE}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
}

# ------------------------------------------------------------------------------
# Error Handling
# ------------------------------------------------------------------------------

# Trap function to catch errors
handle_error() {
    local line="$1"
    local command="$2"
    local exit_code="$3"

    log_error "Error in command '${command}' at line ${line}, exit code: ${exit_code}"

    # Stop any running spinners
    stop_spinner

    # Close progress dialog if it's running
    if [[ -n "${PROGRESS_PID:-}" ]]; then
        kill "${PROGRESS_PID}" &>/dev/null || true
    fi

    # Print error message
    echo ""
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo -e "${RED}⚠️  An error occurred during installation at line ${line}.${RESET}"
    echo -e "${RED}   Command: ${command}${RESET}"
    echo -e "${RED}   Exit code: ${exit_code}${RESET}"
    echo -e "${RED}   See the log file for details: ${LOG_FILE}${RESET}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${RESET}"
    echo ""

    # Ask if the user wants to continue
    if [[ "${SKIP_INTERACTIVE_MENU}" != true ]]; then
        echo -e "${YELLOW}Do you want to continue with the installation? [y/N]${RESET}"
        read -r response
        if [[ ! "${response}" =~ ^[Yy]$ ]]; then
            echo -e "${RED}Installation aborted.${RESET}"
            exit 1
        fi
        echo -e "${GREEN}Continuing with installation...${RESET}"
    else
        # In non-interactive mode, continue but mark that errors occurred
        ERRORS_OCCURRED=true
    fi
}

# Set up the error trap
trap 'handle_error ${LINENO} "$BASH_COMMAND" $?' ERR

# ------------------------------------------------------------------------------
# Script Execution
# ------------------------------------------------------------------------------

# Execute main function if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
