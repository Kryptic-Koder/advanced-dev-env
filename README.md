# Advanced Development Environment Installer v2.0

A fully interactive, modern development environment setup script with enhanced UI, real-time progress tracking, and comprehensive tool management.

## 🚀 Features

### Interactive User Interface
- **Multiple UI Frameworks**: Automatically detects and uses the best available UI (dialog, whiptail, zenity, fzf)
- **Real-time Progress Tracking**: Visual progress bars and animations
- **Dynamic Theming**: Support for multiple color schemes (Catppuccin, Nord, Dracula, Solarized)
- **Cross-platform Compatibility**: Works on Linux, macOS, and Windows (WSL)

### Modern Tool Management
- **mise Integration**: Universal tool version manager (replaces nvm, pyenv, etc.)
- **Programming Languages**: Python, Node.js, Go, Rust with development tools
- **Shell Enhancement**: Zsh with Oh My Zsh, Powerlevel10k, and productivity plugins
- **CLI Tools**: Modern replacements (ripgrep, bat, exa, fd, fzf, etc.)

### Advanced Features
- **Configuration Management**: TOML-based configuration with customization
- **Dotfiles Backup/Restore**: Automatic backup before changes
- **Error Recovery**: Comprehensive error handling with continue/abort options
- **Security**: Download verification and secure permissions
- **Logging**: Detailed installation logs with different verbosity levels

## 📁 Project Structure

```
advanced-dev-env/
├── advanced_install.sh     # Main installer script (1,500+ lines)
├── utils.sh               # Utilities and maintenance tools
├── install_config.toml    # Configuration file
├── README.md             # This documentation
└── configs/              # Configuration templates
    ├── zsh/
    ├── fonts/
    └── git/
```

## 🔧 Installation

### Quick Start

```bash
# Download the scripts
curl -O https://raw.githubusercontent.com/your-repo/advanced-install.sh
curl -O https://raw.githubusercontent.com/your-repo/utils.sh
curl -O https://raw.githubusercontent.com/your-repo/install_config.toml

# Make executable
chmod +x advanced_install.sh utils.sh

# Run interactive installation
./advanced_install.sh
```

### Installation Options

#### Interactive Mode (Recommended)
```bash
./advanced_install.sh
```
- Presents a beautiful checklist menu for component selection
- Real-time progress tracking with visual feedback
- Error recovery with user prompts

#### Non-Interactive Mode
```bash
./advanced_install.sh --yes
```
- Installs all default components without prompts
- Perfect for automation and CI/CD pipelines

#### Verbose Mode
```bash
./advanced_install.sh --verbose
```
- Detailed output for troubleshooting
- Debug-level logging

#### Dry Run Mode
```bash
./advanced_install.sh --dry-run
```
- Shows what would be installed without making changes
- Perfect for testing and validation

#### Debug Mode
```bash
./advanced_install.sh --debug
```
- Enables bash debugging (set -x)
- Maximum verbosity for development

## 🛠️ Components Available

