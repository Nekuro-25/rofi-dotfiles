#!/usr/bin/env bash
# =========================================================
# WI-FI MENU (NetworkManager / nmcli)
# Keybind: SUPER + N (hypr/keybinds/menus.lua)
#
# Jaringan enterprise (802.1X) tidak ditangani di sini: pakai nmtui.
# Catatan: kata sandi dikirim ke nmcli sebagai argumen baris perintah
# (cara standar menu semacam ini); terlihat di `ps` sepersekian detik.
# =========================================================

source "$(dirname "$(readlink -f "$0")")/lib.sh"

ICON_CHECK=""
ICON_LOCK=""
ICON_RESCAN=""
ICON_DISCONNECT=""
ICON_OFF=""
ICON_ON=""
ICON_TUI=""

declare -a entries actions ssids secs

add() {
    entries+=("$1")
    actions+=("$2")
    ssids+=("${3:-}")
    secs+=("${4:-}")
}

# nmcli -t memakai ':' sebagai pemisah dan meng-escape ':' dan '\'
# di dalam nilai. Hasil parse: P_INUSE P_SSID P_SIGNAL P_SEC
parse_line() {
    local line="$1"
    line=${line//\\\\/$'\x02'}
    line=${line//\\:/$'\x01'}
    IFS=: read -r P_INUSE P_SSID P_SIGNAL P_SEC <<<"$line"
    P_SSID=${P_SSID//$'\x01'/:}
    P_SSID=${P_SSID//$'\x02'/\\}
}

wifi_device() {
    nmcli -t -f DEVICE,TYPE device 2>/dev/null | awk -F: '$2=="wifi" {print $1; exit}'
}

build_entries() {
    entries=(); actions=(); ssids=(); secs=()

    local line active_ssid="" sig ssid mark lock
    local -A best sec_of inuse_of

    while IFS= read -r line; do
        [[ -z "$line" ]] && continue
        parse_line "$line"
        [[ -z "$P_SSID" ]] && continue          # jaringan tersembunyi
        sig=${P_SIGNAL:-0}
        # satu entri per SSID: simpan sinyal terkuat
        if [[ -z "${best[$P_SSID]+x}" || "$sig" -gt "${best[$P_SSID]}" ]]; then
            best[$P_SSID]=$sig
            sec_of[$P_SSID]="$P_SEC"
        fi
        if [[ "$P_INUSE" == "*" ]]; then
            inuse_of[$P_SSID]=1
            active_ssid="$P_SSID"
        fi
    done < <(nmcli -t -f IN-USE,SSID,SIGNAL,SECURITY device wifi list 2>/dev/null)

    # jaringan: sinyal terkuat di atas
    while IFS=$'\t' read -r _ ssid; do
        [[ -z "$ssid" ]] && continue
        mark="  "
        [[ -n "${inuse_of[$ssid]:-}" ]] && mark="$ICON_CHECK "
        lock=""
        if [[ -n "${sec_of[$ssid]}" && "${sec_of[$ssid]}" != "--" ]]; then
            lock="  $ICON_LOCK"
        fi
        add "$mark $ssid   ${best[$ssid]}%$lock" net "$ssid" "${sec_of[$ssid]}"
    done < <(for ssid in "${!best[@]}"; do printf '%s\t%s\n' "${best[$ssid]}" "$ssid"; done \
                | sort -t$'\t' -k1,1nr -k2,2)

    # aksi di bagian bawah (Ctrl+k dari atas melompat ke sini karena cycle)
    add "$ICON_RESCAN  Rescan networks" rescan
    [[ -n "$active_ssid" ]] && add "$ICON_DISCONNECT  Disconnect from $active_ssid" disconnect
    add "$ICON_TUI  Open nmtui" nmtui
    add "$ICON_OFF  Turn Wi-Fi off" off
}

connect_network() {
    local ssid="$1" sec="$2" out pass

    if [[ "$sec" == *802.1X* ]]; then
        notify "Wi-Fi" "Enterprise network: use nmtui"
        return
    fi

    notify "Wi-Fi" "Connecting to $ssid..."

    if nmcli -t -f NAME connection show 2>/dev/null | grep -Fxq -- "$ssid"; then
        # profil tersimpan: pakai kata sandi yang sudah ada
        out=$(nmcli --wait 20 connection up id "$ssid" 2>&1)
    elif [[ -z "$sec" || "$sec" == "--" ]]; then
        out=$(nmcli --wait 20 device wifi connect "$ssid" 2>&1)
    else
        pass=$(ask_password "Password: $ssid") || return
        [[ -z "$pass" ]] && return
        out=$(nmcli --wait 20 device wifi connect "$ssid" password "$pass" 2>&1)
    fi

    if (( $? == 0 )); then
        notify "Wi-Fi" "Connected to $ssid"
    else
        notify "Wi-Fi" "Failed: $(head -n1 <<<"$out")"
    fi
}

main() {
    local idx
    while true; do
        if [[ "$(nmcli radio wifi 2>/dev/null)" != "enabled" ]]; then
            printf '%s\n' "$ICON_ON  Turn Wi-Fi on" \
                | menu "Wi-Fi" 1 -mesg "Wi-Fi is turned off" >/dev/null || return 0
            nmcli radio wifi on
            sleep 2
            continue
        fi

        build_entries
        idx=$(printf '%s\n' "${entries[@]}" \
            | menu "Wi-Fi" "$(clamp_lines "${#entries[@]}" 8)" -format i) || return 0

        case "${actions[$idx]}" in
            net)
                connect_network "${ssids[$idx]}" "${secs[$idx]}"
                return 0
                ;;
            rescan)
                notify "Wi-Fi" "Scanning..."
                nmcli device wifi rescan >/dev/null 2>&1
                sleep 3
                ;;
            disconnect)
                nmcli device disconnect "$(wifi_device)" >/dev/null 2>&1 \
                    && notify "Wi-Fi" "Disconnected"
                return 0
                ;;
            nmtui)
                setsid -f kitty -e nmtui >/dev/null 2>&1
                return 0
                ;;
            off)
                nmcli radio wifi off
                notify "Wi-Fi" "Turned off"
                return 0
                ;;
        esac
    done
}

main
