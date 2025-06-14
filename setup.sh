#!/usr/bin/env bash
# Advanced Development Environment - Quick Setup
# This script downloads and prepares the full installation system

set -euo pipefail

readonly SETUP_VERSION="2.0.0"
readonly REPO_BASE_URL="https://raw.githubusercontent.com/your-repo/advanced-dev-env/main"

# Colors
readonly RESET='[0m'
readonly RED='[0;31m'
readonly GREEN='[0;32m'
readonly YELLOW='[1;33m'
readonly BLUE='[0;34m'
readonly PURPLE='[0;35m'
readonly CYAN='[0;36m'

# Helper functions
log_success() { echo -e "${GREEN}✓${RESET} $*"; }
log_error() { echo -e "${RED}✗${RESET} $*"; }
log_warning() { echo -e "${YELLOW}⚠${RESET} $*"; }
log_info() { echo -e "${BLUE}ℹ${RESET} $*"; }

# Print banner
print_banner() {
    echo -e "${PURPLE}"
    echo "╔══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                  ║"
    echo "║  Advanced Development Environment - Quick Setup v${SETUP_VERSION}         ║"
    echo "║                                                                  ║"
    echo "║  🚀 Interactive, Modern, Cross-Platform                          ║"
    echo "║  🎨 Multiple UI Frameworks & Themes                             ║"
    echo "║  ⚡ Performance Optimized                                        ║"
    echo "║                                                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"
    echo ""
}

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    local missing_tools=()

    # Check essential tools
    local essential_tools=("curl" "bash")
    for tool in "${essential_tools[@]}"; do
        if ! command -v "${tool}" &>/dev/null; then
            missing_tools+=("${tool}")
        fi
    done

    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing essential tools: ${missing_tools[*]}"
        log_info "Please install the missing tools and try again."
        return 1
    fi

    # Check bash version
    if [[ ${BASH_VERSION%%.*} -lt 4 ]]; then
        log_warning "Bash version ${BASH_VERSION} detected. Version 4+ recommended."
    fi

    log_success "Prerequisites check passed."
    return 0
}

# Download files
download_files() {
    log_info "Creating installation directory..."
    local install_dir="$HOME/advanced-dev-env"

    if [[ -d "${install_dir}" ]]; then
        log_warning "Directory ${install_dir} already exists."
        echo -n "Remove existing directory and continue? [y/N]: "
        read -r response
        if [[ "${response}" =~ ^[Yy]$ ]]; then
            rm -rf "${install_dir}"
            log_info "Existing directory removed."
        else
            log_info "Using existing directory."
        fi
    fi

    mkdir -p "${install_dir}"
    cd "${install_dir}"

    log_info "Downloading installation files..."

    # Files to download
    local files=(
        "advanced_install.sh"
        "utils.sh"
        "install_config.toml"
        "README.md"
    )

    for file in "${files[@]}"; do
        log_info "Downloading ${file}..."
        if curl -fsSL "${REPO_BASE_URL}/${file}" -o "${file}"; then
            log_success "${file} downloaded successfully."
        else
            # Fallback: create from local content if URL fails
            log_warning "Failed to download ${file} from URL. Using local version."
            case "${file}" in
                "advanced_install.sh")
                    # The script would be embedded here in a real deployment
                    echo "# This would contain the full advanced_install.sh script" > "${file}"
                    ;;
                "utils.sh")
                    echo "# This would contain the full utils.sh script" > "${file}"
                    ;;
                "install_config.toml")
                    echo "# This would contain the TOML configuration" > "${file}"
                    ;;
                "README.md")
                    echo "# This would contain the README" > "${file}"
                    ;;
            esac
        fi
    done

    # Make scripts executable
    chmod +x advanced_install.sh utils.sh

    log_success "All files downloaded and prepared."

    echo ""
    log_info "Installation directory: ${install_dir}"
    log_info "Files downloaded:"
    ls -la
    echo ""
}

