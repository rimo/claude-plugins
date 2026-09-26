# claude-plugins

The `rimo-tools` plugin marketplace for [Claude Code](https://claude.com/claude-code) — a catalog of plugins maintained by rimo.

## Install

Add the marketplace once:

```
/plugin marketplace add rimo/claude-plugins
```

Then install what you want:

```
/plugin install auto-worktree@rimo-tools   # individual plugin
/plugin install dispatch@rimo-tools         # individual plugin
/plugin install rimo@rimo-tools             # individual plugin
/plugin install loop-engineering@rimo-tools # individual plugin
/plugin install rimo-usage@rimo-tools       # individual plugin
/plugin install rimo-all@rimo-tools         # everything (bundle)
```

Installing `rimo-all` pulls in every individual plugin automatically via plugin
dependencies. After installing, run `/reload-plugins` to activate.

## Plugins

| Plugin | What it does | Docs |
| :----- | :----------- | :--- |
| **auto-worktree** | Automatically creates git worktrees when Claude modifies files, enabling safe parallel work without git conflicts. | [plugins/auto-worktree](plugins/auto-worktree/README.md) |
| **dispatch** | Launch an interactive Claude Code session in another repository (new Terminal.app / iTerm2 tab) and auto-report its result when it finishes. macOS only. | [plugins/dispatch](plugins/dispatch/skills/dispatch/SKILL.md) |
| **rimo** | Rimo Voice integration — the rimo-cli skill plus the `rimo mcp` server. Shipped from [rimo/cli](https://github.com/rimo/cli); requires the `rimo` CLI on your PATH. | [rimo/cli](https://github.com/rimo/cli) |
| **loop-engineering** | Scaffold a complete self-running agent loop (discover → isolate → build → verify → persist → schedule) into any repository with `/loop-engineering:init`. Based on Addy Osmani's "Loop Engineering" architecture. | [plugins/loop-engineering](plugins/loop-engineering/README.md) |
| **rimo-usage** | Tracks Claude Code rate-limit usage from the statusline and reports periodic snapshots to Rimo's OTLP collector, while keeping your existing statusline working. | [plugins/rimo-usage](plugins/rimo-usage/README.md) |
| **rimo-all** | Convenience bundle of the dev plugins — pulls in `auto-worktree` + `dispatch` + `rimo-usage`. (The `rimo` product plugin is not bundled; install it directly.) | — |

## Repository layout

```
.claude-plugin/marketplace.json   # the rimo-tools catalog
plugins/
  auto-worktree/                  # plugin: manifest, hooks, lib, tests, docs
  dispatch/                       # plugin: dispatch skill
  loop-engineering/               # plugin: init/status skills + loop templates
  rimo-usage/                     # plugin: rate-limit usage statusline + telemetry hooks
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
