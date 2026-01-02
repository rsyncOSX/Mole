# Mole AI Agent Notes

Use this file as the single source of truth for how to work on Mole.

## Principles

- Safety first: never risk user data or system stability.
- Never run destructive operations that could break the user's machine.
- Do not delete user-important files; cleanup must be conservative and reversible.
- Always use `safe_*` helpers (no raw `rm -rf`).
- Keep changes small and confirm uncertain behavior.
- Follow the local code style in the file you are editing (Bash 3.2 compatible).
- Comments must be English, concise, and intent-focused.
  - Use comments for safety boundaries, non-obvious logic, or flow context.
  - Entry scripts start with ~3 short lines describing purpose/behavior.
- Shell code must use shell-only helpers (no Python).
- Go code must use Go-only helpers (no Python).
- Do not remove installer flags `--prefix`/`--config` (update flow depends on them).
- Do not commit or submit code changes unless explicitly requested.
- You may use `gh` to access GitHub information when needed.

## Architecture

- `mole`: main CLI entrypoint (menu + command routing).
- `mo`: CLI alias wrapper.
- `install.sh`: manual installer/updater (download/build + install).
- `bin/`: command entry points (`clean.sh`, `uninstall.sh`, `optimize.sh`, `purge.sh`, `touchid.sh`,
  `analyze.sh`, `status.sh`).
- `lib/`: shell logic (`core/`, `clean/`, `ui/`).
- `cmd/`: Go apps (`analyze/`, `status/`).
- `scripts/`: build/test helpers.
- `tests/`: BATS integration tests.

## Workflow

- Shell work: add logic under `lib/`, call from `bin/`.
- Go work: edit `cmd/<app>/*.go`.
- Prefer dry-run modes while validating cleanup behavior.

## Build & Test

- `./scripts/test.sh` runs unit/go/integration tests.
- `make build` builds Go binaries for local development.
- `go run ./cmd/analyze` for dev runs without building.

## Key Behaviors

- `mole update` uses `install.sh` with `--prefix`/`--config`; keep these flags.
- Cleanup must go through `safe_*` and respect protection lists.
