#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-apps-module.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_ds_store_tree reports dry-run summary" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" DRY_RUN=true /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/apps.sh"
start_inline_spinner() { :; }
stop_section_spinner() { :; }
note_activity() { :; }
get_file_size() { echo 10; }
bytes_to_human() { echo "0B"; }
files_cleaned=0
total_size_cleaned=0
total_items=0
mkdir -p "$HOME/test_ds"
touch "$HOME/test_ds/.DS_Store"
clean_ds_store_tree "$HOME/test_ds" "DS test"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"DS test"* ]]
}

@test "scan_installed_apps uses cache when fresh" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/apps.sh"
mkdir -p "$HOME/.cache/mole"
echo "com.example.App" > "$HOME/.cache/mole/installed_apps_cache"
get_file_mtime() { date +%s; }
debug_log() { :; }
scan_installed_apps "$HOME/installed.txt"
cat "$HOME/installed.txt"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"com.example.App"* ]]
}

@test "is_bundle_orphaned returns true for old uninstalled bundle" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" ORPHAN_AGE_THRESHOLD=60 bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/apps.sh"
should_protect_data() { return 1; }
get_file_mtime() { echo 0; }
if is_bundle_orphaned "com.example.Old" "$HOME/old" "$HOME/installed.txt"; then
    echo "orphan"
fi
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"orphan"* ]]
}

@test "clean_orphaned_app_data skips when no permission" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/apps.sh"
ls() { return 1; }
stop_section_spinner() { :; }
clean_orphaned_app_data
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Skipped: No permission"* ]]
}
