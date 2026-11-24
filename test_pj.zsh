#!/usr/bin/env zsh
# Run: zsh test_pj.zsh
fails=0
ok() { [[ "$1" == "$2" ]] && print "ok  $3" || { print "FAIL $3\n  want: $2\n  got:  $1"; fails=1 } }

export HOME=$(mktemp -d)
trap 'rm -rf $HOME' EXIT
source ${0:A:h}/pj.zsh

# jsonl session file with a cwd, at given mtime
sess() { mkdir -p ${1:h}; print -r -- "{\"type\":\"x\",\"cwd\":\"$2\"}" > $1; touch -d @$3 $1 }

T=1700000000
mkdir -p $HOME/proj/a
sess $HOME/.claude/projects/-a/1.jsonl $HOME/proj/a $T
sess $HOME/.codex/sessions/2026/01/02/r.jsonl $HOME/proj/a $T
sess $HOME/.pi/agent/sessions/--a--/s.jsonl $HOME/proj/a $T
mkdir -p $HOME/.gemini/tmp/a/chats; print $HOME/proj/a > $HOME/.gemini/tmp/a/.project_root; touch -d @$T $HOME/.gemini/tmp/a/chats
mkdir -p $HOME/.local/share/opencode/storage/project
print "{\"worktree\":\"$HOME/proj/a\",\"time\":{\"updated\":${T}000}}" > $HOME/.local/share/opencode/storage/project/p1.json
mkdir -p $HOME/.claude/projects/x; : > $HOME/.claude/projects/x/empty.jsonl

ok "$(_pj_scan | sort)" "$(print -l \
  "$HOME/proj/a\tclaude\t$T" "$HOME/proj/a\tcodex\t$T" \
  "$HOME/proj/a\tgemini\t$T" "$HOME/proj/a\topencode\t$T" \
  "$HOME/proj/a\tpi\t$T" | sort)" "scan: all five sources, empty file skipped"

exit $fails
