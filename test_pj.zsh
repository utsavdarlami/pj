#!/usr/bin/env zsh
# Run: zsh test_pj.zsh
fails=0
ok() { [[ "$1" == "$2" ]] && print "ok  $3" || { print "FAIL $3\n  want: $2\n  got:  $1"; fails=1 } }

export HOME=$(mktemp -d ${0:A:h}/.testhome.XXXXXX)  # not /tmp: pj filters /tmp
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

ok "$(_pj_ago 1000 1300)" "5m" "ago: minutes"
ok "$(_pj_ago 1000 $((1000+10800)))" "3h" "ago: hours"
ok "$(_pj_ago 1000 $((1000+2*86400)))" "2d" "ago: days"
ok "$(_pj_ago 1000 $((1000+21*86400)))" "3w" "ago: weeks"
ok "$(_pj_ago 1000 $((1000+120*86400)))" "4mo" "ago: months"

now=$((T+1000000))
mkdir -p "$HOME/proj/b c"
sess $HOME/.claude/projects/-b/1.jsonl "$HOME/proj/b c" $((now-7200))
sess $HOME/.claude/projects/-b/0.jsonl "$HOME/proj/b c" $((now-9*86400))
sess $HOME/.codex/sessions/2026/01/03/r.jsonl "$HOME/proj/b c" $((now-3*86400))
sess $HOME/.claude/projects/-gone/1.jsonl $HOME/gone $now
sess $HOME/.claude/projects/-tmp/1.jsonl /tmp/x $now
print '{"worktree":"/","time":{"updated":1700000000000}}' > $HOME/.local/share/opencode/storage/project/global.json

r=$(_pj_rows $now)
ok "$(print -r -- "$r" | cut -f1)" "$(print -l "$HOME/proj/b c" "$HOME/proj/a")" "rows: newest first, gone + / + /tmp dropped, space kept"
ok "$(print -r -- "$r" | head -1 | cut -f3)" "claude codex" "rows: agents newest first"
[[ "$(print -r -- "$r" | head -1 | cut -f2)" == "b c "*"~/proj "*"claude·2h codex·3d" ]]; ok $? 0 "rows: display name, ~parent, tags"

claude() { print launched-claude }
row="$HOME/proj/a"$'\tx\tclaude'
ok "$( (_pj_act "" ""); print $? )" "1" "act: esc does nothing"
ok "$( (_pj_act ctrl-d "$row"; pwd) )" "$HOME/proj/a" "act: ctrl-d cd only"
ok "$( (_pj_act "" "$row") )" "launched-claude" "act: enter launches last agent"
ok "$( (_pj_act "" "$HOME/proj/a"$'\tx\tnosuchagent' 2>&1; print $?; pwd) )" "pj: nosuchagent not found
1
$HOME/proj/a" "act: missing agent still cds"

exit $fails