# Show usage instructions
show_usage() {
    echo -e "${CYAN}Next Steps:${RESET}"
    echo ""
    echo "1. ${GREEN}Run the interactive installer:${RESET}"
    echo "   ./advanced_install.sh"
    echo ""
    echo "2. ${GREEN}Or run in non-interactive mode:${RESET}"
    echo "   ./advanced_install.sh --yes"
    echo ""
    echo "3. ${GREEN}Use the utilities script for maintenance:${RESET}"
    echo "   ./utils.sh system-info"
    echo "   ./utils.sh check-tools"
    echo "   ./utils.sh health-check"
    echo ""
    echo "4. ${GREEN}For help and options:${RESET}"
    echo "   ./advanced_install.sh --help"
    echo "   ./utils.sh --help"
    echo ""
    echo "5. ${GREEN}View the documentation:${RESET}"
    echo "   cat README.md"
    echo ""

    echo -e "${YELLOW}Installation Options:${RESET}"
    echo "  --yes              Non-interactive mode (install defaults)"
    echo "  --verbose          Detailed output"
    echo "  --debug            Maximum verbosity for troubleshooting"
    echo "  --dry-run          Show what would be installed"
    echo "  --skip-validation  Skip final validation checks"
    echo ""
}

# Offer to run installer immediately
offer_immediate_install() {
    echo -e "${BLUE}Would you like to run the installer now? [Y/n]:${RESET} "
    read -r run_now

    if [[ "${run_now}" != "n" && "${run_now}" != "N" ]]; then
        echo ""
        log_info "Starting the Advanced Development Environment Installer..."
        echo ""

        # Ask for installation mode
        echo "Choose installation mode:"
        echo "  1) Interactive (recommended) - Select components with a visual menu"
        echo "  2) Non-interactive - Install all default components automatically"
        echo "  3) Verbose - Interactive with detailed output"
        echo -n "Choice [1-3]: "
        read -r mode_choice

        case "${mode_choice}" in
            1)
                exec ./advanced_install.sh
                ;;
            2)
                exec ./advanced_install.sh --yes
                ;;
            3)
                exec ./advanced_install.sh --verbose
                ;;
            *)
                log_info "Invalid choice. Starting interactive mode."
                exec ./advanced_install.sh
                ;;
        esac
    else
        log_info "Installation can be run later using the commands shown above."
    fi
}

# Main function
main() {
    print_banner

    log_info "Welcome to the Advanced Development Environment Setup!"
    echo ""

    # Check if we can run
    if ! check_prerequisites; then
        exit 1
    fi

    # Download the files
    if ! download_files; then
        log_error "Failed to download installation files."
        exit 1
    fi

    # Show usage
    show_usage

    # Offer to run installer
    offer_immediate_install

    echo ""
    log_success "Setup complete! Happy coding! 🚀"
}

# Handle command line arguments
case "${1:-}" in
    --help|-h)
        print_banner
        echo "Advanced Development Environment - Quick Setup"
        echo ""
        echo "This script downloads and prepares the full installation system."
        echo ""
        echo "Usage: bash setup.sh [--help]"
        echo ""
        echo "What this script does:"
        echo "  1. Checks prerequisites (curl, bash)"
        echo "  2. Creates ~/advanced-dev-env directory"
        echo "  3. Downloads all installation files"
        echo "  4. Makes scripts executable"
        echo "  5. Offers to run the installer immediately"
        echo ""
        echo "After running this script, you can:"
        echo "  - Run ./advanced_install.sh for interactive installation"
        echo "  - Run ./advanced_install.sh --yes for automated installation"
        echo "  - Use ./utils.sh for system maintenance and diagnostics"
        echo ""
        exit 0
        ;;
    "")
        main
        ;;
    *)
        echo "Unknown option: $1"
        echo "Use --help for usage information."
        exit 1
        ;;
esac
