#!/usr/bin/env bash
# Driver for personal-site (Angular client + .NET isolated Functions API behind the SWA emulator).
#
#   bash .claude/skills/run-personal-site/driver.sh start    # launch func :7071, ng serve :4200, swa :4280; wait until ready
#   bash .claude/skills/run-personal-site/driver.sh smoke    # curl the site + API through the emulator; non-zero exit on failure
#   bash .claude/skills/run-personal-site/driver.sh status   # which ports are listening
#   bash .claude/skills/run-personal-site/driver.sh stop     # kill whatever is listening on 4280/4200/7071 (process trees)
#
# Logs: $RUN_LOGS (default ${TMPDIR:-/tmp}/personal-site-run) -> func.log, ng.log, swa.log
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
LOGS="${RUN_LOGS:-${TMPDIR:-/tmp}/personal-site-run}"
SWA=http://localhost:4280
mkdir -p "$LOGS"

listening() { curl -s -o /dev/null --max-time 2 "http://localhost:$1/"; }

# wait_for <file> <ready-regex> <fail-regex> <timeout-seconds>
wait_for() {
  local f=$1 ready=$2 fail=$3 t=$4 i=0
  while [ $i -lt $((t * 2)) ]; do
    if grep -qE "$ready" "$f" 2>/dev/null; then return 0; fi
    if grep -qE "$fail" "$f" 2>/dev/null; then echo "FAILED: $f"; tail -25 "$f"; return 1; fi
    sleep 0.5; i=$((i + 1))
  done
  echo "TIMEOUT after ${t}s waiting for /$ready/ in $f"; tail -25 "$f"; return 1
}

start() {
  if listening 4280; then echo "already running at $SWA (run 'stop' first to restart)"; return 0; fi

  # 1. Functions host. Started by hand: 'swa start --api-location' refuses under Node 24 (see SKILL.md Gotchas).
  (cd "$ROOT/api" && nohup func start --port 7071 > "$LOGS/func.log" 2>&1 &)
  # 2. Angular dev server.
  (cd "$ROOT/client" && NO_COLOR=1 nohup npx ng serve --port 4200 > "$LOGS/ng.log" 2>&1 &)

  wait_for "$LOGS/func.log" '^Functions:' 'Build FAILED|error CS[0-9]+|is unavailable|Port .* in use' 240 || return 1
  echo "func ready  -> http://localhost:7071/api/projects"
  wait_for "$LOGS/ng.log" 'generation complete' 'Application bundle generation failed|ERROR|already in use' 180 || return 1
  echo "ng ready    -> http://localhost:4200"

  # 3. SWA emulator in front of both, so / and /api share one origin like production.
  (cd "$ROOT/client" && nohup swa start http://localhost:4200 --api-devserver-url http://localhost:7071 > "$LOGS/swa.log" 2>&1 &)
  wait_for "$LOGS/swa.log" 'emulator started' 'unknown option|Cannot|EADDRINUSE' 90 || return 1
  echo "swa ready   -> $SWA"

  if grep -q 'Please fix the above error' "$LOGS/swa.log"; then
    echo "WARNING: emulator rejected client/staticwebapp.config.json and is running WITHOUT it:"
    grep -E '"value"|"expected"|"received"' "$LOGS/swa.log" | sed 's/^/  /'
  fi
}

smoke() {
  local rc=0 code body
  code=$(curl -s -o "$LOGS/index.html" -w '%{http_code}' "$SWA/")
  if [ "$code" = 200 ] && grep -q '<app-root' "$LOGS/index.html"; then echo "PASS  GET /              200, has <app-root>"
  else echo "FAIL  GET /              $code"; rc=1; fi

  body=$(curl -s -w '\n%{http_code}' "$SWA/api/projects"); code=${body##*$'\n'}; body=${body%$'\n'*}
  if [ "$code" = 200 ]; then echo "PASS  GET /api/projects  200, body: $body"
  else echo "FAIL  GET /api/projects  $code, body: $body"; rc=1; fi
  return $rc
}

status() {
  for p in 7071 4200 4280; do
    if listening $p; then echo "$p up"; else echo "$p down"; fi
  done
}

stop() {
  powershell.exe -NoProfile -Command '
    $pids = Get-NetTCPConnection -State Listen -LocalPort 4280,4200,7071 -ErrorAction SilentlyContinue |
            Select-Object -ExpandProperty OwningProcess -Unique
    foreach ($p in $pids) { taskkill /PID $p /T /F | Out-Null; "killed tree of PID $p" }
    if (-not $pids) { "nothing listening on 4280/4200/7071" }'
}

case "${1:-}" in
  start|smoke|status|stop) "$1" ;;
  *) echo "usage: $0 start|smoke|status|stop"; exit 2 ;;
esac
