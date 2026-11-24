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
