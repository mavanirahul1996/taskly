#!/usr/bin/env bash

set -Eeuo pipefail

PROJECT_DIR="$(pwd)"
PYTHON_VERSION="3.12"
VENV="$PROJECT_DIR/.venv312"

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

success() { echo -e "${GREEN}SUCCESS: $1${NC}"; }
error()   { echo -e "${RED}ERROR: $1${NC}"; }
info()    { echo -e "${YELLOW}INFO: $1${NC}"; }

echo "======================================"
echo "       TASKLY PROJECT SETUP"
echo "======================================"

# 1. Check project directory
if [[ ! -f "$PROJECT_DIR/requirements-dev.txt" ]]; then
    error "requirements-dev.txt not found."
    echo "Run this script from the Taskly project directory."
    exit 1
fi

success "Taskly project detected."

# 2. Install uv if missing
if ! command -v uv >/dev/null 2>&1; then
    if [[ -x "$HOME/.local/bin/uv" ]]; then
        export PATH="$HOME/.local/bin:$PATH"
    else
        info "Installing uv..."
        curl -LsSf https://astral.sh/uv/install.sh | sh
        export PATH="$HOME/.local/bin:$PATH"
    fi
fi

success "uv is available."

# 3. Install Python 3.12
info "Installing Python $PYTHON_VERSION..."
uv python install "$PYTHON_VERSION"

# 4. Create virtual environment
info "Creating Python virtual environment..."
if [[ -d "$VENV" ]]; then
    mv "$VENV" "${VENV}.backup-$(date +%Y%m%d-%H%M%S)"
fi

uv venv "$VENV" --python "$PYTHON_VERSION"

# 5. Install project dependencies
info "Installing development dependencies..."
uv pip install --python "$VENV/bin/python" \
    -r "$PROJECT_DIR/requirements-dev.txt"

success "Dependencies installed."

# 6. Ignore virtual environment in Git
touch "$PROJECT_DIR/.gitignore"

if ! grep -qxF '.venv/' "$PROJECT_DIR/.gitignore"; then
    echo '.venv/' >> "$PROJECT_DIR/.gitignore"
fi

success "Virtual environment added to Git ignore."

# 7. Show Python and package versions
echo
info "Python version:"
"$VENV/bin/python" --version

echo
info "Installed packages:"
uv pip list --python "$VENV/bin/python"

# 8. Run tests
echo
info "Running Taskly tests..."

cd "$PROJECT_DIR"

if PYTHONPATH="$PROJECT_DIR" "$VENV/bin/python" -m pytest -v; then
    success "All local tests passed."
else
    error "Some tests failed."
    echo "Review the error above before changing application code."
    exit 1
fi

# 9. Final Git status
echo
echo "======================================"
echo "          SETUP COMPLETED"
echo "======================================"

git status --short

echo
success "Taskly local Python setup and tests completed."
echo "Next: Fix or verify GitHub Actions CI/CD."
echo "No Git commit, push, or AWS resources were changed."
