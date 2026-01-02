#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-touchid.XXXXXX")"
    export HOME

    mkdir -p "$HOME"
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

create_fake_utils() {
    local dir="$1"
    mkdir -p "$dir"

    cat > "$dir/sudo" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-n" || "$1" == "-v" ]]; then
    exit 0
fi
exec "$@"
SCRIPT
    chmod +x "$dir/sudo"

    cat > "$dir/bioutil" <<'SCRIPT'
#!/usr/bin/env bash
if [[ "$1" == "-r" ]]; then
    echo "Touch ID: 1"
    exit 0
fi
exit 0
SCRIPT
    chmod +x "$dir/bioutil"
}

@test "touchid status reflects pam file contents" {
    pam_file="$HOME/pam_test"
    cat > "$pam_file" <<'EOF'
auth       sufficient     pam_opendirectory.so
EOF

    run env MOLE_PAM_SUDO_FILE="$pam_file" "$PROJECT_ROOT/bin/touchid.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"not configured"* ]]

    cat > "$pam_file" <<'EOF'
auth       sufficient     pam_tid.so
EOF

    run env MOLE_PAM_SUDO_FILE="$pam_file" "$PROJECT_ROOT/bin/touchid.sh" status
    [ "$status" -eq 0 ]
    [[ "$output" == *"enabled"* ]]
}

@test "enable_touchid inserts pam_tid line in pam file" {
    pam_file="$HOME/pam_enable"
    cat > "$pam_file" <<'EOF'
auth       sufficient     pam_opendirectory.so
EOF

    fake_bin="$HOME/fake-bin"
    create_fake_utils "$fake_bin"

    run env PATH="$fake_bin:$PATH" MOLE_PAM_SUDO_FILE="$pam_file" "$PROJECT_ROOT/bin/touchid.sh" enable
    [ "$status" -eq 0 ]
    grep -q "pam_tid.so" "$pam_file"
    [[ -f "${pam_file}.mole-backup" ]]
}

@test "disable_touchid removes pam_tid line" {
    pam_file="$HOME/pam_disable"
    cat > "$pam_file" <<'EOF'
auth       sufficient     pam_tid.so
auth       sufficient     pam_opendirectory.so
EOF

    fake_bin="$HOME/fake-bin-disable"
    create_fake_utils "$fake_bin"

    run env PATH="$fake_bin:$PATH" MOLE_PAM_SUDO_FILE="$pam_file" "$PROJECT_ROOT/bin/touchid.sh" disable
    [ "$status" -eq 0 ]
    run grep "pam_tid.so" "$pam_file"
    [ "$status" -ne 0 ]
}
