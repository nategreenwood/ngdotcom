---
name: run-personal-site
description: Start, run, stop, smoke-test, or screenshot the personal-site app (Angular client + .NET Functions API behind the Azure Static Web Apps emulator). Use when asked to run the site locally, check the API works, take a screenshot of the site, or run its tests.
---

Start it with `.claude/skills/run-personal-site/driver.sh` (Git Bash). The driver starts three servers, waits until each is ready, and curls the site and the API through the SWA emulator. To look at the page, use the built-in browser pane at `http://localhost:4280`. `chromium-cli` is not installed on this machine.

All paths are relative to the repo root (`G:\Projects\personal-site`). Platform: Windows 11, commands run in Git Bash.

## Prerequisites

These versions were verified to work:

```bash
node --version   # v24.22.2
dotnet --version # 10.0.203
func --version   # 4.15.2
swa --version    # 2.1.0
```

`client/node_modules` must already be installed (`npm install` in `client/`). The API needs no separate build step because `func start` runs `dotnet build`.

## Run (agent path)

```bash
bash .claude/skills/run-personal-site/driver.sh start   # ~11s warm; prints "swa ready -> http://localhost:4280"
bash .claude/skills/run-personal-site/driver.sh smoke   # PASS/FAIL lines, exit code 0 = all pass
bash .claude/skills/run-personal-site/driver.sh status  # 7071/4200/4280 up|down
bash .claude/skills/run-personal-site/driver.sh stop    # kills the process tree on each port
```

| port | what |
|---|---|
| 7071 | `func start` for the .NET isolated Functions host (`api/`) |
| 4200 | `ng serve` for the Angular dev server (`client/`) |
| 4280 | `swa start` for the SWA emulator. **Use this one.** It serves `/` from 4200 and `/api/*` from 7071, the same single-origin setup production uses |

Logs go to `${TMPDIR:-/tmp}/personal-site-run/{func,ng,swa}.log`. You can override the location with `RUN_LOGS=...`.

The servers keep running after `start` returns. Run `stop` when you're done.

**Visual check.** Use the built-in browser pane (`mcp__Claude_Browser__*`):
navigate to `http://localhost:4280`, `find "Hello"` (finds the heading "Hello, ngdotcom" while the starter template is still in place), then take a `screenshot`. For the API, navigate to `http://localhost:4280/api/projects` and use `get_page_text`. It currently returns `Welcome to Azure Functions!`.

## Run (human path)

Run the same three servers yourself in three terminals: `func start --port 7071` in `api/`, `npx ng serve` in `client/`, and `swa start http://localhost:4200 --api-devserver-url http://localhost:7071` in `client/`. Then open http://localhost:4280. Stop each one with Ctrl-C.

## Test

```bash
cd client && npx ng test --watch=false   # Vitest: 1 file, 2 tests pass (~11s)
```

Plain `ng test` starts in watch mode and never exits. The API has no tests yet.

## Gotchas

- **`swa start --api-location ../api` is unusable on Node 24.** SWA CLI 2.1.0 downloads its own Core Tools copy and then exits with `Found Azure Functions Core Tools v4 which is incompatible with your current Node.js v24`. That check is meant for Node-language functions and doesn't apply to this .NET API, but it still blocks the start. The fix is to run `func start` yourself and pass `--api-devserver-url http://localhost:7071`, which is what the driver does.
- **The emulator still starts when `staticwebapp.config.json` is invalid. It runs without the file.** As of this writing, `navigationFallback` is the placeholder `"TODO(human)"` (it must be an object). The emulator prints a schema error and then "emulator started" anyway, so routes, fallback, and headers from the config are **not** applied. The driver prints a `WARNING` when this happens. Deep links such as `/about` still return 200 only because `ng serve` itself falls back to index.html. That proves nothing about SWA's `navigationFallback`.
- **SWA CLI flag names.** `--run-timeout` and `--app-devserver-timeout` don't exist. The real flag is `-t/--devserver-timeout`. Check with `swa start --help` before trusting a flag.
- **ng serve output is ANSI-colored.** `Local:` and `localhost:4200` are split by escape codes, so grepping for them fails. The driver sets `NO_COLOR=1` and waits for `generation complete` instead.
- **"AzureWebJobsStorage Unhealthy" in func.log is harmless.** `local.settings.json` points at `UseDevelopmentStorage=true` and Azurite isn't running. HTTP triggers work anyway. Start Azurite only if you add a non-HTTP trigger.

## Troubleshooting

- **`error: unknown option '--run-timeout'`** (or `--app-devserver-timeout`): use `--devserver-timeout <seconds>`.
- **`✖ Found Azure Functions Core Tools v4 which is incompatible with your current Node.js`**: you used `--api-location`. Use `driver.sh start` instead (see Gotchas).
- **`already running at http://localhost:4280`** from `start`: something is already listening on 4280. Run `driver.sh stop`, then `start` again.
