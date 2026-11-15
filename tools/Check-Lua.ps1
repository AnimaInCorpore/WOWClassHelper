<#
.SYNOPSIS
    Syntax-checks all addon Lua files and reports unexpected global variables.

.DESCRIPTION
    Uses luaparse (Lua 5.1 grammar, as used by WoW) through Node.js.
    Defaults match the msys64 setup: Node from C:\msys64\ucrt64\bin and
    luaparse installed in C:\msys64\opt\luaparse. To install luaparse there:
        C:\msys64\ucrt64\bin\npm.cmd install --prefix C:\msys64\opt\luaparse luaparse@0.3.1

    Exit code 0 = all OK, 1 = syntax errors or unexpected globals.

.EXAMPLE
    pwsh tools/Check-Lua.ps1
#>
[CmdletBinding()]
param(
    [string]$Node     = 'C:\msys64\ucrt64\bin\node.exe',
    [string]$LuaParse = 'C:\msys64\opt\luaparse\node_modules\luaparse\luaparse.js',
    [string]$Root     = (Join-Path $PSScriptRoot '..')
)

# Globals the addon creates on purpose (saved variables, slash commands,
# AddOn compartment handlers named in the TOC)
$allowedGlobals = @(
    'WOWClassHelperDB', 'WOWClassHelperCharDB', 'SLASH_WOWCLASSHELPER1', 'SLASH_WOWCLASSHELPER2',
    'WOWClassHelper_OnAddonCompartmentClick', 'WOWClassHelper_OnAddonCompartmentEnter',
    'WOWClassHelper_OnAddonCompartmentLeave'
)

if (-not (Test-Path $Node))     { throw "Node.js not found at $Node" }
if (-not (Test-Path $LuaParse)) { throw "luaparse not found at $LuaParse (see the install command in this script's help)" }

$files = Get-ChildItem $Root -Recurse -Filter *.lua | ForEach-Object FullName
$failed = $false

Write-Host '--- Syntax'
& $Node (Join-Path $PSScriptRoot 'check-lua.js') $LuaParse @files
if ($LASTEXITCODE -ne 0) { $failed = $true }

Write-Host '--- Unexpected globals'
# tools/ holds the smoke test, which defines the stubbed WoW API as globals on purpose
$toolsDir = (Resolve-Path $PSScriptRoot).Path
$addonFiles = $files | Where-Object { -not $_.StartsWith($toolsDir) }
$globals = & $Node (Join-Path $PSScriptRoot 'check-globals.js') $LuaParse @addonFiles
$unexpected = $globals | Where-Object {
    $name = ($_ -split ': ')[-1]
    $allowedGlobals -notcontains $name
}
if ($unexpected) {
    $unexpected | ForEach-Object { Write-Host $_ }
    $failed = $true
} else {
    Write-Host 'None'
}

exit ([int]$failed)
