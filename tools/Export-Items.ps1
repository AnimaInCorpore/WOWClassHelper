<#
.SYNOPSIS
    Exports WoW Forever item data from the Battle.net Game Data API into a Lua table.

.DESCRIPTION
    Reads item IDs from a text file (one per line, '#' starts a comment),
    fetches each item from the Forever dataset (namespace static-forever-<region>)
    and writes Data/Items.lua, which the addon loads as ns.Items.

.EXAMPLE
    pwsh tools/Export-Items.ps1
    pwsh tools/Export-Items.ps1 -Locale de_DE
    pwsh tools/Export-Items.ps1 -NoIcons
#>
[CmdletBinding()]
param(
    [string]$ItemList = (Join-Path $PSScriptRoot 'items.txt'),
    [string]$OutFile  = (Join-Path $PSScriptRoot '..\Data\Items.lua'),
    [ValidateSet('eu', 'us', 'kr', 'tw')]
    [string]$Region = 'eu',
    [string]$Locale = 'en_US',
    [switch]$NoIcons
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BnetCommon.ps1')

# Item quality type -> numeric value used by the game's Enum.ItemQuality
$qualityMap = @{
    POOR = 0; COMMON = 1; UNCOMMON = 2; RARE = 3; EPIC = 4
    LEGENDARY = 5; ARTIFACT = 6; HEIRLOOM = 7; WOW_TOKEN = 8
}

$ids = Get-Content $ItemList |
    ForEach-Object { ($_ -split '#')[0].Trim() } |
    Where-Object { $_ -match '^\d+$' } |
    ForEach-Object { [int]$_ } |
    Sort-Object -Unique

if (-not $ids) { throw "No item IDs found in $ItemList" }

Initialize-Bnet -Region $Region -Locale $Locale
Write-Host "Exporting $($ids.Count) items from namespace $script:BnetNamespace ($Locale)..."

$items   = [ordered]@{}
$missing = @()
$build   = $null

foreach ($id in $ids) {
    $item = Invoke-BnetApi "/item/$id"
    if (-not $item) {
        Write-Warning "Item $id not found in $script:BnetNamespace - skipped."
        $missing += $id
        continue
    }
    if (-not $build) { $build = Get-BnetBuild $item }

    $p = $item.preview_item
    $entry = [ordered]@{
        name     = $item.name
        quality  = $qualityMap[$item.quality.type]
        ilvl     = $p.level.value
        reqLevel = if ($p.requirements.level.value) { $p.requirements.level.value } else { $item.required_level }
        class    = $item.item_class.id
        subclass = $item.item_subclass.id
        slot     = $item.inventory_type.type
    }
    if ($p.set.item_set.id) { $entry.setID = $p.set.item_set.id }

    if ($p.stats) {
        $stats = [ordered]@{}
        foreach ($s in $p.stats) {
            if (-not $s.is_negated) { $stats[$s.type.type] = $s.value }
        }
        if ($stats.Count) { $entry.stats = $stats }
    }

    if ($p.armor) { $entry.armor = $p.armor.value }
    if ($p.weapon) {
        $entry.weapon = [ordered]@{
            min   = $p.weapon.damage.min_value
            max   = $p.weapon.damage.max_value
            speed = [math]::Round($p.weapon.attack_speed.value / 1000, 2)
        }
    }

    if (-not $NoIcons) {
        $media = Invoke-BnetApi "/media/item/$id"
        $icon  = $media.assets | Where-Object key -eq 'icon' | Select-Object -First 1
        if ($icon) { $entry.icon = $icon.file_data_id }
    }

    $items["$id"] = $entry   # string key: an int key on [ordered] means "position"
    Write-Host ("  {0,6}  {1}" -f $id, $item.name)
}

$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('-- GENERATED FILE - do not edit by hand.')
[void]$sb.AppendLine("-- Source: Battle.net Game Data API, namespace $build, locale $Locale")
[void]$sb.AppendLine('-- Regenerate with: pwsh tools/Export-Items.ps1')
[void]$sb.AppendLine('local _, ns = ...')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('ns.Items = {')
foreach ($id in $items.Keys) {
    [void]$sb.AppendLine("    [$id] = $(Format-LuaValue $items[$id]),")
}
[void]$sb.AppendLine('}')

Write-LuaFile $OutFile $sb.ToString()
Write-Host "Wrote $($items.Count) items to $((Resolve-Path $OutFile).Path)"
if ($missing) { Write-Host "Missing: $($missing -join ', ')" }
