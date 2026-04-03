#!/bin/bash
# Hyprland keybind cheat sheet — parses hyprland.conf live and displays via rofi
# Sorted by category with human-readable key names

CONFIG="$HOME/.config/hypr/hyprland.conf"

parse_binds() {
    local category="General"
    local vars=()

    # First pass: collect variable definitions
    while IFS= read -r line; do
        line="${line%%#*}"  # strip inline comments
        line="${line#"${line%%[![:space:]]*}"}"  # trim leading whitespace
        if [[ "$line" =~ ^\$([a-zA-Z_]+)\ *=\ *(.*) ]]; then
            vars+=("${BASH_REMATCH[1]}|${BASH_REMATCH[2]% }")
        fi
    done < "$CONFIG"

    expand_vars() {
        local s="$1"
        for v in "${vars[@]}"; do
            local name="${v%%|*}"
            local val="${v#*|}"
            s="${s//\$$name/$val}"
        done
        echo "$s"
    }

    prettify_key() {
        local k="$1"
        k="${k//SUPER/Super}"
        k="${k//SHIFT/Shift}"
        k="${k//ALT/Alt}"
        k="${k//CTRL/Ctrl}"
        k="${k//Return/Enter}"
        k="${k//SPACE/Space}"
        k="${k//PRINT/PrtSc}"
        k="${k//bracketleft/[}"
        k="${k//bracketright/]}"
        k="${k//backslash/\\}"
        k="${k//TAB/Tab}"
        k="${k//mouse:272/LMB}"
        k="${k//mouse:273/RMB}"
        k="${k//XF86AudioRaiseVolume/Vol+}"
        k="${k//XF86AudioLowerVolume/Vol-}"
        k="${k//XF86AudioMute/Mute}"
        k="${k//XF86MonBrightnessUp/Bright+}"
        k="${k//XF86MonBrightnessDown/Bright-}"
        k="${k//XF86AudioNext/Next}"
        k="${k//XF86AudioPrev/Prev}"
        k="${k//XF86AudioPlay/Play}"
        k="${k//XF86AudioPause/Pause}"
        echo "$k"
    }

    describe_action() {
        local action="$1"
        local arg="$2"
        arg="${arg#"${arg%%[![:space:]]*}"}"  # trim
        arg="${arg% }"
        case "$action" in
            exec,*)
                local cmd="${action#exec,} $arg"
                cmd="${cmd#"${cmd%%[![:space:]]*}"}"
                # Simplify known commands
                case "$cmd" in
                    *hyprctl\ reload*) echo "Reload config" ;;
                    *\$terminal*|*kitty*) echo "Terminal" ;;
                    *\$browser*|*chrome*|*firefox*) echo "Browser" ;;
                    *\$menu*|*rofi*|*launcher*) echo "App launcher" ;;
                    *\$emojipicker*|*bemoji*) echo "Emoji picker" ;;
                    *\$lock*|*hyprlock*) echo "Lock screen" ;;
                    *toggle-mic*) echo "Toggle mic" ;;
                    *toggle\ blueman*) echo "Bluetooth" ;;
                    *toggle\ pavucontrol*) echo "Audio settings" ;;
                    *rename-workspace*) echo "Rename workspace" ;;
                    *wallpaper-cycle*) echo "Cycle wallpaper" ;;
                    *hyprshot*-m\ window*) echo "Screenshot window" ;;
                    *hyprshot*-m\ output*) echo "Screenshot monitor" ;;
                    *hyprshot*-m\ region*) echo "Screenshot region" ;;
                    *layout-toggle*) echo "Toggle layout" ;;
                    *pkill*exit*) echo "Quit Hyprland" ;;
                    *power-saver*) echo "Power: saver" ;;
                    *balanced*) echo "Power: balanced" ;;
                    *performance*) echo "Power: performance" ;;
                    *brightnessctl*+*) echo "Brightness up" ;;
                    *brightnessctl*-*) echo "Brightness down" ;;
                    *playerctl\ next*) echo "Media next" ;;
                    *playerctl\ prev*) echo "Media prev" ;;
                    *playerctl\ play*) echo "Media play/pause" ;;
                    *volume*--inc*) echo "Volume up" ;;
                    *volume*--dec*) echo "Volume down" ;;
                    *volume*--toggle*) echo "Volume mute" ;;
                    *cheatsheet*) echo "Keybind cheat sheet" ;;
                    *) echo "$cmd" ;;
                esac
                ;;
            killactive*) echo "Close window" ;;
            togglefloating*) echo "Toggle floating" ;;
            pseudo*) echo "Pseudo-tile" ;;
            layoutmsg,*togglesplit*) echo "Toggle split" ;;
            movefocus,*) echo "Focus ${arg:-${action#movefocus,}}" ;;
            movewindow,*) echo "Move window ${arg:-${action#movewindow,}}" ;;
            workspace,*)
                local ws="${arg:-${action#workspace,}}"
                ws="${ws# }"
                case "$ws" in
                    e+1) echo "Next workspace" ;;
                    e-1) echo "Prev workspace" ;;
                    *) echo "Go to workspace $ws" ;;
                esac
                ;;
            movetoworkspace,*)
                local ws="${arg:-${action#movetoworkspace,}}"
                ws="${ws# }"
                case "$ws" in
                    special:*) echo "Move to scratchpad" ;;
                    *) echo "Move window to workspace $ws" ;;
                esac
                ;;
            togglespecialworkspace*) echo "Toggle scratchpad" ;;
            movecurrentworkspacetomonitor,*) echo "Move workspace to monitor ${arg:-${action#movecurrentworkspacetomonitor,}}" ;;
            movewindow) echo "Move window (mouse)" ;;
            resizewindow) echo "Resize window (mouse)" ;;
            pin,*) echo "Pin window" ;;
            fullscreen,*) echo "Fullscreen" ;;
            submap,*)
                local sm="${action#submap,}${arg}"
                sm="${sm# }"
                case "$sm" in
                    resize) echo "Enter resize mode" ;;
                    reset) echo "Exit mode" ;;
                    *) echo "Submap: $sm" ;;
                esac
                ;;
            resizeactive,*) echo "Resize ${arg:-${action#resizeactive,}}" ;;
            *) echo "$action $arg" ;;
        esac
    }

    # Category priority (lower = more relevant, shown first)
    cat_order() {
        case "$1" in
            Programs) echo "01" ;;
            "Window control") echo "02" ;;
            "Move focus"*) echo "03" ;;
            "Move window"*|"Move with"*) echo "04" ;;
            "Switch workspaces"*) echo "05" ;;
            "Move active window"*) echo "06" ;;
            "Move workspaces to"*) echo "07" ;;
            *scratchpad*|*special*) echo "08" ;;
            *scroll*|*tab*) echo "09" ;;
            Screenshots*|*shot*) echo "10" ;;
            "Layout"*) echo "11" ;;
            "Resize"*) echo "12" ;;
            "Workspace naming"*) echo "13" ;;
            *multimedia*|*Media*|*volume*) echo "14" ;;
            "Power profile"*) echo "15" ;;
            *) echo "20" ;;
        esac
    }

    # Second pass: parse binds
    local submap=""
    while IFS= read -r line; do
        # Track categories from comments
        stripped="${line#"${line%%[![:space:]]*}"}"
        if [[ "$stripped" =~ ^#\ *(.+) ]] && [[ ! "$stripped" =~ ^##|^#! ]]; then
            local comment="${BASH_REMATCH[1]}"
            # Skip non-category comments
            [[ "$comment" =~ ^see\ |^https|^See\ |^Example|^Or\ |^Sets|^Requires ]]; continue_skip=$?
            if [[ $continue_skip -ne 0 ]]; then
                category="$comment"
            fi
        fi

        # Track submaps
        if [[ "$stripped" =~ ^submap\ *=\ *(.+) ]]; then
            submap="${BASH_REMATCH[1]}"
            [[ "$submap" == "reset" ]] && submap=""
            continue
        fi

        # Parse bind lines
        if [[ "$stripped" =~ ^bind([elm]*)?\ *=\ *(.+) ]]; then
            local rest="${BASH_REMATCH[2]}"
            rest="$(expand_vars "$rest")"

            IFS=',' read -r mods key action remainder <<< "$rest"
            mods="${mods#"${mods%%[![:space:]]*}"}"
            mods="${mods% }"
            key="${key#"${key%%[![:space:]]*}"}"
            key="${key% }"
            action="${action#"${action%%[![:space:]]*}"}"

            # Skip commented binds
            [[ -z "$key" ]] && continue
            # Skip XF86 duplicates of regular binds
            [[ "$key" =~ ^XF86 && "$action" =~ hyprshot ]] && continue

            local display_key=""
            if [[ -n "$mods" ]]; then
                display_key="$(prettify_key "$mods") + $(prettify_key "$key")"
            else
                display_key="$(prettify_key "$key")"
            fi

            if [[ -n "$submap" ]]; then
                display_key="[$submap] $display_key"
            fi

            local desc
            desc="$(describe_action "$action" "$remainder")"

            local order
            order="$(cat_order "$category")"

            printf "%s|%-30s  %s\n" "$order" "$display_key" "$desc"
        fi
    done < "$CONFIG"
}

# Parse, sort by category priority, strip sort key, display in rofi
parse_binds | sort -t'|' -k1,1 | cut -d'|' -f2 | \
    rofi -dmenu -i -p " Keybinds" -no-custom \
    -theme "$HOME/.config/rofi/launchers/type-3/style-1.rasi"
