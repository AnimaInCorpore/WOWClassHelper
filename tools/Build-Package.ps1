<#
.SYNOPSIS
    Builds a ready-to-share zip of the addon: dist/WOWClassHelper-<version>.zip

.DESCRIPTION
    Reads the version and the file list from WOWClassHelper.toc, so the zip always
    contains exactly what the game loads, plus README.md. Development files
    (tools/, docs/, items.txt, ...) are left out.

    Inside the zip everything sits in a WOWClassHelper/ folder, so the receiver
    unzips it directly into Interface\AddOns.

    By default the Lua check (tools/Check-Lua.ps1) and the smoke test
    (tools/Smoke-Test.ps1, skipped if Lua 5.1 isn't installed) run first and the
    build stops if one fails. Use -SkipCheck to build without them.

.EXAMPLE
    pwsh tools/Build-Package.ps1
    pwsh tools/Build-Package.ps1 -SkipCheck -NoReadme
#>
[CmdletBinding()]
param(
    [string]$Root   = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path,
    [string]$OutDir = (Join-Path (Resolve-Path (Join-Path $PSScriptRoot '..')).Path 'dist'),
    [switch]$SkipCheck,
    [switch]$NoReadme
)

$ErrorActionPreference = 'Stop'
$addonName = 'WOWClassHelper'
$tocPath   = Join-Path $Root "$addonName.toc"
if (-not (Test-Path $tocPath)) { throw "TOC not found: $tocPath" }

# --- Read version and file list from the TOC ----------------------------------

$tocLines = Get-Content $tocPath
$version = ($tocLines | Where-Object { $_ -match '^##\s*Version:\s*(.+)$' } | ForEach-Object { $Matches[1].Trim() } | Select-Object -First 1)
if (-not $version) { throw "No '## Version:' line in $tocPath" }

$files = @("$addonName.toc")
$files += $tocLines |
    ForEach-Object { $_.Trim() } |
    Where-Object { $_ -and -not $_.StartsWith('#') }
if (-not $NoReadme -and (Test-Path (Join-Path $Root 'README.md'))) { $files += 'README.md' }

$missing = $files | Where-Object { -not (Test-Path (Join-Path $Root $_)) }
if ($missing) { throw "Files listed in the TOC are missing: $($missing -join ', ')" }

# --- Lua check -------------------------------------------------------------------

if (-not $SkipCheck) {
    Write-Host 'Running Lua check...'
    & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Check-Lua.ps1') | Out-Host
    if ($LASTEXITCODE -ne 0) { throw 'Lua check failed - fix the errors or use -SkipCheck.' }

    if (Test-Path 'C:\msys64\ucrt64\bin\lua5.1.exe') {
        Write-Host 'Running smoke test...'
        & pwsh -NoProfile -File (Join-Path $PSScriptRoot 'Smoke-Test.ps1') | Out-Host
        if ($LASTEXITCODE -ne 0) { throw 'Smoke test failed - fix the errors or use -SkipCheck.' }
    } else {
        Write-Warning 'Lua 5.1 not installed - smoke test skipped (see tools/Smoke-Test.ps1).'
    }
}

# --- Build the zip ---------------------------------------------------------------
# ZipArchive is used directly so entry paths use '/' (portable for all unzip tools).

Add-Type -AssemblyName System.IO.Compression
Add-Type -AssemblyName System.IO.Compression.FileSystem

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Path $OutDir | Out-Null }
$zipPath = Join-Path $OutDir "$addonName-$version.zip"
if (Test-Path $zipPath) { Remove-Item $zipPath }

$zip = [System.IO.Compression.ZipFile]::Open($zipPath, [System.IO.Compression.ZipArchiveMode]::Create)
try {
    foreach ($rel in $files) {
        $source = Join-Path $Root $rel
        $entry  = "$addonName/" + ($rel -replace '\\', '/')
        [void][System.IO.Compression.ZipFileExtensions]::CreateEntryFromFile(
            $zip, $source, $entry, [System.IO.Compression.CompressionLevel]::Optimal)
    }
}
finally {
    $zip.Dispose()
}

$size = [math]::Round((Get-Item $zipPath).Length / 1KB, 1)
Write-Host ""
Write-Host "Built $zipPath ($size KB, $($files.Count) files, version $version)"
Write-Host "Your friend unzips it into: World of Warcraft\<Forever folder>\Interface\AddOns\"
