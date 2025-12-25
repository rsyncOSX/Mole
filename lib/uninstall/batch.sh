#!/bin/bash

set -euo pipefail

# Ensure common.sh is loaded
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
[[ -z "${MOLE_COMMON_LOADED:-}" ]] && source "$SCRIPT_DIR/lib/core/common.sh"

# Batch uninstall functionality with minimal confirmations
# Replaces the overly verbose individual confirmation approach

# ============================================================================
# Configuration: User Data Detection Patterns
# ============================================================================
# Directories that typically contain user-customized configurations, themes,
# or personal data that users might want to backup before uninstalling
readonly SENSITIVE_DATA_PATTERNS=(
    "\.warp"                                    # Warp terminal configs/themes
    "/\.config/"                                # Standard Unix config directory
    "/themes/"                                  # Theme customizations
    "/settings/"                                # Settings directories
    "/Application Support/[^/]+/User Data"      # Chrome/Electron user data
    "/Preferences/[^/]+\.plist"                 # User preference files
    "/Documents/"                               # User documents
    "/\.ssh/"                                   # SSH keys and configs (critical)
    "/\.gnupg/"                                 # GPG keys (critical)
)

# Join patterns into a single regex for grep
SENSITIVE_DATA_REGEX=$(IFS='|'; echo "${SENSITIVE_DATA_PATTERNS[*]}")

# Decode and validate base64 encoded file list
# Returns decoded string if valid, empty string otherwise
decode_file_list() {
    local encoded="$1"
    local app_name="$2"
    local decoded

    # Decode base64 data (macOS uses -D, GNU uses -d)
    # Try macOS format first, then GNU format for compatibility
    # IMPORTANT: Always return 0 to prevent set -e from terminating the script
    if ! decoded=$(printf '%s' "$encoded" | base64 -D 2> /dev/null); then
        # Fallback to GNU base64 format
        if ! decoded=$(printf '%s' "$encoded" | base64 -d 2> /dev/null); then
            log_error "Failed to decode file list for $app_name" >&2
            echo ""
            return 0  # Return success with empty string
        fi
    fi

    # Validate decoded data doesn't contain null bytes
    if [[ "$decoded" =~ $'\0' ]]; then
        log_warning "File list for $app_name contains null bytes, rejecting" >&2
        echo ""
        return 0  # Return success with empty string
    fi

    # Validate paths look reasonable (each line should be a path or empty)
    while IFS= read -r line; do
        if [[ -n "$line" && ! "$line" =~ ^/ ]]; then
            log_warning "Invalid path in file list for $app_name: $line" >&2
            echo ""
            return 0  # Return success with empty string
        fi
    done <<< "$decoded"

    echo "$decoded"
    return 0
}
# Note: find_app_files() and calculate_total_size() functions now in lib/core/common.sh

# Stop Launch Agents and Daemons for an app
# Args: $1 = bundle_id, $2 = has_system_files (true/false)
stop_launch_services() {
    local bundle_id="$1"
    local has_system_files="${2:-false}"

    [[ -z "$bundle_id" || "$bundle_id" == "unknown" ]] && return 0

    # User-level Launch Agents
    if [[ -d ~/Library/LaunchAgents ]]; then
        while IFS= read -r -d '' plist; do
            launchctl unload "$plist" 2> /dev/null || true
        done < <(find ~/Library/LaunchAgents -maxdepth 1 -name "${bundle_id}*.plist" -print0 2> /dev/null)
    fi

    # System-level services (requires sudo)
    if [[ "$has_system_files" == "true" ]]; then
        if [[ -d /Library/LaunchAgents ]]; then
            while IFS= read -r -d '' plist; do
                sudo launchctl unload "$plist" 2> /dev/null || true
            done < <(find /Library/LaunchAgents -maxdepth 1 -name "${bundle_id}*.plist" -print0 2> /dev/null)
        fi
        if [[ -d /Library/LaunchDaemons ]]; then
            while IFS= read -r -d '' plist; do
                sudo launchctl unload "$plist" 2> /dev/null || true
            done < <(find /Library/LaunchDaemons -maxdepth 1 -name "${bundle_id}*.plist" -print0 2> /dev/null)
        fi
    fi
}

