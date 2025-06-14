#!/usr/bin/env bash
# Advanced Development Environment Utilities
# Companion script for the advanced installer

set -euo pipefail

readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly UTILS_VERSION="2.0.0"

# Colors
readonly RESET='[0m'
readonly RED='[0;31m'
readonly GREEN='[0;32m'
readonly YELLOW='[1;33m'
readonly BLUE='[0;34m'
readonly PURPLE='[0;35m'
readonly CYAN='[0;36m'
readonly GRAY='[0;90m'

# Helper functions
log_success() { echo -e "${GREEN}✓${RESET} $*"; }
log_error() { echo -e "${RED}✗${RESET} $*"; }
log_warning() { echo -e "${YELLOW}⚠${RESET} $*"; }
log_info() { echo -e "${BLUE}ℹ${RESET} $*"; }

# Show help
show_help() {
    echo -e "${CYAN}Advanced Development Environment Utilities v${UTILS_VERSION}${RESET}"
    echo ""
    echo "Usage: bash utils.sh <command> [options]"
    echo ""
    echo "Available commands:"
    echo ""
    echo "  ${GREEN}System Information:${RESET}"
    echo "    system-info         Show detailed system information"
    echo "    check-tools         Verify installed development tools"
    echo "    benchmark          Run performance benchmarks"
    echo ""
    echo "  ${GREEN}Environment Management:${RESET}"
    echo "    backup-dotfiles     Backup current dotfiles"
    echo "    restore-dotfiles    Restore dotfiles from backup"
    echo "    sync-config        Sync configuration with Git repository"
    echo ""
    echo "  ${GREEN}Tool Management:${RESET}"
    echo "    update-tools       Update all mise-managed tools"
    echo "    cleanup            Clean up temporary files and caches"
    echo "    fix-permissions    Fix file permissions for development tools"
    echo ""
    echo "  ${GREEN}Interactive Features:${RESET}"
    echo "    configure-git      Interactive Git configuration"
    echo "    setup-ssh          Setup SSH keys for development"
    echo "    theme-selector     Choose and apply terminal themes"
    echo ""
    echo "  ${GREEN}Maintenance:${RESET}"
    echo "    health-check       Comprehensive system health check"
    echo "    generate-report    Generate installation and status report"
    echo "    troubleshoot       Run troubleshooting diagnostics"
    echo ""
    echo "Examples:"
    echo "  bash utils.sh system-info"
    echo "  bash utils.sh backup-dotfiles"
    echo "  bash utils.sh update-tools"
    echo "  bash utils.sh health-check"
}

# System information with modern formatting
show_system_info() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                     System Information                          │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    # OS Information
    if [[ -f /etc/os-release ]]; then
        source /etc/os-release
        echo -e "${BLUE}Operating System:${RESET} ${NAME} ${VERSION}"
    else
        echo -e "${BLUE}Operating System:${RESET} $(uname -s) $(uname -r)"
    fi

    echo -e "${BLUE}Kernel:${RESET} $(uname -r)"
    echo -e "${BLUE}Architecture:${RESET} $(uname -m)"
    echo -e "${BLUE}Hostname:${RESET} $(hostname)"
    echo -e "${BLUE}User:${RESET} ${USER}"
    echo -e "${BLUE}Shell:${RESET} ${SHELL}"
    echo ""

    # Hardware Information
    if command -v nproc &>/dev/null; then
        echo -e "${BLUE}CPU Cores:${RESET} $(nproc)"
    fi

    if [[ -f /proc/meminfo ]]; then
        local mem_total=$(grep MemTotal /proc/meminfo | awk '{print $2}')
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local mem_total_gb=$((mem_total / 1024 / 1024))
        local mem_available_gb=$((mem_available / 1024 / 1024))
        echo -e "${BLUE}Memory:${RESET} ${mem_available_gb}GB available / ${mem_total_gb}GB total"
    fi

    if command -v df &>/dev/null; then
        local disk_usage=$(df -h / | tail -1 | awk '{print $4 " available / " $2 " total (" $5 " used)"}')
        echo -e "${BLUE}Disk Space:${RESET} ${disk_usage}"
    fi

    echo ""

    # Development Environment
    echo -e "${PURPLE}Development Environment:${RESET}"

    if command -v git &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Git: $(git --version | cut -d' ' -f3)"
    else
        echo -e "  ${RED}✗${RESET} Git: Not installed"
    fi

    if command -v mise &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} mise: $(mise --version | cut -d' ' -f2)"

        # Show mise-managed tools
        if mise list &>/dev/null; then
            echo "     Managed tools:"
            while IFS= read -r line; do
                echo "     - ${line}"
            done < <(mise list | head -10)
        fi
    else
        echo -e "  ${RED}✗${RESET} mise: Not installed"
    fi

    # Language runtimes
    if command -v python &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Python: $(python --version | cut -d' ' -f2)"
    fi

    if command -v node &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Node.js: $(node --version | cut -c2-)"
    fi

    if command -v go &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Go: $(go version | cut -d' ' -f3 | cut -c3-)"
    fi

    if command -v rustc &>/dev/null; then
        echo -e "  ${GREEN}✓${RESET} Rust: $(rustc --version | cut -d' ' -f2)"
    fi

    echo ""
}

