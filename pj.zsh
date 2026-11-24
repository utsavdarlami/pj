# pj — jump back into any folder an AI agent ran in.  source this from ~/.zshrc
zmodload -F zsh/stat b:zstat
zmodload zsh/datetime
# sandbox dirs to hide (Linux + macOS temp)
_PJ_SKIP='^/(private/)?(var/)?tmp(/|$)|^/(private/)?var/folders/'

# _pj_jsonl <agent> <files...>: first "cwd" in each jsonl → path\tagent\tmtime
_pj_jsonl() {
  emulate -L zsh
  local agent=$1 l f p m; shift
  (( $# )) || return 0
  command grep -m1 -oH '"cwd":"[^"]*"' -- "$@" 2>/dev/null | while IFS= read -r l; do
    f=${l%%:\"cwd\":*} p=${l#*:\"cwd\":\"}
    zstat -A m +mtime -- $f && print -r -- "${p%\"}"$'\t'$agent$'\t'$m
  done
}

# path\tagent\tepoch, one per session (unmerged)
_pj_scan() {
  emulate -L zsh
  local f m
  _pj_jsonl claude $HOME/.claude/projects/*/*.jsonl(N)
  _pj_jsonl codex  $HOME/.codex/sessions/**/*.jsonl(N)
  _pj_jsonl pi     $HOME/.pi/agent/sessions/*/*.jsonl(N)
  for f in $HOME/.gemini/tmp/*/.project_root(N); do
    [[ -d ${f:h}/chats ]] && zstat -A m +mtime -- ${f:h}/chats || zstat -A m +mtime -- $f
    print -r -- "$(<$f)"$'\t'gemini$'\t'$m
  done
  f=$HOME/.local/share/opencode/opencode.db
  [[ -f $f ]] && (( $+commands[sqlite3] )) && command sqlite3 -readonly -separator $'\t' $f \
    "select worktree, 'opencode', max(time_updated, time_active) / 1000 from project where time_archived is null" 2>/dev/null
  return 0
}

# _pj_ago <epoch> <now> → 5m 3h 2d 3w 4mo
_pj_ago() {
  emulate -L zsh
  local d=$(( $2 - $1 ))
  if   (( d < 3600 ));    then print $(( d / 60 ))m
  elif (( d < 86400 ));   then print $(( d / 3600 ))h
  elif (( d < 7*86400 )); then print $(( d / 86400 ))d
  elif (( d < 30*86400 ));then print $(( d / 604800 ))w
  else                         print $(( d / 2592000 ))mo
  fi
}

# _pj_rows [now] → path\tdisplay\tagents (newest folder first, agents newest first)
_pj_rows() {
  emulate -L zsh
  local now=${1:-$EPOCHSECONDS} p list x parent tags names
  _pj_scan | command awk -F'\t' -v skip="$_PJ_SKIP" '$1 != "/" && $1 !~ skip {
      k = $1 FS $2; if ($3 > m[k]) m[k] = $3 }
    END { for (k in m) print k FS m[k] }' |
  command sort -t$'\t' -k3,3nr |
  command awk -F'\t' '!($1 in a) { o[++n] = $1 }
    { a[$1] = a[$1] (a[$1] == "" ? "" : " ") $2 ":" $3 }
    END { for (i = 1; i <= n; i++) print o[i] FS a[o[i]] }' |
  while IFS=$'\t' read -r p list; do
    [[ -d $p ]] || continue
    tags=() names=()
    for x in ${(s: :)list}; do
      names+=${x%%:*}; tags+="${x%%:*}·$(_pj_ago ${x#*:} $now)"
    done
    parent=${p:h}; parent=${parent/#$HOME/\~}
    printf '%s\t%-28s %-30s %s\t%s\n' "$p" "${p:t}" "$parent" "$tags" "$names"
  done
}

PJ_AGENTS=(claude codex gemini pi opencode)
PJ_SHOW=7   # rows visible at once; older projects are still found by typing

# _pj_fzf <extra lines> [fzf opts]: fzf sized to stdin so there's no blank gap
# height = min(items, PJ_SHOW) + prompt + info + extra (header). fzf 0.32 lacks --height=~N; fzf caps at terminal.
_pj_fzf() {
  emulate -L zsh
  local extra=$1; shift
  local -a items=("${(@f)$(command cat)}")
  local n=$(( $#items < PJ_SHOW ? $#items : PJ_SHOW ))
  print -l -- $items | command fzf --height=$(( n + 2 + extra )) --no-multi "$@"
}

# _pj_pick_agent [fzf opts]: choose an agent from stdin
_pj_pick_agent() { _pj_fzf 0 --prompt='agent> ' "$@" }

# _pj_act <fzf key> <row>: cd into row's folder, then start a fresh agent session
_pj_act() {
  emulate -L zsh
  local key=$1 row=$2 agent a; local -a used rest
  [[ -n $row ]] || return 1
  cd -- ${row%%$'\t'*} || return 1
  [[ $key == ctrl-d ]] && return 0
  used=(${(s: :)${row##*$'\t'}})
  if [[ $key == ctrl-a ]]; then
    for a in ${PJ_AGENTS:|used}; do whence -p $a >/dev/null && rest+=$a; done
    agent=$(print -l $used $rest | _pj_pick_agent)
    case $? in 0) ;; 130) return 0 ;; *) print -u2 "pj: fzf failed"; return 1 ;; esac
  else
    agent=$used[1]
  fi
  whence $agent >/dev/null || { print -u2 "pj: $agent not found"; return 1 }
  $agent
}

pj() {
  emulate -L zsh
  local out
  out=$(_pj_rows | _pj_fzf 1 --delimiter=$'\t' --with-nth=2 --expect=ctrl-a,ctrl-d --no-sort \
    --prompt='pj> ' --header='enter: new session · ctrl-a: pick agent · ctrl-d: cd only') || return 1
  _pj_act "${out%%$'\n'*}" "${out#*$'\n'}"
}