### Essential Tools
- **[mise](https://mise.jdx.dev)**: Universal tool version manager
- **Git**: Version control with enhanced configuration
- **Curl/Wget**: HTTP clients and downloaders

### Programming Languages

#### Python 3.12+
- **uv**: Ultra-fast Python package manager
- **ruff**: Extremely fast Python linter
- **black**: Code formatter
- **pytest**: Testing framework
- **mypy**: Static type checker

#### Node.js (LTS)
- **Bun**: Fast JavaScript runtime and package manager
- **pnpm**: Efficient package manager
- **TypeScript**: JavaScript with types
- **ESLint**: Code linting
- **Prettier**: Code formatting

#### Go (Latest)
- **golangci-lint**: Comprehensive linter
- **Delve**: Debugger
- **goimports**: Import management

#### Rust (Stable)
- **cargo-edit**: Enhanced Cargo commands
- **cargo-watch**: File watching for development
- **sccache**: Compilation cache
- **Modern CLI tools**: ripgrep, bat, exa, fd

### Shell Enhancement

#### Zsh Configuration
- **Oh My Zsh**: Framework with plugins
- **Powerlevel10k**: Beautiful, fast theme
- **Plugins**: autosuggestions, syntax-highlighting, fzf
- **Custom aliases** and productivity shortcuts

### Development Tools
- **VS Code Extensions**: Essential extensions for each language
- **Nerd Fonts**: JetBrains Mono with icons and symbols
- **CLI Tools**: jq, htop, tmux, tree, and modern replacements

## 🎨 User Interface Frameworks

The installer automatically detects and uses the best available UI framework:

### Zenity (GUI - Linux/macOS with X11)
- Native GTK dialogs
- Beautiful graphical interface
- Progress notifications

### Dialog (TUI - Universal)
- Text-based user interface
- Works in any terminal
- Professional appearance

### Whiptail (TUI - Minimal)
- Lightweight alternative to dialog
- Pre-installed on many systems
- Clean, simple interface

### fzf (Interactive Filter)
- Fuzzy finding capabilities
- Keyboard-driven selection
- Minimalist design

### Basic Terminal (Fallback)
- Works on any system
- Simple text prompts
- No dependencies

## ⚙️ Configuration

### TOML Configuration File (`install_config.toml`)

```toml
[installer]
version = "2.0.0"
ui_framework = "auto"  # auto, dialog, whiptail, zenity, fzf
theme = "catppuccin"   # catppuccin, nord, dracula, solarized
log_level = "info"     # debug, info, warn, error

[tools.languages.python]
version = "3.12"
tools = ["uv", "ruff", "black", "pytest", "mypy"]
auto_install = true
interactive_config = true

[ui]
animations = true
progress_bars = true
colors = true
notifications = true
ascii_art = true

[security]
verify_downloads = true
gpg_verification = true
secure_permissions = true
audit_log = true
```

### Environment Variables (`.env`)

```bash
# Override configuration
UI_FRAMEWORK=dialog
THEME=nord
LOG_LEVEL=debug

# Installation options
SKIP_VALIDATION=false
BACKUP_DOTFILES=true
INSTALL_FONTS=true
```

## 🔨 Utilities Script

The `utils.sh` script provides maintenance and diagnostic tools:

### System Information
```bash
./utils.sh system-info
```
- Detailed system specifications
- Hardware information
- Development environment status

### Tool Management
```bash
./utils.sh check-tools        # Verify installed tools
./utils.sh update-tools       # Update all mise-managed tools
./utils.sh cleanup           # Clean caches and temporary files
```

### Health Check
```bash
./utils.sh health-check
```
- Comprehensive system diagnostics
- Identifies potential issues
- Suggests fixes

### Interactive Configuration
```bash
./utils.sh configure-git     # Interactive Git setup
```

### Performance Benchmarking
```bash
./utils.sh benchmark
```
- Shell startup time comparison
- Command performance testing
- System performance metrics

## 📊 Progress Tracking

The installer provides real-time feedback through multiple mechanisms:

### Visual Progress Bars
- ASCII progress bars with percentage
- Animated spinners during operations
- Color-coded status indicators

### Logging Levels
- **Debug**: Detailed operation information
- **Info**: General progress updates
- **Warn**: Non-critical issues
- **Error**: Failed operations

### Error Recovery
- Interactive error handling
- Option to continue or abort
- Detailed error context

## 🔒 Security Features

### Download Verification
- SHA256 checksum verification
- GPG signature validation where available
- Secure HTTPS downloads

### Permission Management
- Secure file permissions
- User-specific installations
- No unnecessary sudo usage

### Audit Trail
- Comprehensive installation logs
- Security event logging
- Change tracking

## 🌍 Cross-Platform Support

### Linux
- **Ubuntu/Debian**: APT package management
- **RHEL/Fedora**: DNF/YUM package management
- **Arch**: Pacman package management
- **Alpine**: APK package management

### macOS
- **Homebrew**: Package management
- **Xcode Command Line Tools**: Development prerequisites
- **M1/Intel**: Universal compatibility

### Windows
- **WSL**: Full Linux compatibility
- **Native Windows**: Limited support via winget
- **MSYS2/Cygwin**: Partial compatibility

## 🐛 Troubleshooting

### Common Issues

#### UI Framework Not Found
```bash
# Install dialog on Ubuntu/Debian
sudo apt install dialog

# Install dialog on RHEL/Fedora
sudo dnf install dialog

# Install dialog on macOS
brew install dialog
```

#### mise Installation Failed
```bash
# Manual installation
curl https://mise.run | sh
export PATH="$HOME/.local/bin:$PATH"
```

#### Permission Denied
```bash
# Fix script permissions
chmod +x advanced_install.sh utils.sh

# Check user permissions
ls -la ~/.local/bin/
```

### Debug Mode
Run with debug mode for detailed troubleshooting:
```bash
./advanced_install.sh --debug 2>&1 | tee debug.log
```

### Log Analysis
Installation logs are saved with timestamps:
```bash
# View latest log
tail -f ~/.dotfiles-install/logs/install_*.log

# Search for errors
grep -i error ~/.dotfiles-install/logs/install_*.log
```

## 🤝 Contributing

### Development Setup
1. Fork the repository
2. Create a feature branch
3. Test on multiple platforms
4. Submit a pull request

### Testing
```bash
# Test in Docker container
docker run -it ubuntu:latest bash
# Run installer in container

# Test dry run mode
./advanced_install.sh --dry-run

# Test with different UI frameworks
UI_FRAMEWORK=dialog ./advanced_install.sh
UI_FRAMEWORK=whiptail ./advanced_install.sh
```

### Adding New Tools
1. Add tool definition to `install_config.toml`
2. Implement installation function in `advanced_install.sh`
3. Add validation check
4. Update documentation

## 📈 Performance

### Optimization Features
- **Parallel downloads** where possible
- **Cached installations** to avoid re-downloading
- **Minimal dependencies** for faster startup
- **Efficient package management** with mise

### Benchmarks
- **Shell startup**: < 200ms with optimized configuration
- **Tool switching**: Instant with mise
- **Installation time**: 5-15 minutes depending on components

## 📜 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- [mise](https://mise.jdx.dev) for universal tool management
- [Oh My Zsh](https://ohmyz.sh) for shell enhancement
- [Powerlevel10k](https://github.com/romkatv/powerlevel10k) for beautiful theming
- [fzf](https://github.com/junegunn/fzf) for fuzzy finding
- The open-source community for excellent development tools

## 📞 Support

- **Issues**: [GitHub Issues](https://github.com/your-repo/issues)
- **Discussions**: [GitHub Discussions](https://github.com/your-repo/discussions)
- **Documentation**: This README and inline comments

---

**Made with ❤️ for developers by developers**