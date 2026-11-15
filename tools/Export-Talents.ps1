<#
.SYNOPSIS
    Exports the WoW Forever talent trees of all classes into Data/Talents.lua.

.DESCRIPTION
    Forever classes have one talent tree with three spec sections side by side,
    like the classic talent window. This script reads the talent tree index of
    the Forever dataset (namespace static-forever-<region>) and writes, per
    class and spec, every talent node as { node ID, spell ID, ranks }. The
    addon counts the points per section to detect the spec (Core/Spec.lua) and
    reads the learned ranks for the stat weights (Classes/*.lua).

    Each node gets its max-rank text as a comment, for tuning the weights.
    The API dataset can be older than the live client: check values that
    matter against https://classicwowforever.com/talents/ before using them.

.EXAMPLE
    pwsh tools/Export-Talents.ps1
#>
[CmdletBinding()]
param(
    [string]$OutFile = (Join-Path $PSScriptRoot '..\Data\Talents.lua'),
    [ValidateSet('eu', 'us', 'kr', 'tw')]
    [string]$Region = 'eu',
    [string]$Locale = 'en_US'
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'BnetCommon.ps1')

# Playable class ID -> class token used by UnitClass("player")
$classTokens = @{
    1 = 'WARRIOR'; 2 = 'PALADIN'; 3 = 'HUNTER'; 4 = 'ROGUE'; 5 = 'PRIEST'
    6 = 'DEATHKNIGHT'; 7 = 'SHAMAN'; 8 = 'MAGE'; 9 = 'WARLOCK'; 10 = 'MONK'
    11 = 'DRUID'; 12 = 'DEMONHUNTER'; 13 = 'EVOKER'
}

function Get-TalentComment($node) {
    $last = $node.ranks | Select-Object -Last 1
    $name = $last.tooltip.talent.name
    $text = $last.tooltip.spell_tooltip.description
    if (-not $text) { return $name }
    $text = ($text -replace '\s+', ' ').Trim()
    if ($text.Length -gt 180) { $text = $text.Substring(0, 177) + '...' }
    return "${name}: $text"
}

Initialize-Bnet -Region $Region -Locale $Locale

$index = Invoke-BnetApi '/talent-tree/index'
$build = Get-BnetBuild $index

# class token -> @{ tree; specs = ordered list of @{ id; name; nodes } }
$classes = [ordered]@{}
$specTrees = $index.spec_talent_trees | ForEach-Object {
    if ($_.key.href -match 'talent-tree/(\d+)/playable-specialization/(\d+)') {
        [pscustomobject]@{ Tree = [int]$Matches[1]; Spec = [int]$Matches[2] }
    }
} | Sort-Object Tree, Spec

Write-Host "Exporting $($specTrees.Count) spec talent sections from $build ..."
foreach ($entry in $specTrees) {
    $data = Invoke-BnetApi "/talent-tree/$($entry.Tree)/playable-specialization/$($entry.Spec)"
    if (-not $data) { Write-Warning "Tree $($entry.Tree) spec $($entry.Spec) not found - skipped."; continue }
    $token = $classTokens[[int]$data.playable_class.id]
    if (-not $token) { Write-Warning "Unknown class $($data.playable_class.id) - skipped."; continue }
    if (-not $classes.Contains($token)) {
        $classes[$token] = @{ Tree = $entry.Tree; ClassId = [int]$data.playable_class.id; Specs = @() }
    }
    $nodes = foreach ($node in $data.spec_talent_nodes) {
        $first = $node.ranks | Select-Object -First 1
        $spell = $first.tooltip.spell_tooltip.spell.id
        if (-not $spell) { Write-Warning "Node $($node.id) has no spell - skipped."; continue }
        [pscustomobject]@{ Node = $node.id; Spell = $spell; Ranks = @($node.ranks).Count; Comment = Get-TalentComment $node }
    }
    $classes[$token].Specs += [pscustomobject]@{ Id = $entry.Spec; Name = $data.playable_specialization.name; Nodes = $nodes }
    Write-Host ("  {0,-8} {1,-18} {2,2} talents" -f $token, $data.playable_specialization.name, @($nodes).Count)
}

$sb = [Text.StringBuilder]::new()
[void]$sb.AppendLine('-- GENERATED FILE - do not edit by hand.')
[void]$sb.AppendLine("-- Source: Battle.net Game Data API, namespace $build, locale $Locale")
[void]$sb.AppendLine('-- Regenerate with: pwsh tools/Export-Talents.ps1')
[void]$sb.AppendLine('--')
[void]$sb.AppendLine('-- TalentData[CLASS] = { tree = talent tree ID, specs = { [spec ID] = { name = ..., nodes = {')
[void]$sb.AppendLine('--     { node ID, spell ID, ranks }, ... } } } }')
[void]$sb.AppendLine('-- The comment after a node is its max-rank text in this dataset; the live client')
[void]$sb.AppendLine('-- can be newer (see https://classicwowforever.com/talents/).')
[void]$sb.AppendLine('local _, ns = ...')
[void]$sb.AppendLine('')
[void]$sb.AppendLine('ns.TalentData = {')
foreach ($token in ($classes.Keys | Sort-Object { $classes[$_].ClassId })) {
    $class = $classes[$token]
    [void]$sb.AppendLine("    $token = {")
    [void]$sb.AppendLine("        tree = $($class.Tree),")
    [void]$sb.AppendLine('        specs = {')
    foreach ($spec in $class.Specs) {
        [void]$sb.AppendLine("            [$($spec.Id)] = {")
        [void]$sb.AppendLine("                name = $(ConvertTo-LuaString $spec.Name),")
        [void]$sb.AppendLine('                nodes = {')
        foreach ($n in $spec.Nodes) {
            [void]$sb.AppendLine("                    { $($n.Node), $($n.Spell), $($n.Ranks) },   -- $($n.Comment)")
        }
        [void]$sb.AppendLine('                },')
        [void]$sb.AppendLine('            },')
    }
    [void]$sb.AppendLine('        },')
    [void]$sb.AppendLine('    },')
}
[void]$sb.AppendLine('}')

Write-LuaFile $OutFile $sb.ToString()
Write-Host "Wrote $($classes.Count) classes to $((Resolve-Path $OutFile).Path)"
