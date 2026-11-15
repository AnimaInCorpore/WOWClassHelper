<#
.SYNOPSIS
    Runs the addon in plain Lua 5.1 with a stubbed WoW API (tools/smoke-test.lua).

.DESCRIPTION
    Loads all files from the TOC, fires the login events and runs the main
    features for every class: verdict tooltips, commands, knowledge base,
    mana bar and five-second rule, combat with secret values, compartment
    menu and debug report, plus the Priest and Paladin checks carried over
    from WOWPriest and WOWPaladin. It catches runtime errors the syntax check
    can't (nil values, typos, wrong widget methods, unknown events). It can't
    tell whether the real WoW Forever client behaves like the stubs - that
    needs /wch debug.

    Needs Lua 5.1 from msys2. Install once with:
        C:\msys64\usr\bin\bash.exe -lc "pacman -S --noconfirm --needed mingw-w64-ucrt-x86_64-lua51"

    Exit code 0 = all checks passed.

.EXAMPLE
    pwsh tools/Smoke-Test.ps1
    pwsh tools/Smoke-Test.ps1 -ShowTooltips
    pwsh tools/Smoke-Test.ps1 -ShowChat
#>
[CmdletBinding()]
param(
    [string]$Lua  = 'C:\msys64\ucrt64\bin\lua5.1.exe',
    [string]$Root = (Join-Path $PSScriptRoot '..'),
    [switch]$ShowChat,      # also print what the addon writes to chat
    [switch]$ShowTooltips   # also print every rendered verdict tooltip
)

if (-not (Test-Path $Lua)) { throw "Lua 5.1 not found at $Lua (see the install command in this script's help)" }

$luaArgs = @((Join-Path $PSScriptRoot 'smoke-test.lua'), (Resolve-Path $Root).Path)
if ($ShowChat) { $luaArgs += '-v' }
if ($ShowTooltips) { $luaArgs += '-t' }
& $Lua @luaArgs
exit $LASTEXITCODE
