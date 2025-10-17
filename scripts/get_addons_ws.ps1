param(
  [Parameter(Mandatory=$true)][string]$Address,  # e.g. 192.168.1.252:8123
  [Parameter(Mandatory=$true)][string]$Token
)

Add-Type -AssemblyName System.Net.Http
Add-Type -AssemblyName System.Runtime

$wsUri = "ws://$Address/api/websocket"

function Send-Json($ws, [string]$json) {
  $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
  $seg = New-Object System.ArraySegment[byte] -ArgumentList (, $bytes)
  $ws.SendAsync($seg, [System.Net.WebSockets.WebSocketMessageType]::Text, $true, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
}
function Receive-Json($ws) {
  $buffer = New-Object byte[] 131072
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
$ws.ConnectAsync([Uri]$wsUri, [Threading.CancellationToken]::None).GetAwaiter().GetResult()
$hello = Receive-Json $ws | ConvertFrom-Json
if ($hello.type -ne 'auth_required') { throw "Unexpected hello: $($hello | ConvertTo-Json -Depth 5)" }
Send-Json $ws (@{ type='auth'; access_token=$Token } | ConvertTo-Json -Compress)
$auth = Receive-Json $ws | ConvertFrom-Json
if ($auth.type -ne 'auth_ok') { throw "Auth failed: $($auth | ConvertTo-Json -Depth 5)" }

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

$resp = Req 'supervisor/api' @{ method = 'GET'; endpoint = '/addons' }
if (-not $resp.success) { throw ($resp | ConvertTo-Json -Depth 5) }

New-Item -ItemType Directory -Force -Path 'docs' | Out-Null
($resp.result | ConvertTo-Json -Depth 100) | Out-File -FilePath 'docs/addons.json' -Encoding utf8

$resp.result.data.addons | ForEach-Object { "{0}`t{1}`t{2}`t{3}`tupdate:{4}" -f $_.slug,$_.name,$_.version,$_.state,$_.update_available }

