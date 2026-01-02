#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT
}

@test "is_critical_system_component matches known system services" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/app_protection.sh"
is_critical_system_component "backgroundtaskmanagement" && echo "yes"
is_critical_system_component "SystemSettings" && echo "yes"
EOF
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "yes" ]]
    [[ "${lines[1]}" == "yes" ]]
}

@test "is_critical_system_component ignores non-system names" {
    run bash --noprofile --norc <<'EOF'
set -euo pipefail
source "$PROJECT_ROOT/lib/core/app_protection.sh"
if is_critical_system_component "myapp"; then
  echo "bad"
else
  echo "ok"
fi
EOF
    [ "$status" -eq 0 ]
    [[ "$output" == "ok" ]]
}
