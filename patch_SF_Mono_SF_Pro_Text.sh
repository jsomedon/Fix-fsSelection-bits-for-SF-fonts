#!/usr/bin/env bash

check_dependency(){
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo "[pre install routine] install $cmd first, exiting now" >&2
            exit 1
        fi
    done
}

check_dependency "scraper" "7z" "ttx" "xml" "wget"

DMG_URLS=$(wget -q -O - "https://developer.apple.com/fonts/" |
              scraper  "body p.tile-button a.button" |
              grep 'Mono\|Pro' |
              scraper -a href "a")

get_otf(){
    wget -q --show-progress "$1"
    dmg_name=$(basename "$1")

    echo "[$dmg_name] downloaded" >&2

    dir_name="${dmg_name%.*}"
    otf_dir_name="${dir_name}_otf"
    mkdir "$otf_dir_name"
    7z x "$dmg_name" -o"$dir_name" 1>/dev/null
    rm "$dmg_name"
    cd "$dir_name" || exit
    cd */. || exit
    7z x *.pkg 1>/dev/null
    7z x "Payload~" 1>/dev/null
    cd ./Library/Fonts || exit
    shopt -s nullglob
    mv *{Text,Mono}*-*{Bold,Regular}*.otf ../../../../"$otf_dir_name"/
    shopt -u nullglob
    cd ../../../../
    rm -rf "$dir_name"
    echo "[$otf_dir_name] extracted" >&2
    echo "$otf_dir_name"
}

fix_otf(){
    cd "$1" || exit
    for otf in *; do
        ttx "$otf" 2>/dev/null

        echo "[$otf] computing correct bits" >&2
        bold_bit="0"
        italic_bit="0"
        regular_bit="0"
        if [[ $otf == *"Bold"* ]]; then
            bold_bit="1"
            if [[ $otf == *"Italic"* ]]; then
                italic_bit="1"
            fi
        else
            if [[ $otf == *"Italic"* ]]; then
                italic_bit="1"
            else
                regular_bit="1"
            fi
        fi

        ttx="${otf%.*}.ttx"

        echo "[$ttx] computing correct fields" >&2
        # "00000000 0RB0000I"
        fsSelection=$(xml sel -t -v "ttFont/OS_2/fsSelection/@value" "$ttx" |
                    tee >( sed "s/.*/[$ttx - fsSelection] was &\n/" >&2 ) |
                    sed "s/./$bold_bit/12" |
                    sed "s/./$italic_bit/17" |
                    sed "s/./$regular_bit/11" |
                    tee >( sed "s/.*/[$ttx - fsSelection] fixed as &\n/" >&2 ) )
        # "00000000 000000IB"
        macStyle=$(xml sel -t -v "ttFont/head/macStyle/@value" "$ttx" |
                 tee >( sed "s/.*/[$ttx - macStyle] was &\n/" >&2 ) |
                 sed "s/./$bold_bit/17" |
                 sed "s/./$italic_bit/16" |
                 tee >( sed "s/.*/[$ttx - macStyle] fixed as &\n/" >&2 ) )

        echo "[$ttx] applying fix" >&2
        xml ed -L -u "ttFont/OS_2/fsSelection/@value" -v "${fsSelection}" "$ttx"
        xml ed -L -u "ttFont/head/macStyle/@value" -v "${macStyle}" "$ttx"

        echo "[$ttx] verifying fix" >&2
        if [ "$fsSelection" == "$(xml sel -t -v "ttFont/OS_2/fsSelection/@value" "$ttx")" ] && [ "$macStyle" == "$(xml sel -t -v "ttFont/head/macStyle/@value" "$ttx")" ]; then
            echo "[$ttx] fix complete" >&2
        else
            echo "[$ttx] fix failed" >&2
        fi
    done
    rm *.otf
    ttx *.ttx 2>/dev/null
    rm *.ttx
    echo "[$1] $1 is now patched" >&2
    cd ../
}

for dmg_url in $DMG_URLS; do
    otf_dir=$(get_otf "$dmg_url")
    fix_otf "$otf_dir"
done
