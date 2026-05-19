#!/usr/bin/env bash
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FN="$HERE/../.github/actions/ecs-taskdef-transform/transform.sh"
PASS=0; FAIL=0
ok(){ echo "ok - $1"; PASS=$((PASS+1)); }
no(){ echo "NOT OK - $1"; FAIL=$((FAIL+1)); }
NEW_IMG="211125308791.dkr.ecr.ap-northeast-2.amazonaws.com/dev-open-echo/api:NEWSHA"

OUT="$(bash "$FN" "$HERE/fixtures/taskdef-single-app.json" "$NEW_IMG")"; RC=$?
[ $RC -eq 0 ] && ok "single-app exits 0" || no "single-app exits 0 (got $RC)"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].image')" = "$NEW_IMG" ] && ok "image swapped" || no "image swapped"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].environment[0].value')" = "info" ] && ok "environment preserved" || no "environment preserved"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].secrets[0].name')" = "DB_URL" ] && ok "secrets preserved" || no "secrets preserved"
[ "$(echo "$OUT" | jq -r '.cpu')" = "256" ] && ok "cpu preserved" || no "cpu preserved"
for k in taskDefinitionArn revision status requiresAttributes compatibilities registeredAt registeredBy deregisteredAt tags; do
  [ "$(echo "$OUT" | jq -r --arg k "$k" 'has($k)')" = "false" ] && ok "stripped $k" || no "stripped $k"
done
bash "$FN" "$HERE/fixtures/taskdef-two-containers.json" "$NEW_IMG" >/dev/null 2>&1
[ $? -ne 0 ] && ok "two-containers rejected" || no "two-containers rejected"
TMP="$(mktemp)"; jq '.taskDefinition.containerDefinitions[0].name="web"' "$HERE/fixtures/taskdef-single-app.json" > "$TMP"
bash "$FN" "$TMP" "$NEW_IMG" >/dev/null 2>&1
[ $? -ne 0 ] && ok "non-app container rejected" || no "non-app container rejected"
rm -f "$TMP"
echo "—— $PASS passed, $FAIL failed ——"; [ $FAIL -eq 0 ]