# Remove a list of files (handles both regular files and symlinks)
# Args: $1 = file_list (newline-separated), $2 = use_sudo (true/false)
# Returns: number of files removed
remove_file_list() {
    local file_list="$1"
    local use_sudo="${2:-false}"
    local count=0

    while IFS= read -r file; do
        [[ -n "$file" && -e "$file" ]] || continue

        if [[ -L "$file" ]]; then
            # Symlink: use direct rm
            if [[ "$use_sudo" == "true" ]]; then
                sudo rm "$file" 2> /dev/null && ((count++)) || true
            else
                rm "$file" 2> /dev/null && ((count++)) || true
            fi
        else
            # Regular file/directory: use safe_remove
            if [[ "$use_sudo" == "true" ]]; then
                safe_sudo_remove "$file" && ((count++)) || true
            else
                safe_remove "$file" true && ((count++)) || true
            fi
        fi
    done <<< "$file_list"

    echo "$count"
}

# Batch uninstall with single confirmation
# Globals: selected_apps (read) - array of selected applications
batch_uninstall_applications() {
    local total_size_freed=0

    # shellcheck disable=SC2154
    if [[ ${#selected_apps[@]} -eq 0 ]]; then
        log_warning "No applications selected for uninstallation"
        return 0
    fi

    # Pre-process: Check for running apps and calculate total impact
    local -a running_apps=()
    local -a sudo_apps=()
    local total_estimated_size=0
    local -a app_details=()

    # Analyze selected apps with progress indicator
    if [[ -t 1 ]]; then start_inline_spinner "Scanning files..."; fi
    for selected_app in "${selected_apps[@]}"; do
        [[ -z "$selected_app" ]] && continue
        IFS='|' read -r _ app_path app_name bundle_id _ _ <<< "$selected_app"

        # Check if app is running using executable name from bundle
        local exec_name=""
        if [[ -e "$app_path/Contents/Info.plist" ]]; then
            exec_name=$(defaults read "$app_path/Contents/Info.plist" CFBundleExecutable 2> /dev/null || echo "")
        fi
        local check_pattern="${exec_name:-$app_name}"
        if pgrep -x "$check_pattern" > /dev/null 2>&1; then
            running_apps+=("$app_name")
        fi

        # Check if app requires sudo to delete (either app bundle or system files)
        # Need sudo if:
        # 1. Parent directory is not writable (may be owned by another user or root)
        # 2. App owner is root
        # 3. App owner is different from current user
        local needs_sudo=false
        local app_owner=$(get_file_owner "$app_path")
        local current_user=$(whoami)
        if [[ ! -w "$(dirname "$app_path")" ]] || \
           [[ "$app_owner" == "root" ]] || \
           [[ -n "$app_owner" && "$app_owner" != "$current_user" ]]; then
            needs_sudo=true
        fi

        # Calculate size for summary (including system files)
        local app_size_kb=$(get_path_size_kb "$app_path")
        local related_files=$(find_app_files "$bundle_id" "$app_name")
        local related_size_kb=$(calculate_total_size "$related_files")
        # system_files is a newline-separated string, not an array
        # shellcheck disable=SC2178,SC2128
        local system_files=$(find_app_system_files "$bundle_id" "$app_name")
        # shellcheck disable=SC2128
        local system_size_kb=$(calculate_total_size "$system_files")
        local total_kb=$((app_size_kb + related_size_kb + system_size_kb))
        ((total_estimated_size += total_kb))

        # Check if system files require sudo
        # shellcheck disable=SC2128
        if [[ -n "$system_files" ]]; then
            needs_sudo=true
        fi

        if [[ "$needs_sudo" == "true" ]]; then
            sudo_apps+=("$app_name")
        fi

        # Check for sensitive user data (performance optimization: do this once)
        local has_sensitive_data="false"
        if [[ -n "$related_files" ]] && echo "$related_files" | grep -qE "$SENSITIVE_DATA_REGEX"; then
            has_sensitive_data="true"
        fi

        # Store details for later use
        # Base64 encode file lists to handle multi-line data safely (single line)
        local encoded_files
        encoded_files=$(printf '%s' "$related_files" | base64 | tr -d '\n')
        local encoded_system_files
        encoded_system_files=$(printf '%s' "$system_files" | base64 | tr -d '\n')
        # Store needs_sudo to avoid recalculating during deletion phase
        app_details+=("$app_name|$app_path|$bundle_id|$total_kb|$encoded_files|$encoded_system_files|$has_sensitive_data|$needs_sudo")
    done
    if [[ -t 1 ]]; then stop_inline_spinner; fi

    # Format size display (convert KB to bytes for bytes_to_human())
    local size_display=$(bytes_to_human "$((total_estimated_size * 1024))")

    # Display detailed file list for each app before confirmation
    echo ""
    echo -e "${PURPLE_BOLD}Files to be removed:${NC}"
    echo ""

    # Check for apps with user data that might need backup
    # Performance optimization: use pre-calculated flags from app_details
    local has_user_data=false
    for detail in "${app_details[@]}"; do
        IFS='|' read -r _ _ _ _ _ _ has_sensitive_data <<< "$detail"
        if [[ "$has_sensitive_data" == "true" ]]; then
            has_user_data=true
            break
        fi
    done

    if [[ "$has_user_data" == "true" ]]; then
        echo -e "${YELLOW}${ICON_WARNING}${NC} ${YELLOW}Note: Some apps contain user configurations/themes${NC}"
        echo ""
    fi

    for detail in "${app_details[@]}"; do
        IFS='|' read -r app_name app_path bundle_id total_kb encoded_files encoded_system_files has_sensitive_data needs_sudo_flag <<< "$detail"
        local related_files=$(decode_file_list "$encoded_files" "$app_name")
        local system_files=$(decode_file_list "$encoded_system_files" "$app_name")
        local app_size_display=$(bytes_to_human "$((total_kb * 1024))")

        echo -e "${BLUE}${ICON_CONFIRM}${NC} ${app_name} ${GRAY}(${app_size_display})${NC}"
        echo -e "  ${GREEN}${ICON_SUCCESS}${NC} ${app_path/$HOME/~}"

        # Show related files (limit to 5 most important ones for brevity)
        local file_count=0
        local max_files=5
        while IFS= read -r file; do
            if [[ -n "$file" && -e "$file" ]]; then
                if [[ $file_count -lt $max_files ]]; then
                    echo -e "  ${GREEN}${ICON_SUCCESS}${NC} ${file/$HOME/~}"
                fi
                ((file_count++))
            fi
        done <<< "$related_files"

        # Show system files
        local sys_file_count=0
        while IFS= read -r file; do
            if [[ -n "$file" && -e "$file" ]]; then
                if [[ $sys_file_count -lt $max_files ]]; then
                    echo -e "  ${BLUE}${ICON_SOLID}${NC} System: $file"
                fi
                ((sys_file_count++))
            fi
        done <<< "$system_files"

        # Show count of remaining files if truncated
        local total_hidden=$((file_count > max_files ? file_count - max_files : 0))
        ((total_hidden += sys_file_count > max_files ? sys_file_count - max_files : 0))
        if [[ $total_hidden -gt 0 ]]; then
            echo -e "  ${GRAY}  ... and ${total_hidden} more files${NC}"
        fi
    done

    # Show summary and get batch confirmation first (before asking for password)
    local app_total=${#selected_apps[@]}
    local app_text="app"
    [[ $app_total -gt 1 ]] && app_text="apps"

    echo ""
    local removal_note="Remove ${app_total} ${app_text}"
    [[ -n "$size_display" ]] && removal_note+=" (${size_display})"
    if [[ ${#running_apps[@]} -gt 0 ]]; then
        removal_note+=" ${YELLOW}[Running]${NC}"
    fi
    echo -ne "${PURPLE}${ICON_ARROW}${NC} ${removal_note}  ${GREEN}Enter${NC} confirm, ${GRAY}ESC${NC} cancel: "

    drain_pending_input # Clean up any pending input before confirmation
    IFS= read -r -s -n1 key || key=""
    drain_pending_input # Clean up any escape sequence remnants
    case "$key" in
        $'\e' | q | Q)
            echo ""
            echo ""
            return 0
            ;;
        "" | $'\n' | $'\r' | y | Y)
            printf "\r\033[K" # Clear the prompt line
            ;;
        *)
            echo ""
            echo ""
            return 0
            ;;
    esac

    # User confirmed, now request sudo access if needed
    if [[ ${#sudo_apps[@]} -gt 0 ]]; then
        # Check if sudo is already cached
        if ! sudo -n true 2> /dev/null; then
            if ! request_sudo_access "Admin required for system apps: ${sudo_apps[*]}"; then
                echo ""
                log_error "Admin access denied"
                return 1
            fi
        fi
        # Start sudo keepalive with robust parent checking
        parent_pid=$$
        (while true; do
            # Check if parent process still exists first
            if ! kill -0 "$parent_pid" 2> /dev/null; then
                exit 0
            fi
            sudo -n true
            sleep 60
        done 2> /dev/null) &
        sudo_keepalive_pid=$!
    fi

    if [[ -t 1 ]]; then start_inline_spinner "Uninstalling apps..."; fi

    # Force quit running apps first (batch)
    # Note: Apps are already killed in the individual uninstall loop below with app_path for precise matching

    # Perform uninstallations (silent mode, show results at end)
    if [[ -t 1 ]]; then stop_inline_spinner; fi
    local success_count=0 failed_count=0
    local -a failed_items=()
    local -a success_items=()
    for detail in "${app_details[@]}"; do
        IFS='|' read -r app_name app_path bundle_id total_kb encoded_files encoded_system_files has_sensitive_data needs_sudo <<< "$detail"
        local related_files=$(decode_file_list "$encoded_files" "$app_name")
        local system_files=$(decode_file_list "$encoded_system_files" "$app_name")
        local reason=""

        # Note: needs_sudo is already calculated during scanning phase (performance optimization)

        # Stop Launch Agents and Daemons before removal
        local has_system_files="false"
        [[ -n "$system_files" ]] && has_system_files="true"
        stop_launch_services "$bundle_id" "$has_system_files"

        # Force quit app if still running
        if ! force_kill_app "$app_name" "$app_path"; then
            reason="still running"
        fi

        # Remove the application only if not running
        if [[ -z "$reason" ]]; then
            if [[ "$needs_sudo" == true ]]; then
                if ! safe_sudo_remove "$app_path"; then
                    # Determine specific failure reason (only fetch owner info when needed)
                    local app_owner=$(get_file_owner "$app_path")
                    local current_user=$(whoami)
                    if [[ -n "$app_owner" && "$app_owner" != "$current_user" && "$app_owner" != "root" ]]; then
                        reason="owned by $app_owner"
                    else
                        reason="permission denied"
                    fi
                fi
            else
                safe_remove "$app_path" true || reason="remove failed"
            fi
        fi

        # Remove related files if app removal succeeded
        if [[ -z "$reason" ]]; then
            # Remove user-level files
            remove_file_list "$related_files" "false" > /dev/null
            # Remove system-level files (requires sudo)
            remove_file_list "$system_files" "true" > /dev/null

            # Clean up macOS defaults (preference domain)
            # This removes configuration data stored in the macOS defaults system
            # Note: This complements plist file deletion by clearing cached preferences
            if [[ -n "$bundle_id" && "$bundle_id" != "unknown" ]]; then
                # 1. Standard defaults domain cleanup
                if defaults read "$bundle_id" &> /dev/null; then
                    defaults delete "$bundle_id" 2> /dev/null || true
                fi

                # 2. Clean up ByHost preferences (machine-specific configs)
                # These are often missed by standard cleanup tools
                # Format: ~/Library/Preferences/ByHost/com.app.id.XXXX.plist
                if [[ -d ~/Library/Preferences/ByHost ]]; then
                    find ~/Library/Preferences/ByHost -maxdepth 1 -name "${bundle_id}.*.plist" -delete 2>/dev/null || true
                fi
            fi

            ((total_size_freed += total_kb))
            ((success_count++))
            ((files_cleaned++))
            ((total_items++))
            success_items+=("$app_name")
        else
            ((failed_count++))
            failed_items+=("$app_name:$reason")
        fi
    done

    # Summary
    local freed_display
    freed_display=$(bytes_to_human "$((total_size_freed * 1024))")

    local summary_status="success"
    local -a summary_details=()

    if [[ $success_count -gt 0 ]]; then
        local success_list="${success_items[*]}"
        local success_text="app"
        [[ $success_count -gt 1 ]] && success_text="apps"
        local success_line="Removed ${success_count} ${success_text}"
        if [[ -n "$freed_display" ]]; then
            success_line+=", freed ${GREEN}${freed_display}${NC}"
        fi

        # Format app list with max 3 per line
        if [[ -n "$success_list" ]]; then
            local idx=0
            local is_first_line=true
            local current_line=""

            for app_name in "${success_items[@]}"; do
                local display_item="${GREEN}${app_name}${NC}"

                if ((idx % 3 == 0)); then
                    # Start new line
                    if [[ -n "$current_line" ]]; then
                        summary_details+=("$current_line")
                    fi
                    if [[ "$is_first_line" == true ]]; then
                        # First line: append to success_line
                        current_line="${success_line}: $display_item"
                        is_first_line=false
                    else
                        # Subsequent lines: just the apps
                        current_line="$display_item"
                    fi
                else
                    # Add to current line
                    current_line="$current_line, $display_item"
                fi
                ((idx++))
            done
            # Add the last line
            if [[ -n "$current_line" ]]; then
                summary_details+=("$current_line")
            fi
        else
            summary_details+=("$success_line")
        fi
    fi

    if [[ $failed_count -gt 0 ]]; then
        summary_status="warn"

        local failed_names=()
        for item in "${failed_items[@]}"; do
            local name=${item%%:*}
            failed_names+=("$name")
        done
        local failed_list="${failed_names[*]}"

        local reason_summary="could not be removed"
        if [[ $failed_count -eq 1 ]]; then
            local first_reason=${failed_items[0]#*:}
            case "$first_reason" in
                still*running*) reason_summary="is still running" ;;
                remove*failed*) reason_summary="could not be removed" ;;
                permission*denied*) reason_summary="permission denied" ;;
                owned*by*) reason_summary="$first_reason (try with sudo)" ;;
                *) reason_summary="$first_reason" ;;
            esac
        fi
        summary_details+=("Failed: ${RED}${failed_list}${NC} ${reason_summary}")
    fi

    if [[ $success_count -eq 0 && $failed_count -eq 0 ]]; then
        summary_status="info"
        summary_details+=("No applications were uninstalled.")
    fi

    local title="Uninstall complete"
    if [[ "$summary_status" == "warn" ]]; then
        title="Uninstall incomplete"
    fi

    print_summary_block "$title" "${summary_details[@]}"
    printf '\n'

    # Clean up Dock entries for uninstalled apps
    if [[ $success_count -gt 0 ]]; then
        local -a removed_paths=()
        for detail in "${app_details[@]}"; do
            IFS='|' read -r app_name app_path _ _ _ _ <<< "$detail"
            # Check if this app was successfully removed
            for success_name in "${success_items[@]}"; do
                if [[ "$success_name" == "$app_name" ]]; then
                    removed_paths+=("$app_path")
                    break
                fi
            done
        done
        if [[ ${#removed_paths[@]} -gt 0 ]]; then
            remove_apps_from_dock "${removed_paths[@]}" 2> /dev/null || true
        fi
    fi

    # Clean up sudo keepalive if it was started
    if [[ -n "${sudo_keepalive_pid:-}" ]]; then
        kill "$sudo_keepalive_pid" 2> /dev/null || true
        wait "$sudo_keepalive_pid" 2> /dev/null || true
        sudo_keepalive_pid=""
    fi

    # Invalidate cache if any apps were successfully uninstalled
    if [[ $success_count -gt 0 ]]; then
        local cache_file="$HOME/.cache/mole/app_scan_cache"
        rm -f "$cache_file" 2> /dev/null || true
    fi

    ((total_size_cleaned += total_size_freed))
    unset failed_items
}
