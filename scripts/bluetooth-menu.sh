#!/usr/bin/env bash
# =========================================================
# BLUETOOTH MENU (bluetoothctl)
# Keybind: SUPER + B (hypr/keybinds/menus.lua)
#
# ●  = terhubung    ○  = sudah dipasangkan (paired)
# Perangkat yang meminta PIN/konfirmasi tidak bisa dipasangkan dari
# sini: pakai entri "Open Blueman" di bawah.
# =========================================================

source "$(dirname "$(readlink -f "$0")")/lib.sh"

ICON_SCAN=""
ICON_OFF=""
ICON_ON=""
ICON_GUI=""

declare -a entries actions macs names

add() {
    entries+=("$1")
    actions+=("$2")
    macs+=("${3:-}")
    names+=("${4:-}")
}

bt_powered() {
    bluetoothctl show 2>/dev/null | awk '/Powered:/ {print $2; exit}'
}

build_entries() {
    entries=(); actions=(); macs=(); names=()

    local _ mac name mark
    local -A connected paired

    while read -r _ mac _; do
        [[ -n "$mac" ]] && connected[$mac]=1
    done < <(bluetoothctl devices Connected 2>/dev/null)

    while read -r _ mac _; do
        [[ -n "$mac" ]] && paired[$mac]=1
    done < <(bluetoothctl devices Paired 2>/dev/null)

    while read -r _ mac name; do
        [[ -z "$mac" ]] && continue
        [[ -z "$name" ]] && name="$mac"
        mark="  "
        [[ -n "${paired[$mac]:-}" ]] && mark="○ "
        [[ -n "${connected[$mac]:-}" ]] && mark="● "
        add "$mark $name" device "$mac" "$name"
        # status disimpan di aksi supaya keputusan connect/disconnect tepat
        if [[ -n "${connected[$mac]:-}" ]]; then
            actions[${#actions[@]}-1]="disconnect"
        elif [[ -n "${paired[$mac]:-}" ]]; then
            actions[${#actions[@]}-1]="connect"
        else
            actions[${#actions[@]}-1]="pair"
        fi
    done < <(bluetoothctl devices 2>/dev/null)

    add "$ICON_SCAN  Scan for devices (6s)" scan
    add "$ICON_GUI  Open Blueman" gui
    add "$ICON_OFF  Turn Bluetooth off" off
}

connect_device() {
    local mac="$1" name="$2" out
    notify "Bluetooth" "Connecting to $name..."
    if out=$(timeout 25 bluetoothctl connect "$mac" 2>&1) \
        && [[ "$out" == *"Connection successful"* ]]; then
        notify "Bluetooth" "Connected to $name"
    else
        notify "Bluetooth" "Failed to connect to $name"
    fi
}

pair_device() {
    local mac="$1" name="$2" out
    notify "Bluetooth" "Pairing with $name..."
    out=$(timeout 40 bluetoothctl pair "$mac" 2>&1)
    if [[ "$out" != *"Pairing successful"* ]]; then
        notify "Bluetooth" "Pairing failed. Try Open Blueman."
        return 1
    fi
    bluetoothctl trust "$mac" >/dev/null 2>&1
    connect_device "$mac" "$name"
}

main() {
    local idx
    while true; do
        if [[ "$(bt_powered)" != "yes" ]]; then
            printf '%s\n' "$ICON_ON  Turn Bluetooth on" \
                | menu "Bluetooth" 1 -mesg "Bluetooth is turned off" >/dev/null || return 0
            bluetoothctl power on >/dev/null 2>&1
            sleep 1
            continue
        fi

        build_entries
        idx=$(printf '%s\n' "${entries[@]}" \
            | menu "Bluetooth" "$(clamp_lines "${#entries[@]}" 8)" -format i) || return 0

        case "${actions[$idx]}" in
            connect)
                connect_device "${macs[$idx]}" "${names[$idx]}"
                return 0
                ;;
            pair)
                pair_device "${macs[$idx]}" "${names[$idx]}"
                return 0
                ;;
            disconnect)
                bluetoothctl disconnect "${macs[$idx]}" >/dev/null 2>&1 \
                    && notify "Bluetooth" "Disconnected from ${names[$idx]}"
                return 0
                ;;
            scan)
                notify "Bluetooth" "Scanning for 6 seconds..."
                bluetoothctl --timeout 6 scan on >/dev/null 2>&1
                ;;
            gui)
                setsid -f blueman-manager >/dev/null 2>&1
                return 0
                ;;
            off)
                bluetoothctl power off >/dev/null 2>&1
                notify "Bluetooth" "Turned off"
                return 0
                ;;
        esac
    done
}

main
