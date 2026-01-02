#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-clean-extras-more.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_video_tools calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_video_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"ScreenFlow cache"* ]]
    [[ "$output" == *"Final Cut Pro cache"* ]]
}

@test "clean_video_players calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_video_players
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"IINA cache"* ]]
    [[ "$output" == *"VLC cache"* ]]
}

@test "clean_3d_tools calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_3d_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Blender cache"* ]]
    [[ "$output" == *"Cinema 4D cache"* ]]
}

@test "clean_gaming_platforms calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_gaming_platforms
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Steam cache"* ]]
    [[ "$output" == *"Epic Games cache"* ]]
}

@test "clean_translation_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_translation_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Youdao Dictionary cache"* ]]
    [[ "$output" == *"Eudict cache"* ]]
}

@test "clean_launcher_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_launcher_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Alfred cache"* ]]
    [[ "$output" == *"The Unarchiver cache"* ]]
}

@test "clean_remote_desktop calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_remote_desktop
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"TeamViewer cache"* ]]
    [[ "$output" == *"AnyDesk cache"* ]]
}

@test "clean_system_utils calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_system_utils
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Input Source Pro cache"* ]]
    [[ "$output" == *"WakaTime cache"* ]]
}

@test "clean_shell_utils calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_shell_utils
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Zsh completion cache"* ]]
    [[ "$output" == *"wget HSTS cache"* ]]
}
