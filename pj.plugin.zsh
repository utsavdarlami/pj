# pj — jump back into any folder an AI agent ran in. Source this from ~/.zshrc.
# pj-core does the scanning and picking; this function only does what a script can't: cd your shell.
_PJ_CORE=${${(%):-%x}:A:h}/pj-core

pj() {
  emulate -L zsh
  local out agent
  out=$(PJ_SHOW=$PJ_SHOW PJ_AGENTS="$PJ_AGENTS" $_PJ_CORE) || return 1
  cd -- "${out%%$'\t'*}" || return 1
  agent=${out#*$'\t'}
  [[ -n $agent ]] || return 0
  whence $agent >/dev/null || { print -u2 "pj: $agent not found"; return 1 }
  $agent
}
