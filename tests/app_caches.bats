#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-app-caches.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_xcode_tools skips derived data when Xcode running" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
pgrep() { return 0; }
safe_clean() { echo "$2"; }
clean_xcode_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Xcode is running"* ]]
    [[ "$output" != *"derived data"* ]]
    [[ "$output" != *"archives"* ]]
}

@test "clean_media_players protects spotify offline cache" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
mkdir -p "$HOME/Library/Application Support/Spotify/PersistentCache/Storage"
touch "$HOME/Library/Application Support/Spotify/PersistentCache/Storage/offline.bnk"
safe_clean() { echo "CLEAN:$2"; }
clean_media_players
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Spotify cache protected"* ]]
    [[ "$output" != *"CLEAN: Spotify cache"* ]]
}

@test "clean_user_gui_applications calls all sections" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" /bin/bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/common.sh"
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
stop_section_spinner() { :; }
safe_clean() { :; }
clean_xcode_tools() { echo "xcode"; }
clean_code_editors() { echo "editors"; }
clean_communication_apps() { echo "comm"; }
clean_user_gui_applications
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"xcode"* ]]
    [[ "$output" == *"editors"* ]]
    [[ "$output" == *"comm"* ]]
}
