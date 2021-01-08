#!/usr/bin/env bash
set -eEuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exit_with_err() {
    echo "$1" >&2
    exit 1
}

output_dir="./SF_Mono_SF_Pro_Text"
mkdir -p "$output_dir"
./get_SF_Mono_SF_Pro_Text.sh "$output_dir"
for otf in "$output_dir"/*.otf; do
    # iirc apple's font naming is like:
    # Bold for bold
    # BoldItalic for bold and italic
    # Regular for regular
    # RegularItalic for italic
    bold=0
    italic=0
    regular=0
    if [[ $otf == *"Bold"* ]]; then
        bold="1"
        if [[ $otf == *"Italic"* ]]; then
            italic="1"
        fi
    elif [[ $otf == *"Italic"* ]]; then
        italic="1"
    elif [[ $otf == *"Regular"* ]]; then
        regular="1"
    else
        exit_with_err "[font style parsing] Can't parse font style from font name: $otf"
    fi

    ./fix_fsSelection.sh "$otf" "$bold$italic$regular"
done

# say goodbye
echo "[finished] SF Mono and SF Pro Text are patched; original and patched fonts are in $output_dir"
