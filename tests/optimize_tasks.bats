#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-optimize.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "opt_system_maintenance reports DNS and Spotlight" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MOLE_DRY_RUN=1 bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
flush_dns_cache() { return 0; }
mdutil() { echo "Indexing enabled."; }
opt_system_maintenance
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"DNS cache flushed"* ]]
    [[ "$output" == *"Spotlight index verified"* ]]
}

@test "opt_network_optimization refreshes DNS" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MOLE_DRY_RUN=1 bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
flush_dns_cache() { return 0; }
opt_network_optimization
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"DNS cache refreshed"* ]]
    [[ "$output" == *"mDNSResponder restarted"* ]]
}

@test "opt_sqlite_vacuum reports sqlite3 unavailable" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
export PATH="/nonexistent"
opt_sqlite_vacuum
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"sqlite3 unavailable"* ]]
}

@test "opt_font_cache_rebuild succeeds in dry-run" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MOLE_DRY_RUN=1 bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
opt_font_cache_rebuild
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Font cache cleared"* ]]
}

@test "opt_dock_refresh clears cache files" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" MOLE_DRY_RUN=1 bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
mkdir -p "$HOME/Library/Application Support/Dock"
touch "$HOME/Library/Application Support/Dock/test.db"
safe_remove() { return 0; }
opt_dock_refresh
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dock cache cleared"* ]]
    [[ "$output" == *"Dock refreshed"* ]]
}

@test "execute_optimization dispatches actions" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
opt_dock_refresh() { echo "dock"; }
execute_optimization dock_refresh
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"dock"* ]]
}

@test "execute_optimization rejects unknown action" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/optimize/tasks.sh"
execute_optimization unknown_action
EOF

    [ "$status" -eq 1 ]
    [[ "$output" == *"Unknown action"* ]]
}
