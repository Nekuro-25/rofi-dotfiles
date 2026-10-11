#!/usr/bin/env bash
# =========================================================
# SCREENSHOT MENU
# Mengikuti kebiasaan keybind screenshot.lua: simpan ke
# ~/Pictures/Screenshots, salin ke clipboard, kirim notifikasi.
# Keybind: SUPER + S (hypr/keybinds/menus.lua)
# =========================================================

source "$(dirname "$(readlink -f "$0")")/lib.sh"

DIR="$HOME/Pictures/Screenshots"
mkdir -p "$DIR"

# Geometri jendela aktif harus dibaca SEBELUM Rofi mengambil fokus
WINDOW_GEOMETRY=$(hyprctl activewindow -j 2>/dev/null \
    | jq -r 'select(.address != null) | "\(.at[0]),\(.at[1]) \(.size[0])x\(.size[1])"' 2>/dev/null)

AREA_COPY="  Area to clipboard"
AREA_SAVE="  Area, save + copy"
FULL="  Full screen, save + copy"
WINDOW="  Active window, save + copy"
ANNOTATE="  Area, annotate (swappy)"

choice=$(printf '%s\n' "$AREA_COPY" "$AREA_SAVE" "$FULL" "$WINDOW" "$ANNOTATE" \
    | menu "Screenshot" 5) || exit 0

# beri waktu Rofi menutup sebelum menangkap layar
sleep 0.3

new_file() { echo "$DIR/$(date +%Y-%m-%d_%H-%M-%S).png"; }

# Pilihan berbasis area: pilih area lebih dulu. Dibatalkan (Esc) -> keluar
# diam-diam. Harus di shell utama, bukan di dalam $(...), supaya `exit`
# benar-benar menghentikan skrip.
case "$choice" in
    "$AREA_COPY"|"$AREA_SAVE"|"$ANNOTATE")
        geometry=$(slurp) || exit 0
        ;;
esac

case "$choice" in
    "$AREA_COPY")
        grim -g "$geometry" - | wl-copy \
            && notify "Screenshot copied" "Area copied to clipboard"
        ;;
    "$AREA_SAVE")
        file=$(new_file)
        grim -g "$geometry" "$file" \
            && wl-copy < "$file" \
            && notify "Screenshot saved" "Area captured"
        ;;
    "$FULL")
        file=$(new_file)
        grim "$file" \
            && wl-copy < "$file" \
            && notify "Screenshot saved" "Full screen captured"
        ;;
    "$WINDOW")
        if [[ -z "$WINDOW_GEOMETRY" ]]; then
            notify "Screenshot" "No active window"
            exit 0
        fi
        file=$(new_file)
        grim -g "$WINDOW_GEOMETRY" "$file" \
            && wl-copy < "$file" \
            && notify "Screenshot saved" "Active window captured"
        ;;
    "$ANNOTATE")
        grim -g "$geometry" - | swappy -f -
        ;;
esac
