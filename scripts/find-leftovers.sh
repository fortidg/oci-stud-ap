#!/usr/bin/env bash
#
# List resources left behind after the class, using OCI Search. Read-only.
#
# Usage:
#   scripts/find-leftovers.sh --class <class_name>            # everything tagged class=<class_name>, tenancy-wide
#   scripts/find-leftovers.sh --compartment <ocid> [...]      # everything in the given compartment(s), tagged or not
#
# Searching by compartment also catches resources a student created by hand
# (which won't carry the tags). Terminated/deleted resources are filtered out.
# OCI Search can lag a few minutes behind recent deletes.
#
# Requires: oci CLI, jq.

set -euo pipefail

QUERIES=()
while [[ $# -gt 0 ]]; do
  case "$1" in
    --class)
      QUERIES+=("query all resources where (freeformTags.key = 'class' && freeformTags.value = '${2:?--class needs a value}')")
      shift 2 ;;
    --compartment)
      QUERIES+=("query all resources where compartmentId = '${2:?--compartment needs an OCID}'")
      shift 2 ;;
    -h|--help) sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

[[ ${#QUERIES[@]} -gt 0 ]] || { sed -n '2,13p' "$0"; exit 1; }
command -v oci >/dev/null || { echo "oci CLI not found" >&2; exit 1; }
command -v jq  >/dev/null || { echo "jq not found" >&2; exit 1; }

search() {
  local query="$1" page="" out
  while :; do
    if [[ -n "$page" ]]; then
      out=$(oci search resource structured-search --query-text "$query" --limit 1000 --page "$page")
    else
      out=$(oci search resource structured-search --query-text "$query" --limit 1000)
    fi
    jq -c '.data.items[]?' <<<"$out"
    page=$(jq -r '."opc-next-page" // empty' <<<"$out")
    [[ -n "$page" ]] || break
  done
}

{
  printf 'TYPE\tNAME\tSTATE\tSTUDENT\tOCID\n'
  for q in "${QUERIES[@]}"; do search "$q"; done |
    jq -s -r 'unique_by(.identifier)[]
      | select((."lifecycle-state" // "") | test("^(TERMINATED|DELETED|DETACHED)$") | not)
      | [."resource-type", ."display-name", ."lifecycle-state", (."freeform-tags".student // "-"), .identifier]
      | @tsv'
} | column -t -s $'\t'
