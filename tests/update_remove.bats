#!/usr/bin/env bats

setup_file() {
    PROJECT_ROOT="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
    export PROJECT_ROOT

    CURRENT_VERSION="$(grep '^VERSION=' "$PROJECT_ROOT/mole" | head -1 | sed 's/VERSION="\(.*\)"/\1/')"
    export CURRENT_VERSION

    ORIGINAL_HOME="${HOME:-}"
    export ORIGINAL_HOME

    HOME="$(mktemp -d "${BATS_TEST_DIRNAME}/tmp-update-home.XXXXXX")"
    export HOME
}

teardown_file() {
    rm -rf "$HOME"
    if [[ -n "${ORIGINAL_HOME:-}" ]]; then
        export HOME="$ORIGINAL_HOME"
    fi
}

setup() {
    export TERM="dumb"
    rm -rf "${HOME:?}"/*
    mkdir -p "$HOME"
}

@test "update_via_homebrew reports already on latest version" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" bash --noprofile --norc << 'EOF'
set -euo pipefail
MOLE_TEST_BREW_UPDATE_OUTPUT="Updated 0 formulae"
MOLE_TEST_BREW_UPGRADE_OUTPUT="Warning: mole 1.7.9 already installed"
MOLE_TEST_BREW_LIST_OUTPUT="mole 1.7.9"
start_inline_spinner() { :; }
stop_inline_spinner() { :; }
brew() {
  case "$1" in
    update) echo "$MOLE_TEST_BREW_UPDATE_OUTPUT";;
    upgrade) echo "$MOLE_TEST_BREW_UPGRADE_OUTPUT";;
    list) if [[ "$2" == "--versions" ]]; then echo "$MOLE_TEST_BREW_LIST_OUTPUT"; fi ;;
  esac
}
export -f brew start_inline_spinner stop_inline_spinner
source "$PROJECT_ROOT/lib/core/common.sh"
update_via_homebrew "1.7.9"
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Already on latest version"* ]]
}

@test "update_mole skips download when already latest" {
    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" PATH="$HOME/fake-bin:/usr/bin:/bin" TERM="dumb" bash --noprofile --norc << 'EOF'
set -euo pipefail
mkdir -p "$HOME/fake-bin"
cat > "$HOME/fake-bin/curl" <<'SCRIPT'
#!/usr/bin/env bash
out=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    -o)
      out="$2"
      shift 2
      ;;
    *)
      shift
      ;;
  esac
done
if [[ -n "$out" ]]; then
  cat <<'INSTALLER' > "$out"
#!/usr/bin/env bash
echo "Installer executed"
INSTALLER
else
  echo "VERSION=\"$CURRENT_VERSION\""
fi
SCRIPT
chmod +x "$HOME/fake-bin/curl"
cat > "$HOME/fake-bin/brew" <<'SCRIPT'
#!/usr/bin/env bash
exit 1
SCRIPT
chmod +x "$HOME/fake-bin/brew"

"$PROJECT_ROOT/mole" update
EOF

    [ "$status" -eq 0 ]
    [[ "$output" == *"Already on latest version"* ]]
}

@test "remove_mole deletes manual binaries and caches" {
    mkdir -p "$HOME/.local/bin"
    touch "$HOME/.local/bin/mole"
    touch "$HOME/.local/bin/mo"
    mkdir -p "$HOME/.config/mole" "$HOME/.cache/mole"

    run env HOME="$HOME" PROJECT_ROOT="$PROJECT_ROOT" PATH="/usr/bin:/bin" bash --noprofile --norc << 'EOF'
set -euo pipefail
start_inline_spinner() { :; }
stop_inline_spinner() { :; }
export -f start_inline_spinner stop_inline_spinner
printf '\n' | "$PROJECT_ROOT/mole" remove
EOF

    [ "$status" -eq 0 ]
    [ ! -f "$HOME/.local/bin/mole" ]
    [ ! -f "$HOME/.local/bin/mo" ]
    [ ! -d "$HOME/.config/mole" ]
    [ ! -d "$HOME/.cache/mole" ]
}
