#! /usr/bin/env bash

set -euo pipefail

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

file-data() {
  local dumpspec="$1"
  local -n _file_url="$2"
  local -n _file_md5="$3"

  echo "Fetching file metadata..."
  local base_url="https://dumps.wikimedia.org"
  # .articlesmultistreamdump is for smaller wikis (used for quick testing) that don't have a
  # recombined version
  local filedata_filter='.jobs | (.articlesmultistreamdumprecombine // .articlesmultistreamdump)
                         | .files | to_entries[] | select(.key | endswith(".xml.bz2")).value'
  local data="$(curl -sSL "$base_url/$dumpspec/dumpstatus.json" | jq "$filedata_filter")"
  _file_md5="$(jq -r '.md5' <<< "$data")"
  _file_url="$base_url/$(jq -r '.url' <<< "$data" | sed 's_^/__')"
}

download() {
  local dump_url="$1"
  local dump_md5="$2"
  local out="$3"

  echo "Downloading $dump_url to $out..."
  mkdir -p "$(dirname "$out")"
  curl -o "$out" "$dump_url"
  echo "Verifying checksum..."
  local checksum
  _md5 "$out" checksum
  if [[ $checksum != $dump_md5 ]]; then
    echo "Checksum verification failed. Expected $dump_md5. Found $checksum."
    exit 1
  fi
}

bunzip() {
  local bz2_path="$1"
  local xml_path="$2"

  echo "Decompressing bz2 file..."
  if type pv &>/dev/null; then
    pv "$bz2_path" | _bunzip > "$xml_path"
  else
    _bunzip < "$bz2_path" > "$xml_path"
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
  local arg="$1"
  local -n _dumpspec="$2"
  if [[ $arg =~ .*wiki/[0-9]+ ]]; then
    _dumpspec="$arg"
    return
  elif _dumpspec="$(jq -er ".$arg" < manifest.json)"; then
    return
  else
    echo "Invalid dumpspec: $arg"
    return 1
  fi
}

parse-arg "$1" dumpspec
cmd="${2:-all}"

lang="${dumpspec:0:2}"
base_tmp_dir="tmp/$dumpspec"
xml_path="$base_tmp_dir/dump.xml"
bz2_path="$xml_path.bz2"
extract_path="$base_tmp_dir/extracted"
out_path="out/$dumpspec/wf.json"


case "$cmd" in
  download|all)
    file-data "$dumpspec" file_url file_md5
    download "$file_url" "$file_md5" "$bz2_path"
    ;;&
  bunzip|all)
    bunzip "$bz2_path" "$xml_path"
    ;;&
  extract|all)
    extract "$xml_path" "$extract_path"
    ;;&
  compute|all)
    compute-freqs "$lang" "$extract_path" "$out_path"
    ;;
  download|bunzip|extract)
    exit 0
    ;;
  *)
    echo "Unknown command: $cmd"
    exit 1
    ;;
esac
