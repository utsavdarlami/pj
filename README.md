# pj

Jump back into any project you've used an AI coding agent in.

`pj` reads the session history of **Claude Code, Codex, Gemini CLI, pi and opencode**,
lists every folder they ran in (one row per folder, most recent first), and drops you
there with a fresh agent session.

```
pj>
  combine_context    ~/Desktop/LabUAH        claude·2m pi·4d codex·1w opencode·1mo gemini·3mo
  emacs_config       ~/Desktop               claude·1d pi·3d opencode·9mo
  vial               ~/Downloads             claude·2d opencode·2d
```

## Keys

| Key | Does |
|---|---|
| Enter | `cd` there and start a new session of the agent you used last there |
| ctrl-a | `cd` there and pick which agent to start |
| ctrl-d | just `cd` there |
| Esc | nothing |

## Install

Needs zsh and [fzf](https://github.com/junegunn/fzf). `sqlite3` is optional (for opencode).

```zsh
echo 'source ~/Desktop/Workspace/claude-repo/pj.plugin.zsh' >> ~/.zshrc
```

## How it's built

| File | Does |
|---|---|
| `pj-core` | standalone zsh script: scans sessions, shows the fzf lists, prints `dir<TAB>agent` |
| `pj.plugin.zsh` | the `pj` function: runs `pj-core`, then `cd`s and starts the agent |

The split exists because only a function in your own shell can change its directory.
Everything else runs in `pj-core`'s own process, so your aliases and shell options can't affect it.
`pj-core` must stay next to `pj.plugin.zsh`.

## Where it looks

| Agent | Source |
|---|---|
| claude | `~/.claude/projects/*/*.jsonl` (`cwd`) |
| codex | `~/.codex/sessions/**/*.jsonl` (`cwd`) |
| pi | `~/.pi/agent/sessions/*/*.jsonl` (`cwd`) |
| gemini | `~/.gemini/tmp/*/.project_root` |
| opencode | `~/.local/share/opencode/opencode.db` (`project` table, archived skipped) |

Last-used time is the session file's mtime (opencode: `time_updated`/`time_active`).
Folders under `/tmp`, `/var/tmp`, macOS temp dirs, `/`, and folders that no longer exist are hidden.

## Customize

`PJ_SHOW` (default 7) is how many recent projects are visible at once. Older ones are still
there: type to search, or scroll.

`PJ_AGENTS` sets which agents ctrl-a offers (after the ones already used in that folder):

```zsh
PJ_AGENTS=(claude codex)   # in ~/.zshrc, anywhere
PJ_SHOW=10
```

## Test

```zsh
zsh test_pj.zsh
```

Uses a fake `$HOME`, never touches your real sessions. (Uses GNU `touch -d`, so Linux only.)