# Comprehensive tool verification
check_tools() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                    Development Tools Check                      │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    local tools_to_check=(
        "git:Git version control"
        "curl:HTTP client"
        "wget:File downloader"
        "vim:Text editor"
        "zsh:Z shell"
        "tmux:Terminal multiplexer"
        "fzf:Fuzzy finder"
        "jq:JSON processor"
        "tree:Directory tree viewer"
        "htop:Process viewer"
        "mise:Tool version manager"
        "python:Python interpreter"
        "node:Node.js runtime"
        "npm:Node package manager"
        "go:Go programming language"
        "rustc:Rust compiler"
        "docker:Container platform"
    )

    local missing_tools=()
    local installed_count=0
    local total_count=${#tools_to_check[@]}

    for tool_desc in "${tools_to_check[@]}"; do
        local tool_name="${tool_desc%%:*}"
        local tool_description="${tool_desc#*:}"

        if command -v "${tool_name}" &>/dev/null; then
            local version=""
            case "${tool_name}" in
                git)     version="$(git --version | cut -d' ' -f3)" ;;
                python)  version="$(python --version 2>&1 | cut -d' ' -f2)" ;;
                node)    version="$(node --version | cut -c2-)" ;;
                go)      version="$(go version | cut -d' ' -f3 | cut -c3-)" ;;
                rustc)   version="$(rustc --version | cut -d' ' -f2)" ;;
                mise)    version="$(mise --version | cut -d' ' -f2)" ;;
                *)       version="installed" ;;
            esac
            echo -e "  ${GREEN}✓${RESET} ${tool_name} (${tool_description}) - ${version}"
            ((installed_count++))
        else
            echo -e "  ${RED}✗${RESET} ${tool_name} (${tool_description}) - Not found"
            missing_tools+=("${tool_name}")
        fi
    done

    echo ""
    echo -e "${BLUE}Summary:${RESET} ${installed_count}/${total_count} tools installed"

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        echo -e "${YELLOW}Missing tools:${RESET} ${missing_tools[*]}"
        echo -e "${GRAY}Run the installer to install missing tools.${RESET}"
    else
        echo -e "${GREEN}All essential development tools are installed!${RESET}"
    fi

    echo ""
}

# Performance benchmark
run_benchmark() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                   Performance Benchmark                        │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    if ! command -v hyperfine &>/dev/null; then
        log_warning "hyperfine not found. Installing it..."

        # Try to install hyperfine
        if command -v cargo &>/dev/null; then
            cargo install hyperfine
        else
            log_error "Cannot install hyperfine. Please install it manually."
            return 1
        fi
    fi

    log_info "Running shell startup benchmark..."

    # Benchmark shell startup times
    if command -v bash &>/dev/null && command -v zsh &>/dev/null; then
        hyperfine --warmup 3 'bash -i -c exit' 'zsh -i -c exit' || {
            log_warning "Shell benchmark failed, running basic timing..."

            # Fallback to basic timing
            echo "Bash startup time:"
            time bash -i -c exit
            echo ""
            echo "Zsh startup time:"
            time zsh -i -c exit
        }
    fi

    echo ""
    log_info "Running common command benchmarks..."

    # Create test file for benchmarks
    local test_file="/tmp/benchmark_test_file"
    seq 1 10000 > "${test_file}"

    # Benchmark common commands
    if command -v cat &>/dev/null && command -v bat &>/dev/null; then
        echo "File reading (cat vs bat):"
        hyperfine --warmup 2 "cat ${test_file}" "bat ${test_file}" || {
            log_warning "File reading benchmark failed"
        }
    fi

    if command -v grep &>/dev/null && command -v rg &>/dev/null; then
        echo "Text searching (grep vs ripgrep):"
        hyperfine --warmup 2 "grep '5000' ${test_file}" "rg '5000' ${test_file}" || {
            log_warning "Text searching benchmark failed"
        }
    fi

    # Clean up
    rm -f "${test_file}"

    echo ""
    log_success "Benchmark completed!"
}

