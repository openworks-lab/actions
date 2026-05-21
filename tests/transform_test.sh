#!/usr/bin/env bash
# transform_test.sh — ecs-taskdef-transform self-test.
# P5 T4.5 multi-container 패치 (debate D2 A3) 반영:
#   - app container 정확히 1개 강제 (APP_COUNT == 1)
#   - sidecar (app 이 아닌 다른 name) 허용 + image/env/healthCheck/mountPoints 보존
#   - app 이미지만 swap, sidecar 무변경
set -uo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
FN="$HERE/../.github/actions/ecs-taskdef-transform/transform.sh"
PASS=0; FAIL=0
ok(){ echo "ok - $1"; PASS=$((PASS+1)); }
no(){ echo "NOT OK - $1"; FAIL=$((FAIL+1)); }
NEW_IMG="211125308791.dkr.ecr.ap-northeast-2.amazonaws.com/dev-open-echo/api:NEWSHA"

# ─── Positive: single-app (P3 V1.0 호환) ──────────────────────────────────────
OUT="$(bash "$FN" "$HERE/fixtures/taskdef-single-app.json" "$NEW_IMG")"; RC=$?
[ $RC -eq 0 ] && ok "single-app exits 0" || no "single-app exits 0 (got $RC)"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].image')" = "$NEW_IMG" ] && ok "single-app: image swapped" || no "single-app: image swapped"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].environment[0].value')" = "info" ] && ok "single-app: environment preserved" || no "single-app: environment preserved"
[ "$(echo "$OUT" | jq -r '.containerDefinitions[0].secrets[0].name')" = "DB_URL" ] && ok "single-app: secrets preserved" || no "single-app: secrets preserved"
[ "$(echo "$OUT" | jq -r '.cpu')" = "256" ] && ok "single-app: cpu preserved" || no "single-app: cpu preserved"
for k in taskDefinitionArn revision status requiresAttributes compatibilities registeredAt registeredBy deregisteredAt tags; do
  [ "$(echo "$OUT" | jq -r --arg k "$k" 'has($k)')" = "false" ] && ok "single-app: stripped $k" || no "single-app: stripped $k"
done

# ─── Positive: app + sidecar (P5 T4.5 multi-container 패치) ─────────────────
# fixture taskdef-two-containers.json = app + logging-sidecar. T4.5 패치 후 = accept.
OUT2="$(bash "$FN" "$HERE/fixtures/taskdef-two-containers.json" "$NEW_IMG")"; RC=$?
[ $RC -eq 0 ] && ok "app+sidecar exits 0" || no "app+sidecar exits 0 (got $RC)"
APP_IMG="$(echo "$OUT2" | jq -r '.containerDefinitions[] | select(.name=="app") | .image')"
[ "$APP_IMG" = "$NEW_IMG" ] && ok "app+sidecar: app image swapped" || no "app+sidecar: app image swapped (got $APP_IMG)"
SIDECAR_IMG="$(echo "$OUT2" | jq -r '.containerDefinitions[] | select(.name=="logging-sidecar") | .image')"
[ "$SIDECAR_IMG" = "fluentbit" ] && ok "app+sidecar: sidecar image preserved" || no "app+sidecar: sidecar image preserved (got $SIDECAR_IMG)"
CONTAINER_COUNT="$(echo "$OUT2" | jq -r '.containerDefinitions | length')"
[ "$CONTAINER_COUNT" = "2" ] && ok "app+sidecar: 2 containers preserved" || no "app+sidecar: 2 containers preserved (got $CONTAINER_COUNT)"

# ─── Negative: app 2개 (M8 single-app invariant 위반) ─────────────────────
bash "$FN" "$HERE/fixtures/taskdef-two-apps.json" "$NEW_IMG" >/dev/null 2>&1
RC=$?
[ $RC -ne 0 ] && ok "two-apps rejected (APP_COUNT=2)" || no "two-apps rejected (APP_COUNT=2)"

# ─── Negative: app container 부재 (M8 single-app invariant 위반) ──────────
bash "$FN" "$HERE/fixtures/taskdef-no-app.json" "$NEW_IMG" >/dev/null 2>&1
RC=$?
[ $RC -ne 0 ] && ok "no-app rejected (APP_COUNT=0)" || no "no-app rejected (APP_COUNT=0)"

# ─── Negative: 단일 container 이지만 name 이 'app' 아님 ──────────────────
TMP="$(mktemp)"; jq '.taskDefinition.containerDefinitions[0].name="web"' "$HERE/fixtures/taskdef-single-app.json" > "$TMP"
bash "$FN" "$TMP" "$NEW_IMG" >/dev/null 2>&1
RC=$?
[ $RC -ne 0 ] && ok "non-app single container rejected" || no "non-app single container rejected"
rm -f "$TMP"

echo "—— $PASS passed, $FAIL failed ——"; [ $FAIL -eq 0 ]
