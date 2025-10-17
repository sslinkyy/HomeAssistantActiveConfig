#!/usr/bin/env bash
set -euo pipefail

: "${HASS_URL:?Set HASS_URL (e.g., http://homeassistant:8123)}"
: "${HASS_TOKEN:?Set HASS_TOKEN (long-lived access token)}"

mkdir -p .storage
auth="Authorization: Bearer ${HASS_TOKEN}"
accept="Accept: application/json"

curl -fsS -H "$auth" -H "$accept" "$HASS_URL/api/lovelace/config" > .storage/lovelace
curl -fsS -H "$auth" -H "$accept" "$HASS_URL/api/lovelace/resources" > .storage/lovelace_resources
curl -fsS -H "$auth" -H "$accept" "$HASS_URL/api/lovelace/dashboards" > .storage/lovelace_dashboards

# Extract dashboard ids and fetch each config
ids=$(jq -r '.[].id // empty' < .storage/lovelace_dashboards || true)
for id in $ids; do
  if [[ "$id" != "lovelace" ]]; then
    curl -fsS -H "$auth" -H "$accept" "$HASS_URL/api/lovelace/config?dashboard=$id" > ".storage/lovelace.$id"
  fi
done

echo "Saved Lovelace files under .storage/. Add and commit when ready."

