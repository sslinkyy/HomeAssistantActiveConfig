param(
  [string]$BaseUrl = $env:HASS_URL,
  [string]$Token = $env:HASS_TOKEN
)

if (-not $BaseUrl -or -not $Token) {
  Write-Error "Set -BaseUrl and -Token, or env HASS_URL/HASS_TOKEN."; exit 1
}

$Headers = @{ Authorization = "Bearer $Token"; Accept = 'application/json' }
New-Item -ItemType Directory -Force -Path ".storage" | Out-Null

function Save-Json($Uri, $OutPath) {
  $resp = Invoke-RestMethod -Method GET -Headers $Headers -Uri $Uri -TimeoutSec 30
  ($resp | ConvertTo-Json -Depth 100) | Out-File -FilePath $OutPath -Encoding utf8
}

# Global/default Lovelace config and resources
Save-Json "$BaseUrl/api/lovelace/config" ".storage/lovelace"
Save-Json "$BaseUrl/api/lovelace/resources" ".storage/lovelace_resources"

# Dashboards list
$dash = Invoke-RestMethod -Method GET -Headers $Headers -Uri "$BaseUrl/api/lovelace/dashboards" -TimeoutSec 30
($dash | ConvertTo-Json -Depth 100) | Out-File -FilePath ".storage/lovelace_dashboards" -Encoding utf8

# Per-dashboard configs
foreach ($d in $dash) {
  if ($d.id -and $d.id -ne 'lovelace') {
    $id = $d.id
    Save-Json "$BaseUrl/api/lovelace/config?dashboard=$id" ".storage/lovelace.$id"
  }
}

Write-Host "Saved Lovelace files under .storage/. Add and commit when ready."

