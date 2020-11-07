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
  local filedata_filter="$1"
  local dumpspec="$2"
  local -n _file_url="$3"
  local -n _file_md5="$4"

  echo "Fetching file metadata..."
  local base_url="https://dumps.wikimedia.org"
  # .articlesmultistreamdump is for smaller wikis (used for quick testing) that don't have a
  # recombined version
  local data="$(curl -sSL "$base_url/$dumpspec/dumpstatus.json" | jq "$filedata_filter")"
  _file_md5="$(jq -r '.md5' <<< "$data")"
  _file_url="$base_url/$(jq -r '.url' <<< "$data" | sed 's_^/__')"
}

xml-file-data() {
  local filter='.jobs | (.articlesmultistreamdumprecombine // .articlesmultistreamdump)
                | .files | to_entries[] | select(.key | endswith(".xml.bz2")).value'
  file-data "$filter" "$@"
}

sql-file-data() {
  local filter='.jobs.categorylinkstable.files | to_entries[0].value'
  file-data "$filter" "$@"
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

pv-bunzip() {
  local in_path="$1"
  local out_path="$2"

  echo "Decompressing $in_path..."
  pv "$in_path" | _bunzip > "$out_path"
}

pv-gunzip() {
  local in_path="$1"
  local out_path="$2"

  echo "Decompressing $in_path..."
  pv "$in_path" | gunzip > "$out_path"
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

compress() {
  local out_path="$1"

  echo "Compressing output..."
  local tag="${CIRCLE_TAG:-latest}"
  local artifact_path=${out_path/.json/-$tag.json}
  cp "$out_path" "$artifact_path"
  zip --junk-paths "$artifact_path.zip" "$artifact_path"
  local checksum
  _md5 "$artifact_path.zip" checksum
  echo "$checksum" > "$artifact_path.zip.md5"
}

