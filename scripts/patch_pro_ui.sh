#!/usr/bin/env bash
set -euo pipefail

# Patch the Storage UI dashboard "Pro (UI)" in-place to add counters, quick actions,
# Now Playing, convert Lights to tiles, and add a Health view.
#
# Requirements: bash + jq (Terminal & SSH add-on: apk add jq)
# Usage (on HA host):
#   bash scripts/patch_pro_ui.sh

FILE="/config/.storage/lovelace.pro_ui"

if [[ ! -f "$FILE" ]]; then
  echo "ERROR: $FILE not found. Open your 'Pro (UI)' dashboard once so HA creates it." >&2
  exit 1
fi

backup="$FILE.bak.$(date +%Y%m%d-%H%M%S)"
cp -f "$FILE" "$backup"
echo "Backup saved: $backup"

jq '
  # --- helpers ---
  def ensure_grid_section: {type:"grid", cards: []};

  def pad_sections($n):
    ( .sections |= ( . // [] ) )
    | if (.sections|length) >= $n then .
      else ( .sections += [ ensure_grid_section ] ) | pad_sections($n) end;

  # helper to ensure Health view exists later
  def health_view: {
    title: "Health",
    icon: "mdi:heart-pulse",
    type: "sections",
    path: "health",
    subview: true,
    sections: [
      { type: "grid", cards: [
          { type: "entities", title: "Core Snapshot", entities: [
              "sensor.open_doors_windows", "sensor.lights_on", "weather.home"
            ]},
          { type: "conditional",
            conditions: [ {entity:"binary_sensor.zigbee2mqtt_bridge_connection_state", state_not:"unavailable"} ],
            card: { type: "entities", title: "Zigbee2MQTT", entities: [
                "binary_sensor.zigbee2mqtt_bridge_connection_state",
                "binary_sensor.zigbee2mqtt_bridge_restart_required",
                "switch.zigbee2mqtt_bridge_permit_join"
            ]}}
          ,{ type: "markdown", content: "### System Docs\n- [Add-ons Summary](/local/docs/addons.md)\n- [Integrations Summary](/local/docs/integrations.md)" }
      ]}
    ]
  };

  # --- modify views in-place ---
  (.data.views) |= ( map(
    if .title == "Home" then
      # Ensure we have at least 3 sections
      ( pad_sections(3) )
      |
      # Section 2: add Household/Health nav tiles
      ( .sections[1].cards |= ( (. // []) + [
        {type:"tile", name:"Household", icon:"mdi:home-account", tap_action:{action:"navigate", navigation_path:"/pro/household"}},
        {type:"tile", name:"Health", icon:"mdi:heart-pulse", tap_action:{action:"navigate", navigation_path:"/pro/health"}}
      ] | unique_by(.name? // .entity?)))
      |
      # Section 3: counters + quick actions (robust)
      ( .sections[2] |= (
          .cards |= ( (. // []) )
          |
          # Try to locate a nested grid; if none, just push tiles into this section
          ( if ( any(.cards[]?; (.type=="grid" and (.cards|type=="array"))) ) then
              ( .cards |= ( map( if (.type=="grid" and (.cards|type=="array")) then
                                   ( .cards |= ( (. + [
                                       {type:"tile", entity:"sensor.updates_available_count", name:"Updates"},
                                       {type:"tile", entity:"sensor.unavailable_entities_count", name:"Unavailable"}
                                     ]) | unique_by(.name? // .entity?) ) )
                                   else . end )) )
            else
              ( .cards |= ( (. + [
                 {type:"tile", entity:"sensor.updates_available_count", name:"Updates"},
                 {type:"tile", entity:"sensor.unavailable_entities_count", name:"Unavailable"}
               ]) | unique_by(.name? // .entity?) ) )
            end )
          |
          ( .cards |= ( (. + [
                {type:"tile", entity:"script.all_lights_off", name:"All Lights Off", icon:"mdi:lightbulb-off"},
                {type:"tile", entity:"script.vacuum_return_to_base", name:"Dock Vacuum", icon:"mdi:robot-vacuum"}
              ]) | unique_by(.name? // .entity?) ) )
        ) )
      |
      # Add Now Playing row as new section
      ( .sections += [ { type:"grid", cards: [
          { type:"conditional", conditions:[
              {entity:"media_player.samsung_6_series_55", state_not:"off"},
              {entity:"media_player.samsung_6_series_55", state_not:"idle"},
              {entity:"media_player.samsung_6_series_55", state_not:"standby"},
              {entity:"media_player.samsung_6_series_55", state_not:"unavailable"}
            ], card:{ type:"media-control", entity:"media_player.samsung_6_series_55" } },
          { type:"conditional", conditions:[
              {entity:"media_player.onn_streaming_device_4k_pro", state_not:"off"},
              {entity:"media_player.onn_streaming_device_4k_pro", state_not:"idle"},
              {entity:"media_player.onn_streaming_device_4k_pro", state_not:"standby"},
              {entity:"media_player.onn_streaming_device_4k_pro", state_not:"unavailable"}
            ], card:{ type:"media-control", entity:"media_player.onn_streaming_device_4k_pro" } },
          { type:"conditional", conditions:[
              {entity:"media_player.spotify_ayorba_1986", state_not:"off"},
              {entity:"media_player.spotify_ayorba_1986", state_not:"idle"},
              {entity:"media_player.spotify_ayorba_1986", state_not:"standby"},
              {entity:"media_player.spotify_ayorba_1986", state_not:"unavailable"}
            ], card:{ type:"media-control", entity:"media_player.spotify_ayorba_1986" } }
        ] } ] )
    elif .title == "Lights" then
      ( .sections = [ { type:"grid", cards: [
          {type:"tile", entity:"light.2nd_living_room_light", name:"LR Light 2"},
          {type:"tile", entity:"light.0xa4c1384c438aa25c", name:"LR Light 1"},
          {type:"tile", entity:"light.front_porch_light", name:"Front Porch"},
          {type:"tile", entity:"light.master_bedroom_light", name:"Master Bedroom"},
          {type:"tile", entity:"light.chris_bedroom_light", name:"Chris Bedroom"},
          {type:"tile", entity:"light.emily_bedroom_light", name:"Emily Bedroom"},
          {type:"tile", entity:"light.spare_room_light", name:"Spare Room"},
          {type:"tile", entity:"light.master_bathroom_light", name:"Master Bathroom"},
          {type:"tile", entity:"light.0xa4c138e358edf3d8", name:"Ceiling Light (IEEE)"}
      ] } ] )
    else . end
  ))
  |
  # Ensure Health view exists
  ( if (.data.views | any(.title=="Health")) then . else
      .data.views += [ health_view ]
    end )
' "$FILE" > "$FILE.tmp" || {
  echo "jq failed; restoring backup" >&2
  cp -f "$backup" "$FILE"
  exit 1
}

mv "$FILE.tmp" "$FILE"
echo "Patched: $FILE"

# Copy docs so links in Health view work
mkdir -p /config/www/docs
if [[ -f "/config/docs/addons.md" ]]; then cp -f /config/docs/addons.md /config/www/docs/addons.md; fi
if [[ -f "/config/docs/integrations.md" ]]; then cp -f /config/docs/integrations.md /config/www/docs/integrations.md; fi
echo "Docs copied to /config/www/docs (accessible as /local/docs/...)."

echo "Done. Reload dashboards (Developer Tools → YAML) and hard refresh the browser."
