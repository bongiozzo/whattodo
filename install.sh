#!/usr/bin/env bash
# install.sh - Universal installer for text-forge content projects
# Works on: macOS, Linux, Windows (Git Bash/WSL)

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${BLUE}==>${NC} $1"
}

log_success() {
    echo -e "${GREEN}✓${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}⚠${NC} $1"
}

log_error() {
    echo -e "${RED}✗${NC} $1"
}

# Detect OS
detect_os() {
    case "$(uname -s)" in
        Darwin*)
            OS="macos"
            ;;
        Linux*)
            OS="linux"
            ;;
        CYGWIN*|MINGW*|MSYS*)
            OS="windows"
            ;;
        *)
            log_error "Unsupported OS: $(uname -s)"
            exit 1
            ;;
    esac
    log_info "Detected OS: $OS"
}

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Install uv (universal Python package manager)
install_uv() {
    if command_exists uv; then
        log_success "uv is already installed ($(uv --version))"
        return 0
    fi

    log_info "Installing uv..."
    
    if [[ "$OS" == "windows" ]]; then
        # Windows (Git Bash/MSYS)
        powershell -c "irm https://astral.sh/uv/install.ps1 | iex" || {
            log_error "Failed to install uv. Please install manually from https://docs.astral.sh/uv/getting-started/installation/"
            exit 1
        }
    else
        # macOS and Linux
        curl -LsSf https://astral.sh/uv/install.sh | sh || {
            log_error "Failed to install uv. Please install manually from https://docs.astral.sh/uv/getting-started/installation/"
            exit 1
        }
    fi

    # Add uv to PATH for current session
    export PATH="$HOME/.cargo/bin:$PATH"
    
    if command_exists uv; then
        log_success "uv installed successfully ($(uv --version))"
    else
        log_warn "uv was installed but not found in PATH. Please restart your terminal or run: export PATH=\"\$HOME/.cargo/bin:\$PATH\""
        exit 1
    fi
}

# Install pandoc
install_pandoc() {
    if command_exists pandoc; then
        log_success "pandoc is already installed ($(pandoc --version | head -n1))"
        return 0
    fi

    log_info "Installing pandoc..."

    case "$OS" in
        macos)
            if command_exists brew; then
                brew install pandoc || {
                    log_error "Failed to install pandoc via Homebrew"
                    exit 1
                }
            else
                log_warn "Homebrew not found. Install it from https://brew.sh/ then run: brew install pandoc"
                log_warn "Or download pandoc from https://pandoc.org/installing.html"
                exit 1
            fi
            ;;
        linux)
            if command_exists apt-get; then
                sudo apt-get update && sudo apt-get install -y pandoc || {
                    log_error "Failed to install pandoc via apt-get"
                    exit 1
                }
            elif command_exists yum; then
                sudo yum install -y pandoc || {
                    log_error "Failed to install pandoc via yum"
                    exit 1
                }
            elif command_exists dnf; then
                sudo dnf install -y pandoc || {
                    log_error "Failed to install pandoc via dnf"
                    exit 1
                }
            elif command_exists pacman; then
                sudo pacman -S --noconfirm pandoc || {
                    log_error "Failed to install pandoc via pacman"
                    exit 1
                }
            else
                log_warn "No supported package manager found. Please install pandoc manually from https://pandoc.org/installing.html"
                exit 1
            fi
            ;;
        windows)
            log_warn "Automatic pandoc installation not supported on Windows."
            log_warn "Please install pandoc manually:"
            log_warn "  1. Download from https://pandoc.org/installing.html"
            log_warn "  2. Or use Chocolatey: choco install pandoc"
            log_warn "  3. Or use Scoop: scoop install pandoc"
            exit 1
            ;;
    esac

    if command_exists pandoc; then
        log_success "pandoc installed successfully ($(pandoc --version | head -n1))"
    else
        log_error "pandoc installation failed"
        exit 1
    fi
}

# Install Python dependencies via uv
install_dependencies() {
    log_info "Installing Python dependencies..."
    
    if [[ ! -f "pyproject.toml" ]]; then
        log_error "pyproject.toml not found. Are you in the project directory?"
        exit 1
    fi

    uv sync || {
        log_error "Failed to install dependencies. Check pyproject.toml and uv.lock"
        exit 1
    }

    log_success "Python dependencies installed (including text-forge)"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local all_ok=true
    
    if ! command_exists uv; then
        log_error "uv not found"
        all_ok=false
    fi
    
    if ! command_exists pandoc; then
        log_error "pandoc not found"
        all_ok=false
    fi
    
    if ! command_exists python3 && ! command_exists python; then
        log_error "Python not found"
        all_ok=false
    fi
    
    if [[ "$all_ok" == "false" ]]; then
        log_error "Installation verification failed"
        exit 1
    fi
    
    log_success "All tools are installed correctly"
}

# Main installation flow
main() {
    echo ""
    log_info "text-forge installation script"
    echo ""
    
    detect_os
    
    # Step 1: Install uv
    install_uv
    
    # Step 2: Install pandoc
    install_pandoc
    
    # Step 3: Install Python dependencies (including text-forge)
    install_dependencies
    
    # Step 4: Verify everything works
    verify_installation
    
    echo ""
    log_success "Installation complete!"
    echo ""
    log_info "Next steps:"
    echo "  make serve    # Start local preview server"
    echo "  make epub     # Build EPUB only"
    echo "  make all      # Build EPUB + site"
    echo ""
    
    # Optionally start server
    read -p "Start local preview server now? (y/N) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Starting server..."
        make serve
    fi
}

main "$@"