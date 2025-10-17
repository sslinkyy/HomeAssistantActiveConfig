param(
  [Parameter(Mandatory=$true)][string]$Address,  # e.g. 192.168.1.252:8123
  [Parameter(Mandatory=$true)][string]$Token,
  [switch]$Secure
)

Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Runtime

$scheme = if ($Secure.IsPresent) { 'wss' } else { 'ws' }
$wsUri = "${scheme}://$Address/api/websocket"

function Send-Json($ws, [string]$json) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $seg = New-Object System.ArraySegment[byte] -ArgumentList (, $bytes)
  $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}

function Receive-Json($ws) {
  $buffer = New-Object byte[] 65536
  $seg = New-Object System.ArraySegment[byte] -ArgumentList (, $buffer)
  $sb = New-Object System.Text.StringBuilder
  do {
    $res = $ws.ReceiveAsync($seg, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
    $text = [System.Text.Encoding]::UTF8.GetString($buffer, 0, $res.Count)
    [void]$sb.Append($text)
  } while (-not $res.EndOfMessage)
  return $sb.ToString()
}

$ws = [System.Net.WebSockets.ClientWebSocket]::new()
try {
  $ws.ConnectAsync([Uri]$wsUri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
} catch {
  Write-Error ("Failed to connect to {0}: {1}" -f $wsUri, $_); exit 1
}

$hello = Receive-Json $ws | ConvertFrom-Json
if ($hello.type -ne 'auth_required') { Write-Error "Unexpected hello: $($hello | ConvertTo-Json -Depth 5)"; exit 1 }

Send-Json $ws (@{ type='auth'; access_token=$Token } | ConvertTo-Json -Compress)
$auth = Receive-Json $ws | ConvertFrom-Json
if ($auth.type -ne 'auth_ok') { Write-Error "Auth failed: $($auth | ConvertTo-Json -Depth 5)"; exit 1 }

New-Item -ItemType Directory -Force -Path ".storage" | Out-Null

$id = 1
function Req($type, $extra) {
  $script:id++
  $msg = @{ id=$script:id; type=$type }
  if ($extra) { $extra.Keys | ForEach-Object { $msg[$_] = $extra[$_] } }
  Send-Json $ws ($msg | ConvertTo-Json -Compress)
  do {
    $resp = Receive-Json $ws | ConvertFrom-Json
  } while ($resp.id -ne $script:id)
  return $resp
}

# Default dashboard config
$resp = Req 'lovelace/config' $null
if ($resp.success -and $resp.result) {
  ($resp.result | ConvertTo-Json -Depth 100) | Out-File -FilePath ".storage/lovelace" -Encoding utf8
} else { Write-Warning "lovelace/config failed: $($resp | ConvertTo-Json -Depth 5)" }

# Resources
$resp = Req 'lovelace/resources' $null
if ($resp.success -and $resp.result) {
  ($resp.result | ConvertTo-Json -Depth 100) | Out-File -FilePath ".storage/lovelace_resources" -Encoding utf8
} else { Write-Warning "lovelace/resources failed: $($resp | ConvertTo-Json -Depth 5)" }

# Dashboards list
$resp = Req 'lovelace/dashboards/list' $null
if ($resp.success -and $resp.result) {
  $dash = $resp.result
  ($dash | ConvertTo-Json -Depth 100) | Out-File -FilePath ".storage/lovelace_dashboards" -Encoding utf8
  foreach ($d in $dash) {
    if ($d.url_path) {
      $cfg = Req 'lovelace/config' @{ url_path = $d.url_path }
      if ($cfg.success -and $cfg.result) {
        ($cfg.result | ConvertTo-Json -Depth 100) | Out-File -FilePath (".storage/lovelace.{0}" -f $d.id) -Encoding utf8
      }
    }
  }
} else { Write-Warning "lovelace/dashboards/list failed: $($resp | ConvertTo-Json -Depth 5)" }

$ws.Dispose()
Write-Host "Saved Lovelace files under .storage/."
