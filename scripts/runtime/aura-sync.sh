#!/usr/bin/env bash
# aura-sync.sh — sync this PC's AURA RGB LEDs to the matugen wallpaper palette.
#
# Mode: single accent. Every OpenRGB-detected device adopts the wallpaper's
# primary color. Wired as a matugen post_hook (see matugen config.toml,
# [templates.aura]). Runs automatically on every theme regeneration.
#
# Self-gating: the AURA hardware only exists on host "$TARGET_HOST". On any
# other machine, or before OpenRGB is installed, this exits 0 so the portable
# dotfiles and the matugen run itself are never affected.
#
# Dependency-light on purpose (bash + jq + openrgb only) — matugen's hook
# environment does not include the asdf shims, so no python/asdf tools here.

set -euo pipefail

TARGET_HOST="fedora-sin"
COLORS_JSON="$HOME/.config/aura-colors/colors.json"
ROLE="primary"   # palette role driving the LEDs: primary | secondary | tertiary

# --- gates -------------------------------------------------------------------
[[ "$(hostname)" == "$TARGET_HOST" ]] || exit 0
command -v openrgb >/dev/null 2>&1     || exit 0
[[ -f "$COLORS_JSON" ]]                || exit 0

# --- read accent color (strip leading '#', validate) -------------------------
color="$(jq -r --arg r "$ROLE" '.[$r] // empty' "$COLORS_JSON")"
color="${color#\#}"
if [[ ! "$color" =~ ^[0-9A-Fa-f]{6}$ ]]; then
    echo "aura-sync: no valid '$ROLE' color in $COLORS_JSON (got '$color')" >&2
    exit 0
fi

# --- push to every detected device ------------------------------------------
# 'static' is the common fixed-color mode; 'direct' is the universal fallback
# for devices that don't expose 'static'. Tune the order after inspecting
# `openrgb --list-devices` (it prints each device's supported modes).
apply() { openrgb --mode "$1" --color "$color" >/dev/null 2>&1; }
apply static || apply direct || \
    echo "aura-sync: openrgb could not apply #$color to any device" >&2
