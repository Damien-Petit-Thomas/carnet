#!/usr/bin/env bash
# Installe carnet par liens symboliques (le dépôt reste la source : git pull = mise à jour).
#   ./install.sh               installe dans ~/.local
#   PREFIX=/usr/local ./install.sh
#   ZSH_COMPLETION_DIR=~/.oh-my-zsh/custom/completions ./install.sh
#   ./install.sh --uninstall
set -euo pipefail

ROOT="$(cd -P "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PREFIX="${PREFIX:-$HOME/.local}"
BIN_DIR="$PREFIX/bin"
ZSH_DIR="${ZSH_COMPLETION_DIR:-$PREFIX/share/zsh/site-functions}"

if [[ "${1:-}" == "--uninstall" ]]; then
    rm -f "$BIN_DIR/carnet" "$ZSH_DIR/_carnet"
    echo "✓ carnet removed (notes untouched)"
    exit 0
fi

mkdir -p "$BIN_DIR" "$ZSH_DIR"
ln -sf "$ROOT/bin/carnet" "$BIN_DIR/carnet"
ln -sf "$ROOT/share/zsh/_carnet" "$ZSH_DIR/_carnet"
echo "✓ $BIN_DIR/carnet"
echo "✓ $ZSH_DIR/_carnet"

# ─── dépendances ──────────────────────────────────────────────────────
missing=()
for c in bash git fzf rg perl; do
    command -v "$c" &>/dev/null || missing+=("$c")
done
command -v bat &>/dev/null || command -v batcat &>/dev/null || missing+=("bat")
if ! find --version 2>/dev/null | grep -q GNU && ! command -v gfind &>/dev/null; then
    missing+=("GNU find")
fi
if (( BASH_VERSINFO[0] < 4 )); then
    missing+=("bash>=4 (current: $BASH_VERSION)")
fi

if (( ${#missing[@]} > 0 )); then
    echo
    echo "✗ missing: ${missing[*]}"
    case "$(uname -s)" in
        Darwin) echo "  brew install bash findutils fzf ripgrep bat" ;;
        Linux)  echo "  sudo apt install fzf ripgrep bat      # Debian/Ubuntu"
                echo "  sudo dnf install fzf ripgrep bat      # Fedora" ;;
    esac
fi

# ─── PATH / complétion ────────────────────────────────────────────────
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) echo; echo "→ add to your shell rc:  export PATH=\"$BIN_DIR:\$PATH\"" ;;
esac
if [[ -z "${ZSH_COMPLETION_DIR:-}" ]]; then
    echo "→ zsh completion: add before compinit:  fpath=(\"$ZSH_DIR\" \$fpath)"
fi

echo
echo "Next: carnet help"
