#!/bin/sh
# pj installer. Install or update:
#   curl -fsSL https://raw.githubusercontent.com/utsavdarlami/pj/main/install.sh | sh
set -e
RAW=${PJ_RAW:-https://raw.githubusercontent.com/utsavdarlami/pj/main}
DIR=${PJ_DIR:-$HOME/.local/share/pj}
RC=${ZDOTDIR:-$HOME}/.zshrc

command -v zsh >/dev/null || { echo "pj: zsh is required" >&2; exit 1; }
command -v fzf >/dev/null || echo "pj: warning: fzf not found, install it: https://github.com/junegunn/fzf#installation" >&2
command -v sqlite3 >/dev/null || echo "pj: note: sqlite3 not found, opencode projects will be skipped" >&2

mkdir -p "$DIR"
for f in pj-core pj.plugin.zsh; do curl -fsSL "$RAW/$f" -o "$DIR/$f"; done
chmod +x "$DIR/pj-core"

LINE="source $DIR/pj.plugin.zsh"
grep -qxF "$LINE" "$RC" 2>/dev/null || printf '\n# pj: jump to any AI-agent project\n%s\n' "$LINE" >> "$RC"
echo "pj installed to $DIR. Open a new terminal and run: pj"
