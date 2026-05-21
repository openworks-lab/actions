#!/usr/bin/env bash
# Pure transform: find 'app' container (debate D2 A3 — sidecars allowed),
# swap its image, strip register-incompatible read-only fields, preserve all
# other containers (sidecars) + everything else (drift-safe, spec §6.4 path A).
# Usage: transform.sh <describe-task-def.json> <new-image-uri>  → stdout JSON
set -euo pipefail
SRC="${1:?describe-task-def json path required}"
NEW_IMAGE="${2:?new image uri required}"
TD="$(jq -e '.taskDefinition // .' "$SRC")" || { echo "ERR: cannot read taskDefinition" >&2; exit 2; }

COUNT="$(echo "$TD" | jq '.containerDefinitions | length')"
[ "$COUNT" -ge 1 ] || { echo "ERR: at least 1 container required; found $COUNT" >&2; exit 3; }

# Single-app invariant (M8): exactly 1 container named 'app'. Sidecars (debate D2 A3) allowed.
APP_COUNT="$(echo "$TD" | jq '[.containerDefinitions[] | select(.name == "app")] | length')"
[ "$APP_COUNT" -eq 1 ] || { echo "ERR: exactly 1 container named 'app' required; found $APP_COUNT (V1.0 single-app guard, spec §6.4 / M8)" >&2; exit 4; }

# Swap image only on 'app'; sidecars untouched (image/env/healthCheck/mountPoints all preserved).
echo "$TD" | jq --arg img "$NEW_IMAGE" '
  .containerDefinitions |= map(if .name == "app" then .image = $img else . end)
  | del(.taskDefinitionArn,.revision,.status,.requiresAttributes,
        .compatibilities,.registeredAt,.registeredBy,.deregisteredAt,.tags)'
