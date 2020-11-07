#! /usr/bin/env bash

set -euo pipefail

source common.sh

_md5() {
  local path="$1"
  local -n _checksum="$2"
  if type md5 &>/dev/null; then
    _checksum="$(md5 -q "$path")"
  else
    _checksum="$(md5sum "$path" | awk '{print $1}')"
  fi
}

_bunzip() {
  if type pbzip2 &>/dev/null; then
    echo "Using pbzip2..." >&2
    pbzip2 -p2 -d
  else
    echo "Using bzip2..." >&2
    bzip2 -d
  fi
}

extract() {
  local xml_path="$1"
  local extract_path="$2"

  echo "Extracting articles..."
  vendor/WikiExtractor.py --processes 2 --no_templates --json -o "$extract_path" "$xml_path" 2>&1 \
    | egrep -v "INFO: [0-9]+"
}

compute-freqs() {
  local lang="$1"
  local root_dir="$2"
  local out_path="$3"

  echo "Computing word frequencies..."
  mkdir -p "$(dirname "$out_path")"
  ./frequency.py "$lang" "$root_dir" "$out_path"
}

parse-arg() {
  local -n _dumpspec="$1"
  local arg="$2"
  if [[ $arg =~ .*wiki/[0-9]+ ]]; then
    _dumpspec="$arg"
    return
  elif _dumpspec="$(jq -er ".$arg" < freqs-manifest.json)"; then
    return
  else
    echo "Invalid dumpspec: $arg"
    return 1
  fi
}

cmd="$1"
parse-arg dumpspec "$2"

lang="${dumpspec:0:2}"
base_tmp_dir="tmp/$dumpspec"
xml_path="$base_tmp_dir/dump.xml"
bz2_path="$xml_path.bz2"
extract_path="$base_tmp_dir/extracted"
out_path="out/$lang-wf.json"


case "$cmd" in
  download|all)
    xml-file-data "$dumpspec" file_url file_md5
    download "$file_url" "$file_md5" "$bz2_path"
    ;;&
  bunzip|all)
    pv-bunzip "$bz2_path" "$xml_path"
    ;;&
  extract|all)
    extract "$xml_path" "$extract_path"
    ;;&
  compute|all)
    compute-freqs "$lang" "$extract_path" "$out_path"
    ;;&
  artifacts|all)
    compress "$out_path"
    ;;
  download|bunzip|extract|compute)
    exit 0
    ;;
  *)
    echo "Unknown command: $cmd"
    exit 1
    ;;
esac
