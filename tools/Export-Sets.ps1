<#
.SYNOPSIS
    Exports all WoW Forever item sets (pieces and set bonuses) into Data/Sets.lua.

.DESCRIPTION
    Reads the item set index from the Forever dataset (namespace
    static-forever-<region>) and writes every set's name, item IDs and bonus
    effects. Set bonus texts are exported in English (en_US) by default because
    the addon parses them to rate bonuses like "+40 Attack Power".

.EXAMPLE
    pwsh tools/Export-Sets.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $PSScriptRoot '..\Data\Sets.lua'),
    [ValidateSet('eu', 'us', 'kr', 'tw')]
    [string]$Region = 'eu',
    [string]$Locale = 'en_US'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BnetCommon.ps1')

Initialize-Bnet -Region $Region -Locale $Locale

$index = Invoke-BnetApi '/item-set/index'
$build = Get-BnetBuild $index
$list  = $index.item_sets | Sort-Object id
Write-Host "Exporting $($list.Count) item sets from $build ..."

$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('-- GENERATED FILE - do not edit by hand.')
[void]$sb.AppendLine("-- Source: Battle.net Game Data API, namespace $build, locale $Locale")
[void]$sb.AppendLine('-- Regenerate with: pwsh tools/Export-Sets.ps1')
[void]$sb.AppendLine('local _, ns = ...')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('local sets = {')

$count = 0
foreach ($entry in $list) {
    $set = Invoke-BnetApi "/item-set/$($entry.id)"
    if (-not $set) { Write-Warning "Set $($entry.id) not found - skipped."; continue }

    $itemIds = @($set.items | ForEach-Object { [int]$_.id })
    $effects = @($set.effects | Sort-Object required_count | ForEach-Object {
        $text = $_.display_string -replace '^Set:\s*', ''
        "{ count = $($_.required_count), text = $(ConvertTo-LuaString $text) }"
    })

    [void]$sb.AppendLine("    [$($set.id)] = {")
    [void]$sb.AppendLine("        name = $(ConvertTo-LuaString $set.name),")
    [void]$sb.AppendLine("        items = { $($itemIds -join ', ') },")
    [void]$sb.AppendLine("        effects = { $($effects -join ', ') },")
    [void]$sb.AppendLine('    },')
    $count++
}

[void]$sb.AppendLine('}')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('-- Reverse lookup: item ID -> set ID')
[void]$sb.AppendLine('local itemToSet = {}')
[void]$sb.AppendLine('for setID, set in pairs(sets) do')
[void]$sb.AppendLine('    for _, itemID in ipairs(set.items) do itemToSet[itemID] = setID end')
[void]$sb.AppendLine('end')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('ns.SetData = { Sets = sets, ItemToSet = itemToSet }')

Write-LuaFile $OutFile $sb.ToString()
Write-Host "Wrote $count sets to $((Resolve-Path $OutFile).Path)"
