# Shared helpers for the Battle.net export scripts. Dot-source this file:
#   . (Join-Path $PSScriptRoot 'BnetCommon.ps1')
#
# Credentials come from the environment variables BNET_CLIENT_ID and
# BNET_CLIENT_SECRET. They are never written to disk or printed.

function Initialize-Bnet([string]$Region, [string]$Locale) {
    if (-not $env:BNET_CLIENT_ID -or -not $env:BNET_CLIENT_SECRET) {
        throw 'BNET_CLIENT_ID and BNET_CLIENT_SECRET must be set as environment variables.'
    }
    $script:BnetNamespace = "static-forever-$Region"   # WoW Forever dataset only
    $script:BnetApiBase   = "https://$Region.api.blizzard.com/data/wow"
    $script:BnetLocale    = $Locale

    $pair  = "$($env:BNET_CLIENT_ID):$($env:BNET_CLIENT_SECRET)"
    $basic = [Convert]::ToBase64String([Text.Encoding]::UTF8.GetBytes($pair))
    $resp  = Invoke-RestMethod -Method Post -Uri 'https://oauth.battle.net/token' `
        -Headers @{ Authorization = "Basic $basic" } -Body @{ grant_type = 'client_credentials' }
    $script:BnetHeaders = @{ Authorization = "Bearer $($resp.access_token)" }
}

# GET a Game Data API path; returns $null on 404.
function Invoke-BnetApi([string]$Path) {
    $sep  = if ($Path.Contains('?')) { '&' } else { '?' }
    $uri  = "$script:BnetApiBase$Path${sep}namespace=$script:BnetNamespace&locale=$script:BnetLocale"
    $resp = Invoke-WebRequest -Uri $uri -Headers $script:BnetHeaders -SkipHttpErrorCheck
    Start-Sleep -Milliseconds 25   # stay well below the 100 requests/second limit
    if ($resp.StatusCode -eq 404) { return $null }
    if ($resp.StatusCode -ne 200) { throw "HTTP $($resp.StatusCode) for $Path" }
    return $resp.Content | ConvertFrom-Json
}

# Exact namespace/build the API resolved to, e.g. static-1.60.1_70399-forever-eu
function Get-BnetBuild($response) {
    if ($response._links.self.href -match 'namespace=([^&]+)') { return $Matches[1] }
    return $script:BnetNamespace
}

function ConvertTo-LuaString([string]$s) {
    if ($null -eq $s) { return 'nil' }
    $escaped = $s.Replace('\', '\\').Replace('"', '\"').Replace("`r", '').Replace("`n", '\n')
    return '"' + $escaped + '"'
}

function Format-LuaValue($v) {
    if ($null -eq $v)    { return 'nil' }
    if ($v -is [bool])   { return $v.ToString().ToLower() }
    if ($v -is [string]) { return ConvertTo-LuaString $v }
    if ($v -is [System.Collections.IDictionary]) {
        $parts = foreach ($key in $v.Keys) { "$key = $(Format-LuaValue $v[$key])" }
        return '{ ' + ($parts -join ', ') + ' }'
    }
    if ($v -is [System.Collections.IEnumerable]) {
        return '{ ' + (($v | ForEach-Object { Format-LuaValue $_ }) -join ', ') + ' }'
    }
    return [string]$v
}

function Write-LuaFile([string]$Path, [string]$Content) {
    $dir = Split-Path $Path -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
    Set-Content -Path $Path -Value $Content -Encoding utf8NoBOM -NoNewline
}
