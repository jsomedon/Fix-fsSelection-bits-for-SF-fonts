#!/usr/bin/env bash
set -eEuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exit_with_err() {
    echo "$1" >&2
    exit 1
}

usage="[usage] $(basename "$0") <font dir> <font style bits>
font style bits: <bold bit><italic bit><regular bit>
                 to fix for bold - 100
                 for bold italic - 110
                 for regular - 001
                 for italic - 010
                 other style bits are invalid"
if [ "$#" -ne 2 ]; then
    exit_with_err "$usage"
fi

otf="$1"
style_bits="$2"

# validate $otf
if [ ! -f "$otf" ]; then
    exit_with_err "[input validation] No such file exists: $otf"
fi

# validate & parse $style_bits
bold_bit="-1"
italic_bit="-1"
regular_bit="-1"
case "$style_bits" in
    "100" | "110" | "001" | "010")
        bold_bit=${style_bits:0:1}
        italic_bit=${style_bits:1:1}
        regular_bit=${style_bits:2:1}
        ;;
    *)
        exit_with_err "[input validation] Invalid style bits: $style_bits"
        ;;
esac

check_dependency() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            exit_with_err "[dependency check] Command missing: $cmd"
        fi
    done
}

check_dependency "ttx" "xml"

# ^^^^^ boilerplate so far ^^^^^
# vvvvv real code from now on vvvvv

# get ttx from otf
# setup temp dir
# https://unix.stackexchange.com/a/84980
ttx_tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'ttx_tmpdir')
ttx_tmpdir_cleanup() {
    rm -rf "$ttx_tmpdir"
}
trap ttx_tmpdir_cleanup EXIT
# proceed
ttx -d "$ttx_tmpdir" "$otf" 2> /dev/null || exit_with_err "[deserialization] Failed to convert $otf to ttx"
otf_basename=$(basename "$otf")
ttx="$ttx_tmpdir/${otf_basename%.*}.ttx"

# compute correct bits for fsSelection and macStyle
# fsSelection has bits for bolt, italic and regular, positioned as:
# "00000000 0RB0000I" (R for regular, B for bold, I for italic)
fsSelection=$(xml sel -t -v "ttFont/OS_2/fsSelection/@value" "$ttx" |
    tee >(sed "s/.*/[$otf_basename - fsSelection] Current bits are &\n/" >&2) |
    sed "s/./$bold_bit/12" |
    sed "s/./$italic_bit/17" |
    sed "s/./$regular_bit/11" |
    tee >(sed "s/.*/[$otf_basename - fsSelection] New bits are &\n/" >&2))
# macStyle has bits for bold and italic, positioned as:
# "00000000 000000IB" (I for italic, B for bold)
macStyle=$(xml sel -t -v "ttFont/head/macStyle/@value" "$ttx" |
    tee >(sed "s/.*/[$otf_basename - macStyle] Current bits are &\n/" >&2) |
    sed "s/./$bold_bit/17" |
    sed "s/./$italic_bit/16" |
    tee >(sed "s/.*/[$otf_basename - macStyle] New bits are &\n/" >&2))

# update ttx
xml ed -L -u "ttFont/OS_2/fsSelection/@value" -v "${fsSelection}" "$ttx" || exit_with_err "[ttx update] Failed to update fsSelection on $ttx"
xml ed -L -u "ttFont/head/macStyle/@value" -v "${macStyle}" "$ttx" || exit_with_err "[ttx update] Failed to update macStyle on $ttx"

# is it necessary to double check? maybe not? commenting out for now..
: '
if [ "$fsSelection" == "$(xml sel -t -v "ttFont/OS_2/fsSelection/@value" "$ttx")" ] && [ "$macStyle" == "$(xml sel -t -v "ttFont/head/macStyle/@value" "$ttx")" ]; then
    echo "[ttx update verification] Verification succeeded" >&2
else
    exit_with_err "[ttx update verification] Verification failed"
fi
'

# patch & save
patched_otf="$(dirname "$otf")/patched.$(basename "$otf")"
ttx -o "$patched_otf" "$ttx" 2> /dev/null || exit_with_err "[font compilation] Failed to compile font from $ttx"

# say goodbye
echo "[$otf_basename - finished] Fix applied, saved as $patched_otf"