# Update all mise-managed tools
update_tools() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                     Updating Tools                             │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    if ! command -v mise &>/dev/null; then
        log_error "mise not found. Please install it first."
        return 1
    fi

    log_info "Updating mise itself..."
    mise self-update || log_warning "Failed to update mise"

    log_info "Updating all mise-managed tools..."
    mise upgrade || log_warning "Failed to update some tools"

    # Update global npm packages if available
    if command -v npm &>/dev/null; then
        log_info "Updating global npm packages..."
        npm update -g || log_warning "Failed to update npm packages"
    fi

    # Update cargo packages if available
    if command -v cargo &>/dev/null && command -v cargo-install-update &>/dev/null; then
        log_info "Updating cargo packages..."
        cargo install-update -a || log_warning "Failed to update cargo packages"
    fi

    log_success "Tool updates completed!"
}

# Cleanup temporary files and caches
cleanup() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                       Cleanup                                   │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    local cleaned_size=0

    # Clean mise cache
    if command -v mise &>/dev/null; then
        log_info "Cleaning mise cache..."
        if mise cache clear &>/dev/null; then
            log_success "mise cache cleared"
        else
            log_warning "Failed to clear mise cache"
        fi
    fi

    # Clean npm cache
    if command -v npm &>/dev/null; then
        log_info "Cleaning npm cache..."
        local npm_cache_size=$(du -sm $(npm config get cache) 2>/dev/null | cut -f1 || echo "0")
        npm cache clean --force &>/dev/null
        log_success "npm cache cleaned (${npm_cache_size}MB freed)"
        cleaned_size=$((cleaned_size + npm_cache_size))
    fi

    # Clean cargo cache
    if command -v cargo &>/dev/null && [[ -d "$HOME/.cargo" ]]; then
        log_info "Cleaning cargo cache..."
        local cargo_cache_size=$(du -sm "$HOME/.cargo/registry" 2>/dev/null | cut -f1 || echo "0")
        if command -v cargo-cache &>/dev/null; then
            cargo cache --autoclean || log_warning "Failed to clean cargo cache"
        else
            log_info "cargo-cache not installed. Skipping automatic cleanup."
        fi
        log_success "cargo cache cleaned (${cargo_cache_size}MB freed)"
        cleaned_size=$((cleaned_size + cargo_cache_size))
    fi

    # Clean system package cache
    if command -v apt-get &>/dev/null; then
        log_info "Cleaning apt cache..."
        sudo apt-get clean &>/dev/null
        sudo apt-get autoremove --purge -y &>/dev/null
        log_success "apt cache cleaned"
    elif command -v dnf &>/dev/null; then
        log_info "Cleaning dnf cache..."
        sudo dnf clean all &>/dev/null
        log_success "dnf cache cleaned"
    elif command -v brew &>/dev/null; then
        log_info "Cleaning Homebrew cache..."
        brew cleanup &>/dev/null
        log_success "Homebrew cache cleaned"
    fi

    # Clean temporary files
    log_info "Cleaning temporary files..."
    rm -rf /tmp/mise-* /tmp/install-* ~/.cache/mise/* 2>/dev/null || true
    log_success "Temporary files cleaned"

    echo ""
    log_success "Cleanup completed! Approximately ${cleaned_size}MB freed."
}

# Interactive Git configuration
configure_git() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                   Git Configuration                            │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    if ! command -v git &>/dev/null; then
        log_error "Git not found. Please install Git first."
        return 1
    fi

    # Get current configuration
    local current_name=$(git config --global user.name 2>/dev/null || echo "")
    local current_email=$(git config --global user.email 2>/dev/null || echo "")

    # Configure name
    echo -e "${BLUE}Current name:${RESET} ${current_name:-"(not set)"}"
    echo -n "Enter your full name: "
    read -r user_name
    if [[ -n "${user_name}" ]]; then
        git config --global user.name "${user_name}"
        log_success "Name set to: ${user_name}"
    fi

    # Configure email
    echo -e "${BLUE}Current email:${RESET} ${current_email:-"(not set)"}"
    echo -n "Enter your email address: "
    read -r user_email
    if [[ -n "${user_email}" ]]; then
        git config --global user.email "${user_email}"
        log_success "Email set to: ${user_email}"
    fi

    # Configure editor
    local current_editor=$(git config --global core.editor 2>/dev/null || echo "")
    echo -e "${BLUE}Current editor:${RESET} ${current_editor:-"(not set)"}"
    echo "Select preferred editor:"
    echo "  1) vim"
    echo "  2) nano"
    echo "  3) code (VS Code)"
    echo "  4) Keep current"
    echo -n "Choice [1-4]: "
    read -r editor_choice

    case "${editor_choice}" in
        1) git config --global core.editor "vim" && log_success "Editor set to vim" ;;
        2) git config --global core.editor "nano" && log_success "Editor set to nano" ;;
        3) git config --global core.editor "code --wait" && log_success "Editor set to VS Code" ;;
        4) log_info "Keeping current editor setting" ;;
        *) log_warning "Invalid choice, keeping current setting" ;;
    esac

    # Configure default branch
    echo -n "Set default branch name to 'main'? [Y/n]: "
    read -r branch_choice
    if [[ "${branch_choice}" != "n" && "${branch_choice}" != "N" ]]; then
        git config --global init.defaultBranch main
        log_success "Default branch set to 'main'"
    fi

    # Configure useful aliases
    echo -n "Install useful Git aliases? [Y/n]: "
    read -r alias_choice
    if [[ "${alias_choice}" != "n" && "${alias_choice}" != "N" ]]; then
        git config --global alias.st status
        git config --global alias.br branch
        git config --global alias.co checkout
        git config --global alias.cm commit
        git config --global alias.lg "log --oneline --graph --all"
        log_success "Git aliases installed"
    fi

    echo ""
    log_success "Git configuration completed!"
    git config --global --list | grep "user\.\|core\.editor\|init\.defaultBranch" || true
}

# Health check
health_check() {
    echo -e "${CYAN}╭─────────────────────────────────────────────────────────────────╮${RESET}"
    echo -e "${CYAN}│                     Health Check                               │${RESET}"
    echo -e "${CYAN}╰─────────────────────────────────────────────────────────────────╯${RESET}"
    echo ""

    local issues=0

    # Check disk space
    local available_space=$(df / | tail -1 | awk '{print $4}')
    local available_gb=$((available_space / 1024 / 1024))

    if [[ ${available_gb} -lt 5 ]]; then
        log_error "Low disk space: ${available_gb}GB available"
        ((issues++))
    else
        log_success "Disk space: ${available_gb}GB available"
    fi

    # Check memory
    if [[ -f /proc/meminfo ]]; then
        local mem_available=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
        local mem_available_gb=$((mem_available / 1024 / 1024))

        if [[ ${mem_available_gb} -lt 2 ]]; then
            log_warning "Low memory: ${mem_available_gb}GB available"
            ((issues++))
        else
            log_success "Memory: ${mem_available_gb}GB available"
        fi
    fi

    # Check essential tools
    local essential_tools=("git" "curl" "wget")
    for tool in "${essential_tools[@]}"; do
        if command -v "${tool}" &>/dev/null; then
            log_success "${tool} is installed"
        else
            log_error "${tool} is missing"
            ((issues++))
        fi
    done

    # Check mise if installed
    if command -v mise &>/dev/null; then
        if mise doctor &>/dev/null; then
            log_success "mise configuration is healthy"
        else
            log_warning "mise configuration has issues"
            ((issues++))
        fi
    fi

    # Check shell configuration
    if [[ -f "$HOME/.zshrc" ]]; then
        log_success "Zsh configuration found"
    elif [[ -f "$HOME/.bashrc" ]]; then
        log_success "Bash configuration found"
    else
        log_warning "No shell configuration found"
        ((issues++))
    fi

    echo ""
    if [[ ${issues} -eq 0 ]]; then
        log_success "Health check passed! No issues found."
    else
        log_warning "Health check completed with ${issues} issue(s)."
    fi
}

# Main function to route commands
main() {
    case "${1:-}" in
        system-info)
            show_system_info
            ;;
        check-tools)
            check_tools
            ;;
        benchmark)
            run_benchmark
            ;;
        update-tools)
            update_tools
            ;;
        cleanup)
            cleanup
            ;;
        configure-git)
            configure_git
            ;;
        health-check)
            health_check
            ;;
        help|--help|-h)
            show_help
            ;;
        "")
            echo -e "${RED}Error: No command specified.${RESET}"
            echo ""
            show_help
            exit 1
            ;;
        *)
            echo -e "${RED}Error: Unknown command '${1}'.${RESET}"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Execute main function
main "$@"
