#!/usr/bin/env bash
# Pure transform: swap the 'app' container image, strip register-incompatible
# read-only fields, preserve everything else (drift-safe, spec §6.4 path A).
# Usage: transform.sh <describe-task-def.json> <new-image-uri>  → stdout JSON
set -euo pipefail
SRC="${1:?describe-task-def json path required}"
NEW_IMAGE="${2:?new image uri required}"
TD="$(jq -e '.taskDefinition // .' "$SRC")" || { echo "ERR: cannot read taskDefinition" >&2; exit 2; }
COUNT="$(echo "$TD" | jq '.containerDefinitions | length')"
[ "$COUNT" -eq 1 ] || { echo "ERR: V1.0 deploys exactly 1 container; found $COUNT (spec §6.4 / M8)" >&2; exit 3; }
NAME="$(echo "$TD" | jq -r '.containerDefinitions[0].name')"
[ "$NAME" = "app" ] || { echo "ERR: sole container must be named 'app'; found '$NAME'" >&2; exit 4; }
echo "$TD" | jq --arg img "$NEW_IMAGE" '
  .containerDefinitions[0].image = $img
  | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,
        .compatibilities,.registeredAt,.registeredBy,.deregisteredAt,.tags)'
