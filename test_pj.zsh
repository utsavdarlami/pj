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
# opencode db: proj/a (time_active newer than time_updated), plus an archived project
OC=$HOME/.local/share/opencode/opencode.db; mkdir -p ${OC:h}; mkdir -p $HOME/proj/archived
oc() { sqlite3 $OC "insert into project values('$1','$2',$3,$4,$5)" }
sqlite3 $OC 'create table project (id text primary key, worktree text not null, time_updated integer not null, time_active integer default 0 not null, time_archived integer)'
oc p1 $HOME/proj/a $(( (T-50)*1000 )) ${T}123 null
oc p2 $HOME/proj/archived ${T}000 0 ${T}000
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
oc g / ${T}000 0 null

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

# --- review fixes
ok "$(print -l claude codex | _pj_pick_agent --filter=codex)" "codex" "pick: installed fzf accepts picker options"
ok "$( (_pj_pick_agent() { return 2 }; _pj_act ctrl-a "$row" 2>/dev/null); print $? )" "1" "act: real fzf error is not treated as esc"
ok "$( (_pj_pick_agent() { return 130 }; _pj_act ctrl-a "$row"; print $?; pwd) )" "0
$HOME/proj/a" "act: esc in agent picker stays in folder"
ok "$(whence -w stat)" "stat: command" "source: does not shadow the stat command"
ok "$(zsh -fc "alias grep='grep --color=always'; source ${0:A:h}/pj.zsh; _pj_scan" | sort)" "$(_pj_scan | sort)" "scan: survives a grep alias"
ok "$( (setopt sh_word_split; _pj_act ctrl-d "$HOME/proj/b c"$'\tx\tclaude'; pwd) )" "$HOME/proj/b c" "act: sh_word_split doesn't split paths"
ok "$( (setopt ksh_arrays; _pj_act "" "$row") )" "launched-claude" "act: ksh_arrays doesn't break agent pick"
for p in /private/tmp/x /private/var/folders/ab/cd/T/x /tmp/x /var/tmp; do
  [[ $p =~ $_PJ_SKIP ]]; ok $? 0 "skip: $p"
done
[[ $HOME/proj/a =~ $_PJ_SKIP ]]; ok $? 1 "skip: real project kept"

# picker height = agents + prompt + info line (no blank gap); fake fzf echoes its --height
mkdir -p $HOME/bin; print -l '#!/bin/sh' 'for a; do case $a in --height=*) echo "$a";; esac; done' > $HOME/bin/fzf; chmod +x $HOME/bin/fzf
ok "$(print -l claude codex pi | PATH=$HOME/bin:$PATH _pj_pick_agent)" "--height=5" "pick: height fits the agent list"

ok "$(print -l a b c | PATH=$HOME/bin:$PATH _pj_fzf 1)" "--height=6" "fzf: height fits list + header line"

ok "$(print -l {1..20} | PATH=$HOME/bin:$PATH _pj_fzf 1)" "--height=10" "fzf: only PJ_SHOW=7 rows visible, rest searchable"

exit $fails
