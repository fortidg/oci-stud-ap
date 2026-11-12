#!/usr/bin/env bash
#
# Build the Resource Manager stack zip that students upload (or that a
# "Deploy to Oracle Cloud" button points at). Only the Terraform files and
# schema.yaml go in, at the zip root. State, tfvars and plan files never do.
#
# Usage: scripts/package-stack.sh [output.zip]     (default: dist/oci-ap-stack.zip)

set -euo pipefail

cd "$(dirname "$0")/.."
OUT="${1:-dist/oci-ap-stack.zip}"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"

zip -q -X "$OUT" ./*.tf ./*.tpl schema.yaml
echo "Wrote $OUT:"
unzip -l "$OUT"
