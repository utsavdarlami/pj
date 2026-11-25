#!/usr/bin/env zsh
# Opens a shell with a fake $HOME full of made-up projects, for screenshots.
# Usage: zsh assets/demo.zsh     (type pj, take the screenshot, then exit)
R=${0:A:h:h}
H=${XDG_CACHE_HOME:-$HOME/.cache}/pj-demo   # not /tmp: pj hides /tmp paths
rm -rf $H; mkdir -p $H
zmodload zsh/datetime; now=$EPOCHSECONDS m=60 h=3600 d=86400

sess() {  # sess <agent> <project dir under ~> <seconds ago>
  local dir=$H/$2 t=$(( now - $3 )) f
  mkdir -p $dir
  case $1 in
    claude) f=$H/.claude/projects/${2:t}/s.jsonl ;;
    codex)  f=$H/.codex/sessions/2026/01/01/${2:t}.jsonl ;;
    pi)     f=$H/.pi/agent/sessions/${2:t}/s.jsonl ;;
    gemini) mkdir -p $H/.gemini/tmp/${2:t}/chats; print $dir > $H/.gemini/tmp/${2:t}/.project_root
            touch -d @$t $H/.gemini/tmp/${2:t}/chats; return ;;
    opencode) mkdir -p $H/.local/share/opencode
            sqlite3 $H/.local/share/opencode/opencode.db "create table if not exists project (id text primary key, worktree text, time_updated integer, time_active integer default 0, time_archived integer); insert into project values('${2:t}','$dir',${t}000,0,null)"; return ;;
  esac
  mkdir -p ${f:h}; print -r -- "{\"cwd\":\"$dir\"}" > $f; touch -d @$t $f
}

sess claude   projects/todo-app      $((2*m))
sess pi      projects/todo-app      $((4*d));  sess codex projects/todo-app $((7*d)); sess opencode projects/todo-app $((31*d))
sess codex    code/rust-cli          $((2*h))
sess claude   work/ml-notebooks      $((6*h));  sess gemini work/ml-notebooks $((3*d))
sess codex    work/api-server        $((1*d));  sess claude work/api-server $((5*d))
sess opencode projects/portfolio     $((3*d));  sess claude projects/portfolio $((10*d))
sess gemini   projects/blog          $((4*d));  sess opencode projects/blog $((14*d))
sess pi       code/game-jam          $((14*d))
sess claude   dotfiles               $((21*d)); sess pi dotfiles $((60*d))
sess claude   work/infra             $((30*d))

print -l "source $R/pj.plugin.zsh" "PROMPT='%F{cyan}%~%f ➜ '" "cd ~" > $H/.zshrc
HOME=$H ZDOTDIR=$H zsh -i
