#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-purge-extra.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "is_project_container detects project indicators" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/project.sh"
mkdir -p "$HOME/Workspace2/project"
touch "$HOME/Workspace2/project/package.json"
if is_project_container "$HOME/Workspace2" 2; then
    echo "yes"
fi
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"yes"* ]]
}

@test "discover_project_dirs includes detected containers" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/project.sh"
mkdir -p "$HOME/CustomProjects/app"
touch "$HOME/CustomProjects/app/go.mod"
discover_project_dirs | grep -q "$HOME/CustomProjects"
EOF

    [ "$status" -eq 0 ]
}

@test "save_discovered_paths writes config with tilde" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/project.sh"
save_discovered_paths "$HOME/Projects"
grep -q "^~/" "$HOME/.config/mole/purge_paths"
EOF

    [ "$status" -eq 0 ]
}

@test "scan_purge_targets finds artifacts via find path" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MOLE_PURGE_MIN_DEPTH=1 MOLE_PURGE_MAX_DEPTH=2 bash --noprofile --norc <<'EOF'
set -euo pipefail
PATH="/usr/bin:/bin"
source "$PROJECT_ROOT/lib/clean/project.sh"
mkdir -p "$HOME/dev/app/node_modules"
scan_purge_targets "$HOME/dev" "$HOME/results.txt"
grep -q "node_modules" "$HOME/results.txt"
EOF

    [ "$status" -eq 0 ]
}

@test "select_purge_categories returns failure on empty input" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/project.sh"
if select_purge_categories; then
    exit 1
fi
EOF

    [ "$status" -eq 0 ]
}
