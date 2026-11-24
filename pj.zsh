# pj — jump back into any folder an AI agent ran in.  source this from ~/.zshrc
zmodload zsh/stat zsh/datetime

# _pj_jsonl <agent> <files...>: first "cwd" in each jsonl → path\tagent\tmtime
_pj_jsonl() {
  local agent=$1 l f p m; shift
  (( $# )) || return 0
  grep -m1 -oH '"cwd":"[^"]*"' -- "$@" 2>/dev/null | while IFS= read -r l; do
    f=${l%%:\"cwd\":*} p=${l#*:\"cwd\":\"}
    zstat -A m +mtime -- $f && print -r -- "${p%\"}"$'\t'$agent$'\t'$m
  done
}

# path\tagent\tepoch, one per session (unmerged)
_pj_scan() {
  local f m
  _pj_jsonl claude $HOME/.claude/projects/*/*.jsonl(N)
  _pj_jsonl codex  $HOME/.codex/sessions/**/*.jsonl(N)
  _pj_jsonl pi     $HOME/.pi/agent/sessions/*/*.jsonl(N)
  for f in $HOME/.gemini/tmp/*/.project_root(N); do
    [[ -d ${f:h}/chats ]] && zstat -A m +mtime -- ${f:h}/chats || zstat -A m +mtime -- $f
    print -r -- "$(<$f)"$'\t'gemini$'\t'$m
  done
  f=($HOME/.local/share/opencode/storage/project/*.json(N))
  (( $#f )) && jq -r '[.worktree, "opencode", (.time.updated/1000|floor|tostring)] | @tsv' -- $f 2>/dev/null
  return 0
}

# _pj_ago <epoch> <now> → 5m 3h 2d 3w 4mo
_pj_ago() {
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
  local now=${1:-$EPOCHSECONDS} p list x parent tags names
  _pj_scan | awk -F'\t' '$1 != "/" && $1 !~ "^/(var/)?tmp(/|$)" {
      k = $1 FS $2; if ($3 > m[k]) m[k] = $3 }
    END { for (k in m) print k FS m[k] }' |
  sort -t$'\t' -k3,3nr |
  awk -F'\t' '!($1 in a) { o[++n] = $1 }
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
