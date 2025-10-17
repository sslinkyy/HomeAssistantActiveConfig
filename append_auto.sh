#!/bin/sh
# append_auto.sh  — append a motion→notify automation to automations.yaml
set -eu

ALIAS="$1"
DESC="${2:-Created via voice}"
MOTION="$3"
TITLE="$4"
MSG="$5"
MODE="${6:-single}"

TMP="/config/.auto_append_$$.yml"

# Write the automation block to a temp file (leading blank line kept)
cat > "$TMP" <<EOF

- alias: $ALIAS
  description: $DESC
  mode: $MODE
  trigger:
    - platform: state
      entity_id: $MOTION
      to: "on"
  condition: []
  action:
    - service: notify.mobile_app_sm_g975u
      data:
        title: $TITLE
        message: $MSG
    - service: notify.mobile_app_sm_s928u1
      data:
        title: $TITLE
        message: $MSG
EOF

# Append then clean up
cat "$TMP" >> /config/automations.yaml
rm -f "$TMP"