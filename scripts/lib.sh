#!/usr/bin/env bash
# =========================================================
# ROFI MENUS — HELPER BERSAMA
# Dipakai oleh: source "$(dirname "$(readlink -f "$0")")/lib.sh"
#
# Kegagalan Rofi (kode keluar selain 0 dan 1) dicatat di
# ~/.cache/rofi-menus.log dan ditampilkan sebagai notifikasi,
# supaya menu yang "tidak muncul" ada penjelasannya.
# =========================================================

ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
MENU_THEME="$ROFI_DIR/menu.rasi"
LOG_FILE="${XDG_CACHE_HOME:-$HOME/.cache}/rofi-menus.log"
mkdir -p "$(dirname "$LOG_FILE")"

# notify <judul> [isi]
notify() {
    notify-send -a "Rofi menu" "$1" "${2:-}"
}

# menu <prompt> <jumlah-baris> [argumen rofi tambahan...]
# Daftar item dibaca dari stdin, pilihan dicetak ke stdout.
# Esc atau klik di luar -> status keluar 1 dan tidak ada output.
menu() {
    local prompt="$1" lines="$2" out rc
    shift 2
    out=$(rofi -dmenu -i -no-custom \
        -p "$prompt" \
        -theme "$MENU_THEME" \
        -theme-str "listview { lines: ${lines}; }" \
        "$@" 2>>"$LOG_FILE")
    rc=$?
    # 0 = dipilih, 1 = dibatalkan; selain itu = Rofi gagal
    if (( rc != 0 && rc != 1 )); then
        notify "Rofi gagal (kode $rc)" "$(tail -n 1 "$LOG_FILE")"
    fi
    [[ -n "$out" ]] && printf '%s\n' "$out"
    return "$rc"
}

# ask_password <prompt>  -> mencetak teks yang diketik (disamarkan di layar)
ask_password() {
    printf '' | rofi -dmenu -password \
        -p "$1" \
        -theme "$MENU_THEME" \
        -theme-str 'listview { lines: 0; } entry { placeholder: "Type password..."; }' \
        2>>"$LOG_FILE"
}

# clamp_lines <jumlah> <maksimum>  -> jumlah yang dibatasi antara 1 dan maksimum
clamp_lines() {
    local n="$1" max="$2"
    (( n > max )) && n="$max"
    (( n < 1 )) && n=1
    echo "$n"
}
