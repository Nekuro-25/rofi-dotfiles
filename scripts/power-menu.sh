#!/usr/bin/env bash
# =========================================================
# POWER MENU
# Konfirmasi Yes/No hanya untuk Shutdown dan Reboot.
# Hibernate tidak ada: kernel belum punya resume= (lihat README).
# Keybind: SUPER + X (hypr/keybinds/menus.lua)
# =========================================================

source "$(dirname "$(readlink -f "$0")")/lib.sh"

SHUTDOWN="  Shutdown"
REBOOT="  Reboot"
SUSPEND="  Suspend"
LOCK="  Lock"
LOGOUT="  Logout"

# confirm <judul>  -> status 0 hanya jika memilih Yes ("No" ada di atas
# supaya menekan Enter tanpa sengaja tidak mematikan komputer)
confirm() {
    local answer
    answer=$(printf '%s\n%s\n' "No" "Yes" | menu "$1" 2 -mesg "Are you sure?") || return 1
    [[ "$answer" == "Yes" ]]
}

choice=$(printf '%s\n' "$SHUTDOWN" "$REBOOT" "$SUSPEND" "$LOCK" "$LOGOUT" \
    | menu "Power" 5) || exit 0

case "$choice" in
    "$SHUTDOWN")  confirm "Shutdown" && systemctl poweroff ;;
    "$REBOOT")    confirm "Reboot"   && systemctl reboot ;;
    "$SUSPEND")   systemctl suspend ;;
    "$LOCK")      loginctl lock-session ;;
    # Hyprland 0.55+ (config Lua): argumen dispatch adalah ekspresi Lua
    "$LOGOUT")    hyprctl dispatch 'hl.dsp.exit()' ;;
esac
