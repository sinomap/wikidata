#! /usr/bin/env bash

set -euo pipefail

source common.sh

parse-args() {
  local -n _dumpspec="$1"
  local -n _category="$2"
  local dump_arg="$3"
  local category_arg="${4:-}"
  if [[ $dump_arg =~ .*wiktionary/[0-9]+ ]]; then
    _dumpspec="$dump_arg"
    _category="$category_arg"
  else
    _dumpspec="$(jq -er ".$dump_arg.dumpspec" < dict-manifest.json)" \
      || (echo "Invalid dumpspec: $arg"; return 1)
    _category="$(jq -er ".$dump_arg.category" < dict-manifest.json)"
  fi
}

cmd="$1"
lang="${2:0:2}"
shift
parse-args dumpspec category "$@"

# Multiple languages may use the same dumpspec
base_tmp_dir="tmp/$dumpspec/$lang"
xml_path="$base_tmp_dir/dump.xml"
xml_bz2_path="$xml_path.bz2"
sql_path="$base_tmp_dir/links.sql"
sql_gz_path="$sql_path.gz"
id_path="$base_tmp_dir/ids"
db_name="${dumpspec/\//_}"
out_path="out/$lang-dict.json"

_mysql() {
  mysql -u root -h 127.0.0.1 -P 3306 "$@"
}

case "$cmd" in
  download|all)
    xml-file-data "$dumpspec" file_url file_md5
    download "$file_url" "$file_md5" "$xml_bz2_path"
    sql-file-data "$dumpspec" file_url file_md5
    download "$file_url" "$file_md5" "$sql_gz_path"
    ;;&
  bunzip|all)
    pv-bunzip "$xml_bz2_path" "$xml_path"
    pv-gunzip "$sql_gz_path" "$sql_path"
    ;;&
  load|all)
    echo "Loading $sql_path..."
    _mysql -e "DROP DATABASE IF EXISTS $db_name; CREATE DATABASE $db_name;"
    pv "$sql_path" | _mysql -D "$db_name"
    ;;&
  extract|all)
    echo "Extracting articles with category $category..."
    query="select cl_from from categorylinks where cl_to = '$category'"
    _mysql -D "$db_name" -N -e "$query" > "$id_path"
    mkdir -p "$(dirname "$out_path")"
    ./dictionary.py "$id_path" "$xml_path" "$out_path"
    ;;&
  artifacts|all)
    compress "$out_path"
    ;;
  download|bunzip|load|extract)
    exit 0
    ;;
  *)
    echo "Unknown command: $cmd"
    exit 1
    ;;
esac
