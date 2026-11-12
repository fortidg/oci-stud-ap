#!/usr/bin/env bash
#
# Run a Resource Manager "Destroy" job for every stack in the given student
# compartments, wait for the jobs to finish, and optionally delete the stacks.
#
# Dry run by default: without --yes it only lists the stacks it would destroy.
#
# Usage:
#   scripts/destroy-stacks.sh [--yes] [--delete-stacks] --parent <compartment-ocid>
#   scripts/destroy-stacks.sh [--yes] [--delete-stacks] <compartment-ocid> [<compartment-ocid> ...]
#
#   --parent <ocid>   Process every active child compartment directly under <ocid>
#                     (e.g. a "students" compartment holding one compartment per student).
#   --yes             Actually create the destroy jobs. Without it, nothing is changed.
#   --delete-stacks   After a destroy job SUCCEEDS, delete the stack as well.
#
# Requires: oci CLI (authenticated as an instructor/admin), jq.

set -euo pipefail

APPLY=false
DELETE_STACKS=false
PARENT=""
COMPARTMENTS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) APPLY=true; shift ;;
    --delete-stacks) DELETE_STACKS=true; shift ;;
    --parent) PARENT="${2:?--parent needs an OCID}"; shift 2 ;;
    -h|--help) sed -n '2,19p' "$0"; exit 0 ;;
    ocid1.*) COMPARTMENTS+=("$1"); shift ;;
    *) echo "Unknown argument: $1" >&2; exit 1 ;;
  esac
done

command -v oci >/dev/null || { echo "oci CLI not found" >&2; exit 1; }
command -v jq  >/dev/null || { echo "jq not found" >&2; exit 1; }

if [[ -n "$PARENT" ]]; then
  while IFS= read -r c; do COMPARTMENTS+=("$c"); done < <(
    oci iam compartment list --compartment-id "$PARENT" --lifecycle-state ACTIVE --all |
      jq -r '.data[]?.id')
fi

if [[ ${#COMPARTMENTS[@]} -eq 0 ]]; then
  echo "No compartments given. Use --parent <ocid> or pass compartment OCIDs." >&2
  exit 1
fi

# Collect active stacks: "<stack-id>\t<compartment-id>\t<stack-name>"
STACKS=()
for comp in "${COMPARTMENTS[@]}"; do
  while IFS= read -r line; do [[ -n "$line" ]] && STACKS+=("$line"); done < <(
    oci resource-manager stack list --compartment-id "$comp" --lifecycle-state ACTIVE --all |
      jq -r --arg c "$comp" '.data[]? | [.id, $c, ."display-name"] | @tsv')
done

echo "Found ${#STACKS[@]} active stack(s) in ${#COMPARTMENTS[@]} compartment(s):"
if [[ ${#STACKS[@]} -eq 0 ]]; then echo "Nothing to destroy."; exit 0; fi
for s in "${STACKS[@]}"; do
  IFS=$'\t' read -r id comp name <<<"$s"
  echo "  $name  ($id)"
done

if ! $APPLY; then
  echo
  echo "Dry run only. Re-run with --yes to create destroy jobs."
  exit 0
fi

# Start all destroy jobs first so they run in parallel.
JOBS=()  # "<job-id>\t<stack-id>\t<stack-name>"
for s in "${STACKS[@]}"; do
  IFS=$'\t' read -r id comp name <<<"$s"
  job_id=$(oci resource-manager job create-destroy-job --stack-id "$id" \
             --execution-plan-strategy AUTO_APPROVED \
             --display-name "instructor-cleanup-$(date +%Y%m%d-%H%M%S)" |
           jq -r '.data.id')
  echo "Started destroy job for $name: $job_id"
  JOBS+=("$job_id"$'\t'"$id"$'\t'"$name")
done

# Wait for each job to reach a terminal state.
echo
echo "Waiting for destroy jobs to finish (FortiGate teardown usually takes 5-15 minutes)..."
FAILED=0
for j in "${JOBS[@]}"; do
  IFS=$'\t' read -r job_id stack_id name <<<"$j"
  while :; do
    state=$(oci resource-manager job get --job-id "$job_id" | jq -r '.data."lifecycle-state"')
    case "$state" in
      SUCCEEDED|FAILED|CANCELED) break ;;
      *) sleep 30 ;;
    esac
  done
  echo "  $name: $state"
  if [[ "$state" == "SUCCEEDED" ]]; then
    if $DELETE_STACKS; then
      oci resource-manager stack delete --stack-id "$stack_id" --force >/dev/null
      echo "    stack deleted"
    fi
  else
    FAILED=$((FAILED + 1))
    echo "    check the job log: oci resource-manager job get-job-logs-content --job-id $job_id"
  fi
done

echo
if [[ $FAILED -gt 0 ]]; then
  echo "$FAILED destroy job(s) did not succeed. Re-run, or use scripts/find-leftovers.sh to clean up manually."
  exit 1
fi
echo "All destroy jobs succeeded. Run scripts/find-leftovers.sh to confirm the compartments are empty."
