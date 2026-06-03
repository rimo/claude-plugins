# rimo plugins

The `rimo` plugin marketplace for [Claude Code](https://claude.com/claude-code) — a small catalog of plugins maintained by rimoapp.

## Install

Add the marketplace once:

```
/plugin marketplace add rimoapp/rimo-plugins
```

Then install what you want:

```
/plugin install auto-worktree@rimo   # individual plugin
/plugin install dispatch@rimo         # individual plugin
/plugin install rimo-all@rimo         # everything (bundle)
```

Installing `rimo-all` pulls in every individual plugin automatically via plugin
dependencies. After installing, run `/reload-plugins` to activate.

## Plugins

| Plugin | What it does | Docs |
| :----- | :----------- | :--- |
| **auto-worktree** | Automatically creates git worktrees when Claude modifies files, enabling safe parallel work without git conflicts. | [plugins/auto-worktree](plugins/auto-worktree/README.md) |
| **dispatch** | Launch an interactive Claude Code session in another repository (new Terminal.app / iTerm2 tab) and auto-report its result when it finishes. macOS only. | [plugins/dispatch](plugins/dispatch/skills/dispatch/SKILL.md) |
| **rimo-all** | Convenience bundle — installing it pulls in all of the above. | — |

## Repository layout

```
.claude-plugin/marketplace.json   # the rimo catalog
plugins/
  auto-worktree/                  # plugin: manifest, hooks, lib, tests, docs
  dispatch/                       # plugin: dispatch skill
  rimo-all/                       # bundle: dependencies only
```

## Development

Test a plugin locally without installing:

```
claude --plugin-dir ./plugins/auto-worktree
```

Run a plugin's test suite:

```
bash plugins/auto-worktree/tests/run-tests.sh
```

See [CLAUDE.md](CLAUDE.md) for contribution conventions (English-only, version
bumping, shell-portability rules).

## License

MIT — see [LICENSE](LICENSE).
