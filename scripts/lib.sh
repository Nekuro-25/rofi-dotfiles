#!/usr/bin/env bash
# =========================================================
# ROFI MENUS — HELPER BERSAMA
# Dipakai oleh: source "$(dirname "$(readlink -f "$0")")/lib.sh"
# =========================================================

ROFI_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/rofi"
MENU_THEME="$ROFI_DIR/menu.rasi"

# menu <prompt> <jumlah-baris> [argumen rofi tambahan...]
# Daftar item dibaca dari stdin, pilihan dicetak ke stdout.
# Esc atau klik di luar -> status keluar 1 dan tidak ada output.
menu() {
    local prompt="$1" lines="$2"
    shift 2
    rofi -dmenu -i -no-custom \
        -p "$prompt" \
        -theme "$MENU_THEME" \
        -theme-str "listview { lines: ${lines}; }" \
        "$@"
}

# ask_password <prompt>  -> mencetak teks yang diketik (disamarkan di layar)
ask_password() {
    printf '' | rofi -dmenu -password \
        -p "$1" \
        -theme "$MENU_THEME" \
        -theme-str 'listview { lines: 0; } entry { placeholder: "Type password..."; }'
}

# notify <judul> [isi]
notify() {
    notify-send -a "Rofi menu" "$1" "${2:-}"
}

# clamp_lines <jumlah> <maksimum>  -> jumlah yang dibatasi antara 1 dan maksimum
clamp_lines() {
    local n="$1" max="$2"
    (( n > max )) && n="$max"
    (( n < 1 )) && n=1
    echo "$n"
}
