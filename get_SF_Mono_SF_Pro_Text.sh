#!/usr/bin/env bash
set -eEuo pipefail
trap 's=$?; echo "$0: Error on line "$LINENO": $BASH_COMMAND"; exit $s' ERR

exit_with_err() {
    echo "$1" >&2
    exit 1
}

usage="[usage] $(basename "$0") <dir to put fonts>"
if [ "$#" -ne 1 ]; then
    exit_with_err "$usage"
fi

# input validation
# let's be specific: only proceed if the path exists and is a dir
output_path="$1"
if [ ! -d "$output_path" ]; then
    exit_with_err "[input validation] No directory on path: $output_path"
fi

# check dependency
check_dependency() {
    for cmd in "$@"; do
        if ! command -v "$cmd" &> /dev/null; then
            exit_with_err "[dependency check] Command missing: $cmd"
        fi
    done
}

check_dependency "wget" "7z"

# ^^^^^ boilerplate so far ^^^^^
# vvvvv real code from now on vvvvv

# extract upstream url for fonts
declare -a upstream=("https://devimages-cdn.apple.com/design/resources/download/SF-Pro.dmg" "https://devimages-cdn.apple.com/design/resources/download/SF-Mono.dmg")

# setup temp dir
# https://unix.stackexchange.com/a/84980
get_sf_tmpdir=$(mktemp -d 2> /dev/null || mktemp -d -t 'get_sf_tmpdir')
cleanup() {
    rm -rf "$get_sf_tmpdir"
}
trap cleanup EXIT

for dmg_url in "${upstream[@]}"; do
    # download font dmg
    dmg_name=$(basename "$dmg_url")
    dmg_path="$get_sf_tmpdir/$dmg_name"
    wget -q --show-progress -O "$dmg_path" "$dmg_url"

    # setup dir, will extract here
    extraction_dir_name="${dmg_name%.*}"
    extraction_dir_path="$get_sf_tmpdir/$extraction_dir_name"
    mkdir -p "$extraction_dir_path"

    # extract
    7z e -r -o"$extraction_dir_path" "$dmg_path" *.pkg 1> /dev/null || exit_with_err "[$dmg_name] dmg extraction failed"
    7z e -r -o"$extraction_dir_path" "$extraction_dir_path/*.pkg" Payload~ 1> /dev/null || exit_with_err "[$dmg_name] pkg extraction failed"
    7z e -r -o"$extraction_dir_path" "$extraction_dir_path/Payload~" *.otf 1> /dev/null || exit_with_err "[$dmg_name] Payload~ extraction failed"
    shopt -s nullglob
    # I just need SF Mono and SF Pro Text
    mv "$extraction_dir_path"/*{Text,Mono}*-*{Bold,Regular}*.otf "$output_path"
    shopt -u nullglob
done

# say goodbye
echo "[finished] SF fonts fetched: $output_path"
