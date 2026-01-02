#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-clean-extras.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_cloud_storage calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/user.sh"
stop_section_spinner() { :; }
safe_clean() { echo "$2"; }
clean_cloud_storage
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Dropbox cache"* ]]
    [[ "$output" == *"Google Drive cache"* ]]
}

@test "clean_virtualization_tools hits cache paths" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/user.sh"
stop_section_spinner() { :; }
safe_clean() { echo "$2"; }
clean_virtualization_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"VMware Fusion cache"* ]]
    [[ "$output" == *"Parallels cache"* ]]
}

@test "clean_email_clients calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_email_clients
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spark cache"* ]]
    [[ "$output" == *"Airmail cache"* ]]
}

@test "clean_note_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_note_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Notion cache"* ]]
    [[ "$output" == *"Obsidian cache"* ]]
}

@test "clean_task_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_task_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Todoist cache"* ]]
    [[ "$output" == *"Any.do cache"* ]]
}

@test "scan_external_volumes skips when no volumes" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/user.sh"
run_with_timeout() { return 1; }
scan_external_volumes
EOF

    [ "$status" -eq 0 ]
}
