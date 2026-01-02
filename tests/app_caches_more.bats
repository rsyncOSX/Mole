#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-app-caches-more.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

@test "clean_ai_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_ai_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"ChatGPT cache"* ]]
    [[ "$output" == *"Claude desktop cache"* ]]
}

@test "clean_design_tools calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_design_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Sketch cache"* ]]
    [[ "$output" == *"Figma cache"* ]]
}

@test "clean_dingtalk calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_dingtalk
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"DingTalk iDingTalk cache"* ]]
    [[ "$output" == *"DingTalk logs"* ]]
}

@test "clean_download_managers calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_download_managers
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Aria2 cache"* ]]
    [[ "$output" == *"qBittorrent cache"* ]]
}

@test "clean_productivity_apps calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_productivity_apps
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"MiaoYan cache"* ]]
    [[ "$output" == *"Flomo cache"* ]]
}

@test "clean_screenshot_tools calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/app_caches.sh"
safe_clean() { echo "$2"; }
clean_screenshot_tools
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"CleanShot cache"* ]]
    [[ "$output" == *"Xnip cache"* ]]
}

@test "clean_office_applications calls expected caches" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/clean/user.sh"
stop_section_spinner() { :; }
safe_clean() { echo "$2"; }
clean_office_applications
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Microsoft Word cache"* ]]
    [[ "$output" == *"Apple iWork cache"* ]]
}
