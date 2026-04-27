param(
    [string]$Url = "https://www.aurakingdom-db.com/charts/eidolon-archive",
    [string]$OutputHtml = "index.html",
    [string]$AssetsDir = "assets/eidolons",
    [switch]$KeepRemoteIcons
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Web

$GuideIconsDir = "assets/icons"
$DungeonGuideSheetUrl = "https://docs.google.com/spreadsheets/d/17pYlqk7__46yW7dDoClrQzK1hjJ85H7Hcvn0qYk7gHQ/gviz/tq?gid=0"
$DungeonGuideSheetPageUrl = "https://docs.google.com/spreadsheets/d/17pYlqk7__46yW7dDoClrQzK1hjJ85H7Hcvn0qYk7gHQ/edit?gid=0"
$DungeonGuideHardcodedFile = "dungeon_guide_hardcoded.json"
$GuideIconSources = @{
    "I80914.png" = "https://cdn.aurakingdom-db.com/images/icons/I80914.png"
    "I81010.png" = "https://cdn.aurakingdom-db.com/images/icons/I81010.png"
    "I80781.png" = "https://cdn.aurakingdom-db.com/images/icons/I80781.png"
    "I00469.png" = "https://cdn.aurakingdom-db.com/images/icons/I00469.png"
    "I00464.png" = "https://cdn.aurakingdom-db.com/images/icons/I00464.png"
    "I01677.png" = "https://cdn.aurakingdom-db.com/images/icons/I01677.png"
    "I02464.png" = "https://cdn.aurakingdom-db.com/images/icons/I02464.png"
    "I02465.png" = "https://cdn.aurakingdom-db.com/images/icons/I02465.png"
    "I02466.png" = "https://cdn.aurakingdom-db.com/images/icons/I02466.png"
    "I02540.png" = "https://cdn.aurakingdom-db.com/images/icons/I02540.png"
}

function Normalize-Key {
    param([string]$Text)
    return (($Text.ToLowerInvariant() -replace "[^a-z0-9]", "").Trim())
}

function Clean-Text {
    param([string]$Text)
    $clean = $Text -replace "<br\s*/?>", " " -replace "<[^>]+>", " "
    $clean = [System.Web.HttpUtility]::HtmlDecode($clean)
    return ($clean -replace "\s+", " ").Trim()
}

function Normalize-EidolonName {
    param([string]$Name)

    if (-not $Name) {
        return $Name
    }

    $map = @{
        "H鐰ur" = "Hödur"
    }

    if ($map.ContainsKey($Name)) {
        return $map[$Name]
    }

    return $Name
}

function Get-Category {
    param([string]$Star3)

    $s = $Star3.Trim()

    if ($s -match "^PEN\b") { return "PEN" }
    if ($s -match "^All stats\b|^Mighty\b") { return "ALL STATS RAISED" }
    if ($s -match "^Main weapon damage increased by|^Main Weapon DMG") { return "MAIN WEAPON DAMAGE" }
    if ($s -match "^Max CRIT DMG") { return "MAX CRIT DMG" }
    if ($s -match "^CRIT DMG to Boss") { return "CDMG AGAINST BOSSES" }
    if ($s -match "^CRIT DMG to Players") { return "CDMG AGAINST PLAYERS" }
    if ($s -match "^CRIT DMG\b") { return "CRIT DMG" }
    if ($s -match "^Max DMG dealt") { return "MAX DMG DEALT" }
    if ($s -match "^DMG dealt to Elites") { return "DMG AGAINST ELITES" }
    if ($s -match "^DMG dealt to Boss Monsters") { return "DMG AGAINST BOSSES" }
    if ($s -match "^DMG dealt to Players") { return "DMG AGAINST PLAYERS" }
    if ($s -match "^DMG taken from Elites") { return "DMG TAKEN FROM ELITES" }
    if ($s -match "^DMG taken from Boss Monsters") { return "DMG TAKEN FROM BOSSES" }
    if ($s -match "^DMG taken from Players") { return "DMG TAKEN FROM PLAYERS" }
    if ($s -match "^DMG dealt\b") { return "DMG DEALT" }
    if ($s -match "^DMG taken\b") { return "DMG TAKEN" }
    if ($s -match "^Combo chance") { return "COMBO CHANCE" }
    if ($s -match "^Normal ATK SPD") { return "NORMAL ATTACK SPEED" }
    if ($s -match "^Move SPD") { return "MOVE SPEED" }
    if ($s -match "^Armor Piercing") { return "ARMOR PIERCING" }
    if ($s -match "^Damage of (.+?) Skills") { return ("{0} SKILLS" -f $Matches[1].ToUpper()) }
    if ($s -match "^DMG \+\d+% against (.+?) targets") { return ("DMG AGAINST {0} TARGETS" -f $Matches[1].ToUpper()) }
    if ($s -match "^ACC\b") { return "ACCURACY" }
    if ($s -match "^Holy DMG taken") { return "HOLY DMG TAKEN" }
    if ($s -match "^Ice attribute penetration DMG taken") { return "ICE PEN RESIST" }
    if ($s -match "^Ice attribute skill penetration effect") { return "ICE PEN EFFECT" }
    if ($s -match "^Holy attribute skill penetration effect") { return "HOLY PEN EFFECT" }

    return "OTHER"
}

function Get-Numeric {
    param([string]$Text)

    $m = [regex]::Match($Text, "([-+]?\d+(?:\.\d+)?)\s*%?")
    if ($m.Success) {
        return [double]$m.Groups[1].Value
    }

    return 0.0
}

function Get-Local-Icon {
    param(
        [string]$RemoteUrl,
        [hashtable]$IconMap
    )

    if (-not $RemoteUrl) {
        return ""
    }

    if ($IconMap.ContainsKey($RemoteUrl)) {
        return $IconMap[$RemoteUrl]
    }

    return $RemoteUrl
}

function Get-ComboOverride {
    param(
        [array]$Eidolons,
        [string]$Star3,
        [string]$Star4
    )

    $normalizedNames = @($Eidolons | ForEach-Object { Normalize-Key $_.Name })

    # Source data bug: this combo can come with 3* Max CRIT DMG and 4* Main Weapon DMG.
    # Force both tiers to Max CRIT DMG for the affected Christmas Little Red Riding Hood + Yarnaros + Christmas Andrea variant.
    if (
        ($normalizedNames -contains "christmaslittleredridinghood") -and
        ($normalizedNames -contains "yarnaros") -and
        ($normalizedNames -contains "christmasandrea") -and
        ($Star3 -match "^Max CRIT DMG") -and
        ($Star4 -match "^Main Weapon DMG")
    ) {
        return [pscustomobject]@{
            Category = "MAX CRIT DMG"
            Star3 = "Max CRIT DMG +2%"
            Star4 = "Max CRIT DMG +4%"
        }
    }

    $comboKey = (($normalizedNames | Sort-Object) -join "|")

    switch ($comboKey) {
        "faust|summerguanyu|summershutendoji" {
            return [pscustomobject]@{
                Category = "MAX CRIT DMG"
                Star3 = "Max CRIT DMG +4%"
                Star4 = "Max CRIT DMG +8%"
            }
        }
        "bealdor|mary|pan" {
            return [pscustomobject]@{
                Category = "HOLY PEN EFFECT"
                Star3 = "Holy attribute skill penetration effect +2%"
                Star4 = "Holy attribute skill penetration effect +4%"
            }
        }
    }

    return [pscustomobject]@{
        Category = Get-Category $Star3
        Star3 = $Star3
        Star4 = $Star4
    }
}

function Get-DungeonGuideItems {
    param(
        [string]$SheetUrl,
        [array]$KnownEidolonNames = @()
    )

    $manualDungeonSources = @{
        "Hebe" = @("Whirlpool Abyss II")
        "Cerberus" = @("Infernal Abyss II")
        "Izanami" = @("Avarice Abyss II")
        "Michaela" = @("Abyss of Light II")
        "Demeter" = @("Hurricane Abyss II")
        "Hermes" = @("Thundering Abyss II")
        "Justicia" = @("Vault of Eternity - Chapter 11 (Party)")
    }

    $mainStoryEidolons = @(
        "Gigas", "Aelius", "Abraxas", "Benkei", "Faust", "Eligos", "Sigrun", "Nalani", "Uzuriel", "Tanith",
        "Maja", "Bel-Chandra", "Vayu", "Nazrudin", "Yarnaros", "Ghodroon", "Quelkulan", "Zaahir", "Cyril", "Kotonoha",
        "Tigerius Caesar", "Bahadur", "Tsubaki", "Cleopawtra", "Serena", "Endora", "Vermilion", "Shirayuki", "Kaiser", "Zeta",
        "Hel", "Alucard", "Bealdor", "Kusanagi", "Hansel & Gretel", "Astraea", "Cesela", "Diao-Chan", "Uriel", "Amaterasu",
        "Alice", "Ayako"
    )

    $response = Invoke-WebRequest -Uri $SheetUrl -UseBasicParsing
    $raw = $response.Content
    $jsonMatch = [regex]::Match($raw, "setResponse\((?<json>[\s\S]+)\);")
    if (-not $jsonMatch.Success) {
        throw "Could not parse dungeon guide source payload."
    }

    $payload = $jsonMatch.Groups["json"].Value | ConvertFrom-Json
    if (-not $payload.table -or -not $payload.table.rows) {
        return @()
    }

    $results = New-Object System.Collections.Generic.List[object]

    $mainStoryNameLabel = ""
    $mainStoryDungeonLabel = ""
    if ($payload.table.cols -and $payload.table.cols.Count -ge 8) {
        $mainStoryNameLabel = [string]$payload.table.cols[2].label
        $mainStoryDungeonLabel = [string]$payload.table.cols[7].label
    }

    foreach ($row in $payload.table.rows) {
        if (-not $row.c -or $row.c.Count -lt 8) {
            continue
        }

        $nameCell = $row.c[2]
        $locationCell = $row.c[7]
        if ($null -eq $nameCell -or $null -eq $locationCell) {
            continue
        }

        $rawName = [string]$nameCell.v
        $locations = [string]$locationCell.v
        if (-not $rawName -or -not $locations) {
            continue
        }

        $name = (($rawName -split "\r?\n")[0]).Trim()
        if ($name -match "^\?+$" -or $name -match "^Upcoming") {
            continue
        }

        if ($locations.Trim().ToUpperInvariant() -eq "N/A") {
            continue
        }

        $sourceLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in ($locations -split "\r?\n")) {
            $cleanLine = ($line -replace "^-+\s*", "").Trim()
            if (-not $cleanLine) {
                continue
            }

            if (-not $sourceLines.Contains($cleanLine)) {
                [void]$sourceLines.Add($cleanLine)
            }
        }

        $namesToAdd = New-Object System.Collections.Generic.List[string]
        if ($rawName -match "(?i)Main Story Eidolon") {
            foreach ($storyName in $mainStoryEidolons) {
                if (-not $storyName) {
                    continue
                }

                $escapedName = [regex]::Escape([string]$storyName)
                if ($rawName -match (("(?i)(^|[^A-Za-z0-9])" + $escapedName + "([^A-Za-z0-9]|$)"))) {
                    if (-not $namesToAdd.Contains([string]$storyName)) {
                        [void]$namesToAdd.Add([string]$storyName)
                    }
                }
            }

            if ($KnownEidolonNames -and $KnownEidolonNames.Count -gt 0) {
                foreach ($knownName in ($KnownEidolonNames | Sort-Object { $_.Length } -Descending)) {
                    if (-not $knownName) {
                        continue
                    }

                    $escapedName = [regex]::Escape([string]$knownName)
                    if ($rawName -match (("(?i)(^|[^A-Za-z0-9])" + $escapedName + "([^A-Za-z0-9]|$)"))) {
                        if (-not $namesToAdd.Contains([string]$knownName)) {
                            [void]$namesToAdd.Add([string]$knownName)
                        }
                    }
                }
            }
        } else {
            [void]$namesToAdd.Add($name)
        }

        if ($sourceLines.Count -gt 0) {
            foreach ($nameToAdd in $namesToAdd) {
                $entryLines = New-Object System.Collections.Generic.List[string]
                foreach ($lineToAdd in $sourceLines) {
                    [void]$entryLines.Add($lineToAdd)
                }

                if ($manualDungeonSources.ContainsKey($nameToAdd)) {
                    foreach ($manualSource in $manualDungeonSources[$nameToAdd]) {
                        if (-not $entryLines.Contains($manualSource)) {
                            [void]$entryLines.Add($manualSource)
                        }
                    }
                }

                $results.Add([pscustomobject]@{
                    Name = $nameToAdd
                    Locations = @($entryLines)
                })
            }
        }
    }

    if ($mainStoryNameLabel -match "(?i)Main Story Eidolon" -and $mainStoryDungeonLabel -and $mainStoryDungeonLabel.Trim().ToUpperInvariant() -ne "N/A") {
        $mainStorySummaryLines = @(
            "Main Story Eidolon (Dungeon source available).",
            "Check the original spreadsheet for the exact dungeon route for this Eidolon."
        )

        foreach ($storyName in $mainStoryEidolons) {
            if (-not $storyName) {
                continue
            }

            $escapedName = [regex]::Escape([string]$storyName)
            if ($mainStoryNameLabel -match (("(?i)(^|[^A-Za-z0-9])" + $escapedName + "([^A-Za-z0-9]|$)"))) {
                $results.Add([pscustomobject]@{
                    Name = $storyName
                    Locations = @($mainStorySummaryLines)
                })
            }
        }
    }

    foreach ($manualName in $manualDungeonSources.Keys) {
        $existing = $results | Where-Object { $_.Name -eq $manualName } | Select-Object -First 1
        if ($null -eq $existing) {
            $results.Add([pscustomobject]@{
                Name = $manualName
                Locations = @($manualDungeonSources[$manualName])
            })
            continue
        }

        foreach ($manualSource in $manualDungeonSources[$manualName]) {
            if (-not ($existing.Locations -contains $manualSource)) {
                $existing.Locations = @($existing.Locations + $manualSource)
            }
        }
    }

    return @($results | Sort-Object Name)
}

function Get-DungeonGuideItemsFromSheetPage {
    param(
        [string]$SheetPageUrl,
        [string[]]$KnownEidolonNames = @()
    )

    $response = Invoke-WebRequest -Uri $SheetPageUrl -UseBasicParsing
    $raw = $response.Content
    if (-not $raw) {
        return @()
    }

    $manualDungeonSources = @{
        "Hebe" = @("Whirlpool Abyss II")
        "Cerberus" = @("Infernal Abyss II")
        "Izanami" = @("Avarice Abyss II")
        "Michaela" = @("Abyss of Light II")
        "Demeter" = @("Hurricane Abyss II")
        "Hermes" = @("Thundering Abyss II")
        "Justicia" = @("Vault of Eternity - Chapter 11 (Party)")
    }
    $results = New-Object System.Collections.Generic.List[object]
    $itemsByName = @{}
    $knownNameMap = @{}
    foreach ($known in @($KnownEidolonNames)) {
        $normalizedKnown = ([string]$known).Trim().ToLowerInvariant()
        if ($normalizedKnown) {
            $knownNameMap[$normalizedKnown] = $true
        }
    }

    $rows = [regex]::Matches($raw, '<tr\b[^>]*>(?<inner>[\s\S]*?)</tr>')
    foreach ($row in $rows) {
        $cells = [regex]::Matches($row.Groups["inner"].Value, '<td\b(?<attrs>[^>]*)>(?<inner>[\s\S]*?)</td>')
        if ($cells.Count -eq 0) {
            continue
        }

        $colMap = @{}
        $cursor = 0
        foreach ($cell in $cells) {
            $attrs = [string]$cell.Groups["attrs"].Value
            $inner = [string]$cell.Groups["inner"].Value

            $colspan = 1
            $colspanMatch = [regex]::Match($attrs, 'colspan\s*=\s*"(?<n>\d+)"')
            if ($colspanMatch.Success) {
                $colspan = [int]$colspanMatch.Groups["n"].Value
            }

            $text = ($inner -replace '<br\s*/?>', "`n")
            $text = ($text -replace '<[^>]+>', '')
            $text = [System.Web.HttpUtility]::HtmlDecode($text)
            $text = ($text -replace '[\u00a0]+', ' ').Trim()

            for ($i = 0; $i -lt $colspan; $i++) {
                $colMap[$cursor + $i] = $text
            }
            $cursor += $colspan
        }

        $nameRaw = $null
        foreach ($nameCol in 2..4) {
            if ($colMap.ContainsKey($nameCol)) {
                $candidate = [string]$colMap[$nameCol]
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $nameRaw = $candidate
                    break
                }
            }
        }

        $dungeonRaw = $null
        foreach ($dungeonCol in 7..13) {
            if ($colMap.ContainsKey($dungeonCol)) {
                $candidate = [string]$colMap[$dungeonCol]
                if (-not [string]::IsNullOrWhiteSpace($candidate)) {
                    $dungeonRaw = $candidate
                    break
                }
            }
        }

        if (-not $nameRaw -or -not $dungeonRaw) {
            continue
        }

        $name = (($nameRaw -split "\r?\n")[0]).Trim()
        if (-not $name -or $name -eq "Eidolon" -or $name -match "^\?+$" -or $name -match "^Upcoming" -or $name -match "(?i)^Main Story Eidolon") {
            continue
        }

        if ($name -match '^(Green\s*=|Blue\s*=|Eidolon Spawn/Fragment Locations|Color legend and notes:)$') {
            continue
        }

        if ($knownNameMap.Count -gt 0) {
            $normalizedName = $name.ToLowerInvariant()
            if (-not $knownNameMap.ContainsKey($normalizedName)) {
                continue
            }
        }

        if ($dungeonRaw.Trim().ToUpperInvariant() -eq "N/A") {
            continue
        }

        $sourceLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in ($dungeonRaw -split "\r?\n")) {
            $cleanLine = ($line -replace "^-+\s*", "").Trim()
            if ($cleanLine -and -not $sourceLines.Contains($cleanLine)) {
                [void]$sourceLines.Add($cleanLine)
            }
        }

        if ($sourceLines.Count -eq 0) {
            continue
        }

        if (-not $itemsByName.ContainsKey($name)) {
            $itemsByName[$name] = New-Object System.Collections.Generic.List[string]
        }
        foreach ($source in $sourceLines) {
            if (-not $itemsByName[$name].Contains($source)) {
                [void]$itemsByName[$name].Add($source)
            }
        }
    }

    foreach ($name in ($itemsByName.Keys | Sort-Object)) {
        $sourceLines = New-Object System.Collections.Generic.List[string]
        foreach ($line in @($itemsByName[$name])) {
            if (-not [string]::IsNullOrWhiteSpace($line) -and -not $sourceLines.Contains($line)) {
                [void]$sourceLines.Add($line)
            }
        }

        if ($manualDungeonSources.ContainsKey($name)) {
            foreach ($manualSource in $manualDungeonSources[$name]) {
                if (-not $sourceLines.Contains($manualSource)) {
                    [void]$sourceLines.Add($manualSource)
                }
            }
        }

        if ($sourceLines.Count -gt 0) {
            $results.Add([pscustomobject]@{
                Name = $name
                Locations = @($sourceLines)
            })
        }
    }

    foreach ($manualName in $manualDungeonSources.Keys) {
        $existing = $results | Where-Object { $_.Name -eq $manualName } | Select-Object -First 1
        if ($null -eq $existing) {
            $results.Add([pscustomobject]@{
                Name = $manualName
                Locations = @($manualDungeonSources[$manualName])
            })
            continue
        }

        foreach ($manualSource in $manualDungeonSources[$manualName]) {
            if (-not ($existing.Locations -contains $manualSource)) {
                $existing.Locations = @($existing.Locations + $manualSource)
            }
        }
    }

    return @($results | Sort-Object Name)
}

function Get-HardcodedDungeonGuideItems {
    param([string]$FilePath)

    if (-not (Test-Path $FilePath)) {
        return @()
    }

    $raw = Get-Content -Path $FilePath -Raw
    if (-not $raw) {
        return @()
    }

    $parsed = $raw | ConvertFrom-Json
    $normalized = New-Object System.Collections.Generic.List[object]

    foreach ($item in @($parsed)) {
        if (-not $item.Name -or -not $item.Locations) {
            continue
        }

        $locs = New-Object System.Collections.Generic.List[string]
        foreach ($loc in @($item.Locations)) {
            $cleanLoc = ([string]$loc).Trim()
            if ($cleanLoc -and -not $locs.Contains($cleanLoc)) {
                [void]$locs.Add($cleanLoc)
            }
        }

        if ($locs.Count -gt 0) {
            $normalized.Add([pscustomobject]@{
                Name = ([string]$item.Name).Trim()
                Locations = @($locs)
            })
        }
    }

    return @($normalized | Sort-Object Name)
}

function Merge-DungeonGuideItems {
    param(
        [array]$PrimaryItems,
        [array]$FallbackItems
    )

    $mergedMap = @{}

    foreach ($entry in @($FallbackItems) + @($PrimaryItems)) {
        if (-not $entry -or -not $entry.Name) {
            continue
        }

        $name = ([string]$entry.Name).Trim()
        if (-not $name) {
            continue
        }

        $key = Normalize-Key $name
        if (-not $mergedMap.ContainsKey($key)) {
            $mergedMap[$key] = [pscustomobject]@{
                Name = $name
                Locations = @()
            }
        }

        foreach ($loc in @($entry.Locations)) {
            $cleanLoc = ([string]$loc).Trim()
            if ($cleanLoc -and -not ($mergedMap[$key].Locations -contains $cleanLoc)) {
                $mergedMap[$key].Locations = @($mergedMap[$key].Locations + $cleanLoc)
            }
        }
    }

    return @($mergedMap.Values | Sort-Object Name)
}

function Build-PageHtml {
    param(
        [array]$Rows,
        [hashtable]$IconMap,
        [array]$DungeonGuideItems
    )

    $dungeonGuideIconMap = @{}
    foreach ($row in $Rows) {
        foreach ($eid in $row.Eidolons) {
            $normalized = Normalize-Key $eid.Name
            if (-not $normalized -or $dungeonGuideIconMap.ContainsKey($normalized)) {
                continue
            }

            $iconPath = Get-Local-Icon -RemoteUrl $eid.IconUrl -IconMap $IconMap
            if ($iconPath) {
                $dungeonGuideIconMap[$normalized] = $iconPath
            }
        }
    }

    $preferredOrder = @(
        "PEN",
        "ALL STATS RAISED",
        "MAIN WEAPON DAMAGE",
        "MAX CRIT DMG",
        "CRIT DMG",
        "MAX DMG DEALT",
        "DMG DEALT",
        "DMG TAKEN",
        "COMBO CHANCE",
        "NORMAL ATTACK SPEED",
        "MOVE SPEED",
        "ARMOR PIERCING",
        "FLAME SKILLS",
        "PHYSICAL SKILLS",
        "HOLY SKILLS",
        "STORM SKILLS",
        "LIGHTNING SKILLS",
        "ICE SKILLS",
        "DARK SKILLS",
        "DMG AGAINST ELITES",
        "DMG AGAINST BOSSES",
        "CDMG AGAINST BOSSES",
        "CDMG AGAINST PLAYERS",
        "DMG AGAINST PLAYERS",
        "DMG TAKEN FROM ELITES",
        "DMG TAKEN FROM BOSSES",
        "DMG TAKEN FROM PLAYERS",
        "DMG AGAINST FLAME TARGETS",
        "DMG AGAINST HOLY TARGETS",
        "DMG AGAINST STORM TARGETS",
        "DMG AGAINST LIGHTNING TARGETS",
        "DMG AGAINST ICE TARGETS",
        "DMG AGAINST DARK TARGETS",
        "ACCURACY",
        "HOLY DMG TAKEN",
        "ICE PEN RESIST",
        "ICE PEN EFFECT",
        "HOLY PEN EFFECT",
        "OTHER"
    )

    $groups = $Rows | Group-Object Category
    $groupMap = @{}
    foreach ($g in $groups) {
        $groupMap[$g.Name] = $g.Group
    }

    $orderedCats = @()
    foreach ($cat in $preferredOrder) {
        if ($groupMap.ContainsKey($cat)) {
            $orderedCats += $cat
        }
    }

    foreach ($cat in ($groups.Name | Sort-Object)) {
        if ($orderedCats -notcontains $cat) {
            $orderedCats += $cat
        }
    }

    $sb = New-Object System.Text.StringBuilder

    [void]$sb.AppendLine("<!doctype html>")
    [void]$sb.AppendLine("<html lang=`"en`" translate=`"no`">")
    [void]$sb.AppendLine("<head>")
    [void]$sb.AppendLine("  <meta charset=`"utf-8`">")
    [void]$sb.AppendLine("  <meta name=`"viewport`" content=`"width=device-width, initial-scale=1`">")
    [void]$sb.AppendLine("  <meta name=`"google`" content=`"notranslate`">")
    [void]$sb.AppendLine("  <title>Eidolon Archive</title>")
    [void]$sb.AppendLine("  <style>")
    [void]$sb.AppendLine("    :root { --bg:#0f141d; --bg-top:#1a2230; --card:#161e2a; --ink:#e8edf5; --muted:#9aa8bc; --line:#2a3446; --accent:#7cc8ff; --th-bg:#1c2736; --chip-bg:#202b3b; --chip-line:#33455f; --icon-bg:#101722; --icon-line:#3a4d69; --input-bg:#121a26; --input-ink:#e8edf5; }")
    [void]$sb.AppendLine("    body[data-theme='light'] { --bg:#fff6ef; --bg-top:#fffdf8; --card:#fffdf9; --ink:#2d1f1a; --muted:#6c5a53; --line:#efddd3; --accent:#cc5f2e; --th-bg:#fff4ec; --chip-bg:#fff7f1; --chip-line:#f0dfd5; --icon-bg:#ffffff; --icon-line:#e8d3c7; --input-bg:#ffffff; --input-ink:#2d1f1a; }")
    [void]$sb.AppendLine("    * { box-sizing:border-box; }")
    [void]$sb.AppendLine("    html { background-color:#0f141d; overflow-x:hidden; } body { margin:0; font-family: `"Segoe UI`", Tahoma, sans-serif; background: radial-gradient(circle at top, var(--bg-top), var(--bg)); color:var(--ink); overflow-x:hidden; } body[data-theme='light'] { background-color:#fff6ef; }")
    [void]$sb.AppendLine("    .wrap { width:min(1100px, 94vw); margin: 8px auto 24px; }")
    [void]$sb.AppendLine("    h1 { margin:0 0 2px; font-size: clamp(1rem, 2vw, 1.4rem); }")
    [void]$sb.AppendLine("    p { margin:0; color:var(--muted); font-size:0.85rem; }")
    [void]$sb.AppendLine("    .topbar { position: sticky; top:0; z-index:10; padding:6px 0; backdrop-filter: blur(6px); background: color-mix(in srgb, var(--bg-top) 78%, transparent); border-bottom:1px solid var(--line); margin-bottom:8px; }")
    [void]$sb.AppendLine("    .search { width:100%; border:1px solid var(--line); border-radius:10px; padding:6px 10px; font-size:0.9rem; background:var(--input-bg); color:var(--input-ink); }")
    [void]$sb.AppendLine("    .section { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px; margin-top:14px; box-shadow:0 8px 22px rgba(0,0,0,.28); overflow-x:auto; }")
    [void]$sb.AppendLine("    .section h2 { margin:0 0 10px; color:var(--accent); font-size:1.05rem; letter-spacing:.2px; }")
    [void]$sb.AppendLine("    table { width:100%; border-collapse: collapse; font-size:0.9rem; }")
    [void]$sb.AppendLine("    th, td { border:1px solid var(--line); padding:8px; vertical-align:top; text-align:left; }")
    [void]$sb.AppendLine("    th { background:var(--th-bg); }")
    [void]$sb.AppendLine("    .totals { margin-top:8px; font-size:0.88rem; color:var(--muted); font-weight:600; }")
    [void]$sb.AppendLine("    .hide { display:none !important; }")
    [void]$sb.AppendLine("    .combo-list { display:flex; flex-wrap:wrap; align-items:center; gap:6px; }")
    [void]$sb.AppendLine("    .combo-item { display:inline-flex; align-items:center; gap:6px; background:var(--chip-bg); border:1px solid var(--chip-line); border-radius:999px; padding:3px 8px 3px 4px; }")
    [void]$sb.AppendLine("    .eido-icon { width:24px; height:24px; border-radius:50%; object-fit:cover; border:1px solid var(--icon-line); background:var(--icon-bg); }")
    [void]$sb.AppendLine("    .eido-missing { display:inline-flex; align-items:center; justify-content:center; font-size:12px; color:#8e6f61; }")
    [void]$sb.AppendLine("    .combo-sep { color:var(--muted); font-weight:700; }")
    [void]$sb.AppendLine("    .top-row { display:flex; align-items:flex-start; justify-content:space-between; gap:12px; margin-bottom:8px; }")
    [void]$sb.AppendLine("    .top-actions { display:flex; align-items:center; gap:8px; flex-wrap:wrap; justify-content:flex-end; }")
    [void]$sb.AppendLine("    .info-menu { position:relative; }")
    [void]$sb.AppendLine("    .info-menu-toggle { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 12px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:700; list-style:none; user-select:none; }")
    [void]$sb.AppendLine("    .info-menu-toggle:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .info-menu-toggle::-webkit-details-marker { display:none; }")
    [void]$sb.AppendLine("    .info-menu-panel { position:absolute; right:0; top:46px; width:min(340px, 90vw); padding:10px; border:1px solid var(--line); border-radius:12px; background:var(--card); box-shadow:0 14px 30px rgba(0,0,0,.35); display:none; z-index:25; }")
    [void]$sb.AppendLine("    .info-menu[open] .info-menu-panel { display:grid; gap:8px; }")
    [void]$sb.AppendLine("    .info-menu-panel .lucky-pack-btn, .info-menu-panel .wish-coin-btn, .info-menu-panel .limit-break-btn, .info-menu-panel .dungeon-guide-btn, .info-menu-panel .leveling-guide-btn { width:100%; justify-content:flex-start; }")
    [void]$sb.AppendLine("    .lucky-pack-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .lucky-pack-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .lucky-pack-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .wish-coin-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .wish-coin-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .limit-break-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .limit-break-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .leveling-guide-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .leveling-guide-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .theme-toggle { width:40px; height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; }")
    [void]$sb.AppendLine("    .theme-toggle:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .theme-icon { font-size:18px; line-height:1; }")
    [void]$sb.AppendLine("    .lucky-pack-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .lucky-pack-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .lucky-pack-modal { width:min(680px, 96vw); background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .lucky-pack-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .lucky-pack-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .lucky-pack-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .lucky-pack-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .lucky-pack-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .lucky-pack-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .lucky-pack-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .wish-coin-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .wish-coin-modal { width:min(680px, 96vw); background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .wish-coin-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .wish-coin-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .wish-coin-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .wish-coin-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .wish-coin-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .wish-coin-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .limit-break-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .limit-break-modal { width:min(680px, 96vw); background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .limit-break-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .limit-break-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .limit-break-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .limit-break-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .limit-break-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .limit-break-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .leveling-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .leveling-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .leveling-guide-modal { width:min(760px, 96vw); background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .leveling-guide-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .leveling-guide-modal p { margin:0 0 8px; color:var(--muted); }")
    [void]$sb.AppendLine("    .leveling-guide-list { margin:8px 0 0; padding:0; list-style:none; display:grid; gap:8px; }")
    [void]$sb.AppendLine("    .leveling-guide-list li { display:flex; align-items:center; justify-content:space-between; gap:10px; border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:8px 10px; }")
    [void]$sb.AppendLine("    .leveling-guide-item { display:flex; align-items:center; gap:8px; }")
    [void]$sb.AppendLine("    .leveling-guide-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .leveling-guide-qty { font-weight:700; color:var(--ink); }")
    [void]$sb.AppendLine("    .skill-leveling-box { margin-top:12px; border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:10px; }")
    [void]$sb.AppendLine("    .skill-leveling-head { display:flex; align-items:center; gap:8px; margin-bottom:6px; }")
    [void]$sb.AppendLine("    .skill-leveling-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .skill-leveling-title { margin:0; font-size:0.92rem; color:var(--ink); }")
    [void]$sb.AppendLine("    .skill-leveling-grid { margin:8px 0 0; padding:0; list-style:none; display:grid; grid-template-columns:repeat(2, minmax(0, 1fr)); gap:8px; }")
    [void]$sb.AppendLine("    .skill-leveling-grid li { border:1px solid var(--line); border-radius:10px; padding:8px; background:var(--card); display:flex; align-items:center; justify-content:space-between; gap:8px; }")
    [void]$sb.AppendLine("    .quality-chip { display:inline-flex; align-items:center; border-radius:999px; padding:2px 8px; font-size:0.76rem; font-weight:700; }")
    [void]$sb.AppendLine("    .q-green { background:#1f9d55; color:#fff; }")
    [void]$sb.AppendLine("    .q-blue { background:#1e62d0; color:#fff; }")
    [void]$sb.AppendLine("    .q-orange { background:#d97706; color:#fff; }")
    [void]$sb.AppendLine("    .q-purple { background:#7e3af2; color:#fff; }")
    [void]$sb.AppendLine("    .q-gold { background:#c89b22; color:#1f1a0e; }")
    [void]$sb.AppendLine("    .skill-total { margin-top:8px; font-size:0.84rem; color:var(--ink); font-weight:700; }")
    [void]$sb.AppendLine("    .leveling-guide-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .leveling-guide-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .leveling-guide-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .dungeon-guide-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .dungeon-guide-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .dungeon-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .dungeon-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .dungeon-guide-modal { width:min(920px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .dungeon-guide-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .dungeon-guide-modal p { margin:0 0 10px; color:var(--muted); font-size:0.9rem; }")
    [void]$sb.AppendLine("    .dungeon-guide-modal p a { color:var(--accent); text-decoration:underline; text-underline-offset:2px; font-weight:600; }")
    [void]$sb.AppendLine("    .dungeon-guide-modal p a:hover { filter:brightness(1.12); }")
    [void]$sb.AppendLine("    .dungeon-guide-list { display:grid; grid-template-columns:repeat(auto-fit, minmax(230px, 1fr)); gap:10px; margin-top:10px; }")
    [void]$sb.AppendLine("    .dungeon-guide-item { border:1px solid var(--line); border-radius:10px; padding:8px; background:var(--chip-bg); }")
    [void]$sb.AppendLine("    .dungeon-guide-head { display:flex; align-items:center; gap:8px; margin-bottom:6px; }")
    [void]$sb.AppendLine("    .dungeon-guide-icon { width:24px; height:24px; border-radius:50%; object-fit:cover; border:1px solid var(--icon-line); background:var(--icon-bg); flex:0 0 auto; }")
    [void]$sb.AppendLine("    .dungeon-guide-item h4 { margin:0 0 6px; font-size:0.9rem; color:var(--ink); }")
    [void]$sb.AppendLine("    .dungeon-guide-item ul { margin:0; padding-left:18px; }")
    [void]$sb.AppendLine("    .dungeon-guide-item li { margin:3px 0; color:var(--muted); font-size:0.82rem; }")
    [void]$sb.AppendLine("    .dungeon-guide-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .dungeon-guide-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .dungeon-guide-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    @media (max-width:760px) { .top-row { align-items:stretch; flex-direction:column; } .top-actions { width:100%; justify-content:flex-start; } .lucky-pack-btn, .wish-coin-btn, .limit-break-btn, .dungeon-guide-btn, .leveling-guide-btn { min-height:40px; padding:6px 10px; } .theme-toggle { flex:0 0 auto; } .info-menu-panel { position:static; width:100%; margin-top:8px; } .dungeon-guide-list { grid-template-columns:1fr; } .leveling-guide-list li { align-items:flex-start; flex-direction:column; } .skill-leveling-grid { grid-template-columns:1fr; } th, td { padding:7px 6px; font-size:0.84rem; } }")
    [void]$sb.AppendLine("  </style>")
    [void]$sb.AppendLine("</head>")
    [void]$sb.AppendLine("<body style=`"background-color:#0f141d`">")
    [void]$sb.AppendLine("  <div class=`"topbar`"><div class=`"wrap`">")
    [void]$sb.AppendLine("    <div class=`"top-row`">")
    [void]$sb.AppendLine("      <div>")
    [void]$sb.AppendLine("        <h1>Eidolon Archive</h1>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"top-actions`">")
    [void]$sb.AppendLine("        <details class=`"info-menu`">")
    [void]$sb.AppendLine("          <summary class=`"info-menu-toggle`" aria-label=`"Open info menu`">Guides ▾</summary>")
    [void]$sb.AppendLine("          <div class=`"info-menu-panel`">")
    [void]$sb.AppendLine("            <button id=`"luckyPackInfoBtn`" class=`"lucky-pack-btn`" type=`"button`" title=`"What are Eidolon Lucky Packs?`" aria-label=`"What are Eidolon Lucky Packs?`">What is <img class=`"lucky-pack-icon`" src=`"assets/icons/I80914.png`" alt=`"Eidolon Lucky Pack`">?</button>")
    [void]$sb.AppendLine("            <button id=`"wishCoinInfoBtn`" class=`"wish-coin-btn`" type=`"button`" title=`"What are Eidolon Wish Coins?`" aria-label=`"What are Eidolon Wish Coins?`">What is <img class=`"wish-coin-icon`" src=`"assets/icons/I81010.png`" alt=`"Eidolon Wish Coin`">?</button>")
    [void]$sb.AppendLine("            <button id=`"limitBreakInfoBtn`" class=`"limit-break-btn`" type=`"button`" title=`"What are Card Breakthrough Devices?`" aria-label=`"What are Card Breakthrough Devices?`">What is <img class=`"limit-break-icon`" src=`"assets/icons/I80781.png`" alt=`"Card Breakthrough Device`">?</button>")
    [void]$sb.AppendLine("            <button id=`"levelingGuideInfoBtn`" class=`"leveling-guide-btn`" type=`"button`" title=`"How to level Eidolons from 25 to 80?`" aria-label=`"How to level Eidolons from 25 to 80?`">Eidolon Leveling</button>")
    [void]$sb.AppendLine("            <button id=`"dungeonGuideInfoBtn`" class=`"dungeon-guide-btn`" type=`"button`" title=`"Where can I find Eidolon spawn locations?`" aria-label=`"Where can I find Eidolon spawn locations?`">Eidolon Spawn Location</button>")
    [void]$sb.AppendLine("          </div>")
    [void]$sb.AppendLine("        </details>")
    [void]$sb.AppendLine("        <button id=`"themeToggle`" class=`"theme-toggle`" type=`"button`" aria-label=`"Switch to light theme`" title=`"Switch to light theme`"><span id=`"themeIcon`" class=`"theme-icon`">☀</span></button>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("    <input id=`"q`" class=`"search`" placeholder=`"Search by Eidolon, combo or bonus...`" title=`"Type to filter combos by Eidolon, combo, or bonus`" aria-label=`"Search combos`">")
    [void]$sb.AppendLine("  </div></div>")
    [void]$sb.AppendLine("  <div id=`"luckyPackModal`" class=`"lucky-pack-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"luckyPackTitle`">")
    [void]$sb.AppendLine("    <div class=`"lucky-pack-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"luckyPackTitle`">Eidolon Lucky Packs</h3>")
    [void]$sb.AppendLine("      <p>Eidolon Lucky Packs are used at the Eidolon Den in your house to level up intimacy.</p>")
    [void]$sb.AppendLine("      <p>The basic stats gained by intimacy leveling are applied to your character:</p>")
    [void]$sb.AppendLine("      <ul class=`"lucky-pack-list`">")
    [void]$sb.AppendLine("        <li>DMG</li>")
    [void]$sb.AppendLine("        <li>CRIT</li>")
    [void]$sb.AppendLine("        <li>SPD</li>")
    [void]$sb.AppendLine("        <li>EVA</li>")
    [void]$sb.AppendLine("        <li>HP</li>")
    [void]$sb.AppendLine("        <li>DEF</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p>Because of this, all Eidolons should be leveled to at least intimacy level 8. It usually takes about 280 Eidolon Lucky Packs to go from level 1 to 8. Level 10 is optional.</p>")
    [void]$sb.AppendLine("      <div class=`"lucky-pack-actions`"><button id=`"luckyPackCloseBtn`" class=`"lucky-pack-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"wishCoinModal`" class=`"wish-coin-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"wishCoinTitle`">")
    [void]$sb.AppendLine("    <div class=`"wish-coin-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"wishCoinTitle`">Eidolon Wish Coins</h3>")
    [void]$sb.AppendLine("      <p>Wish Coins are used to fulfill an Eidolon's wish without needing to gather what they ask for. They are a shortcut to fulfill wishes.</p>")
    [void]$sb.AppendLine("      <p>All stats gained this way are applied to your character.</p>")
    [void]$sb.AppendLine("      <p>Wish Coin cost per wish level:</p>")
    [void]$sb.AppendLine("      <ul class=`"wish-coin-list`">")
    [void]$sb.AppendLine("        <li>Wish 1: 1 coin</li>")
    [void]$sb.AppendLine("        <li>Wish 2: 2 coins</li>")
    [void]$sb.AppendLine("        <li>Wish 3: 4 coins</li>")
    [void]$sb.AppendLine("        <li>Wish 4: 8 coins</li>")
    [void]$sb.AppendLine("        <li>Wish 5: 16 coins</li>")
    [void]$sb.AppendLine("        <li>Wish 6: 32 coins</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p>All Eidolons should have their wishes fulfilled. This is one of the greatest sources of raw stats.</p>")
    [void]$sb.AppendLine("      <div class=`"wish-coin-actions`"><button id=`"wishCoinCloseBtn`" class=`"wish-coin-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"limitBreakModal`" class=`"limit-break-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"limitBreakTitle`">")
    [void]$sb.AppendLine("    <div class=`"limit-break-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"limitBreakTitle`">Card Breakthrough Devices</h3>")
    [void]$sb.AppendLine("      <p>Card Breakthrough Devices are used to increase the breakthrough level of a card from 1 to 10.</p>")
    [void]$sb.AppendLine("      <p>Reaching level 10 unlocks the card's <strong>Status Bonus</strong>, applied permanently to your character.</p>")
    [void]$sb.AppendLine("      <p>Device tier required per level:</p>")
    [void]$sb.AppendLine("      <ul class=`"limit-break-list`">")
    [void]$sb.AppendLine("        <li>Levels 1–3: Basic Card Breakthrough Device</li>")
    [void]$sb.AppendLine("        <li>Levels 4–7: Intermediate Card Breakthrough Device</li>")
    [void]$sb.AppendLine("        <li>Levels 7–10: Advanced Card Breakthrough Device</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p>Prioritize reaching level 10 on cards with the strongest Status Bonuses for your build.</p>")
    [void]$sb.AppendLine("      <div class=`"limit-break-actions`"><button id=`"limitBreakCloseBtn`" class=`"limit-break-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"levelingGuideModal`" class=`"leveling-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"levelingGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"leveling-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"levelingGuideTitle`">Eidolon Leveling</h3>")
    [void]$sb.AppendLine("      <p>To level an Eidolon from level 25 to 80, you can use the crystals below:</p>")
    [void]$sb.AppendLine("      <ul class=`"leveling-guide-list`">")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I00469.png`" alt=`"Large XP Crystal`"><span>Large XP Crystal</span></span><span class=`"leveling-guide-qty`">10881</span></li>")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I00464.png`" alt=`"Pure XP Crystal`"><span>Pure XP Crystal</span></span><span class=`"leveling-guide-qty`">8161</span></li>")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I01677.png`" alt=`"Dazzling XP Crystal`"><span>Dazzling XP Crystal</span></span><span class=`"leveling-guide-qty`">3835</span></li>")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I02464.png`" alt=`"Gorgeous XP Crystal`"><span>Gorgeous XP Crystal</span></span><span class=`"leveling-guide-qty`">384</span></li>")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I02465.png`" alt=`"Rainbow XP Crystal`"><span>Rainbow XP Crystal</span></span><span class=`"leveling-guide-qty`">38</span></li>")
    [void]$sb.AppendLine("        <li><span class=`"leveling-guide-item`"><img class=`"leveling-guide-icon`" src=`"assets/icons/I02466.png`" alt=`"XP Stone`"><span>XP Stone</span></span><span class=`"leveling-guide-qty`">4</span></li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p><strong>Note:</strong> Medium and Small crystals are used to craft keys and raise an Eidolon to two stars, respectively.</p>")
    [void]$sb.AppendLine("      <div class=`"skill-leveling-box`">")
    [void]$sb.AppendLine("        <div class=`"skill-leveling-head`"><img class=`"skill-leveling-icon`" src=`"assets/icons/I02540.png`" alt=`"Mana Starstone`"><h4 class=`"skill-leveling-title`">Eidolon Skill Leveling (Mana Starstone)</h4></div>")
    [void]$sb.AppendLine("        <p>Leveling the skills of your main Eidolons is very important, because their skills gain stronger and additional buffs/debuffs.</p>")
    [void]$sb.AppendLine("        <ul class=`"skill-leveling-grid`">")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-green`">Green</span><span>120 stones</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-blue`">Blue</span><span>530 stones</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-orange`">Orange</span><span>1140 stones</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-purple`">Purple</span><span>1950 stones</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-gold`">Gold</span><span>2960 stones</span></li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <div class=`"skill-total`">Total Mana Starstone needed: 6700</div>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"leveling-guide-actions`"><button id=`"levelingGuideCloseBtn`" class=`"leveling-guide-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"dungeonGuideModal`" class=`"dungeon-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"dungeonGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"dungeon-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"dungeonGuideTitle`">Eidolon Spawn Location</h3>")
    [void]$sb.AppendLine("      <p>Data provided by AngelicAse&#39;s spreadsheet: <a href=`"https://docs.google.com/spreadsheets/d/17pYlqk7__46yW7dDoClrQzK1hjJ85H7Hcvn0qYk7gHQ/edit?gid=0`" target=`"_blank`" rel=`"noopener noreferrer`">Eidolon Spawn &amp; Key Fragment Locations</a>.</p>")
    [void]$sb.AppendLine("      <p><strong>Note:</strong> Eidolons not listed here may be obtained from the Loyalty Points shop, by buying from other players, through the Auction House, by playing Paragon, or from in-game events.</p>")
    [void]$sb.AppendLine("      <div class=`"dungeon-guide-list`">")

    if ($DungeonGuideItems -and $DungeonGuideItems.Count -gt 0) {
        foreach ($guideItem in $DungeonGuideItems) {
            $safeGuideName = [System.Web.HttpUtility]::HtmlEncode($guideItem.Name)
            $normalizedGuideName = Normalize-Key $guideItem.Name
            $guideIcon = ""
            if ($dungeonGuideIconMap.ContainsKey($normalizedGuideName)) {
                $guideIcon = [System.Web.HttpUtility]::HtmlEncode($dungeonGuideIconMap[$normalizedGuideName])
            }

            [void]$sb.AppendLine("        <div class='dungeon-guide-item'>")
            [void]$sb.AppendLine("          <div class='dungeon-guide-head'>")
            if ($guideIcon) {
                [void]$sb.AppendLine("            <img class='dungeon-guide-icon' src='$guideIcon' alt='$safeGuideName' loading='lazy'>")
            } else {
                [void]$sb.AppendLine("            <span class='eido-icon eido-missing dungeon-guide-icon' aria-hidden='true'>?</span>")
            }
            [void]$sb.AppendLine("            <h4>$safeGuideName</h4>")
            [void]$sb.AppendLine("          </div>")
            [void]$sb.AppendLine("          <ul>")

            foreach ($guideLocation in $guideItem.Locations) {
                $safeGuideLocation = [System.Web.HttpUtility]::HtmlEncode([string]$guideLocation)
                [void]$sb.AppendLine("            <li>$safeGuideLocation</li>")
            }

            [void]$sb.AppendLine("          </ul>")
            [void]$sb.AppendLine("        </div>")
        }
    } else {
        [void]$sb.AppendLine("        <div class='dungeon-guide-item'><h4>No dungeon data available</h4><ul><li>The source could not be loaded at generation time.</li></ul></div>")
    }

    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"dungeon-guide-actions`"><button id=`"dungeonGuideCloseBtn`" class=`"dungeon-guide-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <main class=`"wrap`">")

    foreach ($cat in $orderedCats) {
        $items = $groupMap[$cat]
        $sum3 = ($items | Measure-Object -Property N3 -Sum).Sum
        $sum4 = ($items | Measure-Object -Property N4 -Sum).Sum
        $combined = $sum3 + $sum4

        if ($combined -eq [math]::Truncate($combined)) {
            $combinedText = ([int]$combined).ToString()
        } else {
            $combinedText = $combined.ToString("0.##")
        }

        [void]$sb.AppendLine("    <section class='section' data-section='1'>")
        [void]$sb.AppendLine("      <h2>$cat</h2>")
        [void]$sb.AppendLine("      <table><thead><tr><th>Combo</th><th>&#9733;&#9733;&#9733;</th><th>&#9733;&#9733;&#9733;&#9733;</th></tr></thead><tbody>")

        foreach ($it in $items) {
            $comboSb = New-Object System.Text.StringBuilder
            [void]$comboSb.Append("<div class=`"combo-list`">")

            for ($i = 0; $i -lt $it.Eidolons.Count; $i++) {
                $eid = $it.Eidolons[$i]
                $safeName = [System.Web.HttpUtility]::HtmlEncode($eid.Name)
                $icon = Get-Local-Icon -RemoteUrl $eid.IconUrl -IconMap $IconMap

                [void]$comboSb.Append("<span class=`"combo-item`">")
                if ($icon) {
                    $safeIcon = [System.Web.HttpUtility]::HtmlEncode($icon)
                    [void]$comboSb.Append("<img class='eido-icon' src='$safeIcon' alt='$safeName' loading='lazy'>")
                } else {
                    [void]$comboSb.Append("<span class='eido-icon eido-missing' aria-hidden='true'>?</span>")
                }
                [void]$comboSb.Append("<span>$safeName</span></span>")

                if ($i -lt ($it.Eidolons.Count - 1)) {
                    [void]$comboSb.Append("<span class=`"combo-sep`">+</span>")
                }
            }

            [void]$comboSb.Append("</div>")

            $safe3 = [System.Web.HttpUtility]::HtmlEncode($it.Star3)
            $safe4 = [System.Web.HttpUtility]::HtmlEncode($it.Star4)
            [void]$sb.AppendLine("        <tr><td>$($comboSb.ToString())</td><td>$safe3</td><td>$safe4</td></tr>")
        }

        [void]$sb.AppendLine("      </tbody></table>")
        [void]$sb.AppendLine("      <div class='totals'>Combined total for this list: $combinedText</div>")
        [void]$sb.AppendLine("    </section>")
    }

    [void]$sb.AppendLine("  </main>")
    [void]$sb.AppendLine("  <script>")
    [void]$sb.AppendLine("    const q = document.getElementById('q');")
    [void]$sb.AppendLine("    const themeToggle = document.getElementById('themeToggle');")
    [void]$sb.AppendLine("    const themeIcon = document.getElementById('themeIcon');")
    [void]$sb.AppendLine("    const luckyPackInfoBtn = document.getElementById('luckyPackInfoBtn');")
    [void]$sb.AppendLine("    const luckyPackModal = document.getElementById('luckyPackModal');")
    [void]$sb.AppendLine("    const luckyPackCloseBtn = document.getElementById('luckyPackCloseBtn');")
    [void]$sb.AppendLine("    const wishCoinInfoBtn = document.getElementById('wishCoinInfoBtn');")
    [void]$sb.AppendLine("    const wishCoinModal = document.getElementById('wishCoinModal');")
    [void]$sb.AppendLine("    const wishCoinCloseBtn = document.getElementById('wishCoinCloseBtn');")
    [void]$sb.AppendLine("    const limitBreakInfoBtn = document.getElementById('limitBreakInfoBtn');")
    [void]$sb.AppendLine("    const limitBreakModal = document.getElementById('limitBreakModal');")
    [void]$sb.AppendLine("    const limitBreakCloseBtn = document.getElementById('limitBreakCloseBtn');")
    [void]$sb.AppendLine("    const levelingGuideInfoBtn = document.getElementById('levelingGuideInfoBtn');")
    [void]$sb.AppendLine("    const levelingGuideModal = document.getElementById('levelingGuideModal');")
    [void]$sb.AppendLine("    const levelingGuideCloseBtn = document.getElementById('levelingGuideCloseBtn');")
    [void]$sb.AppendLine("    const dungeonGuideInfoBtn = document.getElementById('dungeonGuideInfoBtn');")
    [void]$sb.AppendLine("    const dungeonGuideModal = document.getElementById('dungeonGuideModal');")
    [void]$sb.AppendLine("    const dungeonGuideCloseBtn = document.getElementById('dungeonGuideCloseBtn');")
    [void]$sb.AppendLine("    function applyTheme(theme) {")
    [void]$sb.AppendLine("      const t = (theme === 'light') ? 'light' : 'dark';")
    [void]$sb.AppendLine("      document.body.setAttribute('data-theme', t);")
    [void]$sb.AppendLine("      document.body.style.backgroundColor = (t === 'dark') ? '#0f141d' : '#fff6ef';")
    [void]$sb.AppendLine("      themeIcon.textContent = (t === 'dark') ? '☀' : '☾';")
    [void]$sb.AppendLine("      const actionLabel = (t === 'dark') ? 'Switch to light theme' : 'Switch to dark theme';")
    [void]$sb.AppendLine("      themeToggle.setAttribute('aria-label', actionLabel);")
    [void]$sb.AppendLine("      themeToggle.setAttribute('title', actionLabel);")
    [void]$sb.AppendLine("      localStorage.setItem('eidolonTheme', t);")
    [void]$sb.AppendLine("    }")
    [void]$sb.AppendLine("    applyTheme(localStorage.getItem('eidolonTheme') || 'dark');")
    [void]$sb.AppendLine("    themeToggle.addEventListener('click', () => {")
    [void]$sb.AppendLine("      const current = document.body.getAttribute('data-theme') || 'dark';")
    [void]$sb.AppendLine("      applyTheme(current === 'dark' ? 'light' : 'dark');")
    [void]$sb.AppendLine("    });")
    [void]$sb.AppendLine("    function openLuckyPackModal() { luckyPackModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeLuckyPackModal() { luckyPackModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    luckyPackInfoBtn.addEventListener('click', openLuckyPackModal);")
    [void]$sb.AppendLine("    luckyPackCloseBtn.addEventListener('click', closeLuckyPackModal);")
    [void]$sb.AppendLine("    luckyPackModal.addEventListener('click', (ev) => { if (ev.target === luckyPackModal) closeLuckyPackModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && luckyPackModal.classList.contains('show')) closeLuckyPackModal(); });")
    [void]$sb.AppendLine("    function openWishCoinModal() { wishCoinModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeWishCoinModal() { wishCoinModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    wishCoinInfoBtn.addEventListener('click', openWishCoinModal);")
    [void]$sb.AppendLine("    wishCoinCloseBtn.addEventListener('click', closeWishCoinModal);")
    [void]$sb.AppendLine("    wishCoinModal.addEventListener('click', (ev) => { if (ev.target === wishCoinModal) closeWishCoinModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && wishCoinModal.classList.contains('show')) closeWishCoinModal(); });")
    [void]$sb.AppendLine("    function openLimitBreakModal() { limitBreakModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeLimitBreakModal() { limitBreakModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    limitBreakInfoBtn.addEventListener('click', openLimitBreakModal);")
    [void]$sb.AppendLine("    limitBreakCloseBtn.addEventListener('click', closeLimitBreakModal);")
    [void]$sb.AppendLine("    limitBreakModal.addEventListener('click', (ev) => { if (ev.target === limitBreakModal) closeLimitBreakModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && limitBreakModal.classList.contains('show')) closeLimitBreakModal(); });")
    [void]$sb.AppendLine("    function openLevelingGuideModal() { levelingGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeLevelingGuideModal() { levelingGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    levelingGuideInfoBtn.addEventListener('click', openLevelingGuideModal);")
    [void]$sb.AppendLine("    levelingGuideCloseBtn.addEventListener('click', closeLevelingGuideModal);")
    [void]$sb.AppendLine("    levelingGuideModal.addEventListener('click', (ev) => { if (ev.target === levelingGuideModal) closeLevelingGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && levelingGuideModal.classList.contains('show')) closeLevelingGuideModal(); });")
    [void]$sb.AppendLine("    function openDungeonGuideModal() { dungeonGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeDungeonGuideModal() { dungeonGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    dungeonGuideInfoBtn.addEventListener('click', openDungeonGuideModal);")
    [void]$sb.AppendLine("    dungeonGuideCloseBtn.addEventListener('click', closeDungeonGuideModal);")
    [void]$sb.AppendLine("    dungeonGuideModal.addEventListener('click', (ev) => { if (ev.target === dungeonGuideModal) closeDungeonGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && dungeonGuideModal.classList.contains('show')) closeDungeonGuideModal(); });")
    [void]$sb.AppendLine("    q.addEventListener('input', () => {")
    [void]$sb.AppendLine("      const term = q.value.toLowerCase().trim();")
    [void]$sb.AppendLine("      document.querySelectorAll('section[data-section]').forEach(sec => {")
    [void]$sb.AppendLine("        let any = false;")
    [void]$sb.AppendLine("        sec.querySelectorAll('tbody tr').forEach(tr => {")
    [void]$sb.AppendLine("          const ok = tr.textContent.toLowerCase().includes(term);")
    [void]$sb.AppendLine("          tr.classList.toggle('hide', !ok);")
    [void]$sb.AppendLine("          if (ok) any = true;")
    [void]$sb.AppendLine("        });")
    [void]$sb.AppendLine("        sec.classList.toggle('hide', !any);")
    [void]$sb.AppendLine("      });")
    [void]$sb.AppendLine("    });")
    [void]$sb.AppendLine("  </script>")
    [void]$sb.AppendLine("</body>")
    [void]$sb.AppendLine("</html>")

    return $sb.ToString()
}

Write-Host "[1/4] Downloading page HTML..."
$response = Invoke-WebRequest -Uri $Url -UseBasicParsing
$html = $response.Content

if (-not $html) {
    throw "Could not retrieve content from $Url"
}

$archiveMatch = [regex]::Match($html, "<table id=`"archive`"[\s\S]*?<tbody>(?<body>[\s\S]*?)</tbody>[\s\S]*?</table>")
if (-not $archiveMatch.Success) {
    throw "Table #archive was not found in downloaded HTML."
}

$tbody = $archiveMatch.Groups["body"].Value
$rowMatches = [regex]::Matches($tbody, "<tr>[\s\S]*?<td>(?<eid>[\s\S]*?)</td>[\s\S]*?<td class=`"text-start`">(?<bonus>[\s\S]*?)</td>[\s\S]*?</tr>")

$rows = @()
$allIconUrls = New-Object System.Collections.Generic.HashSet[string]

foreach ($rm in $rowMatches) {
    $eidHtml = $rm.Groups["eid"].Value
    $bonusHtml = $rm.Groups["bonus"].Value

    $eidMatches = [regex]::Matches($eidHtml, "<a\s+title=`"(?<name>[^`"]+)`"[^>]*>[\s\S]*?<img[^>]+src=`"(?<src>[^`"]+)`"", "IgnoreCase")
    if ($eidMatches.Count -eq 0) {
        continue
    }

    $eidolons = @()
    foreach ($em in $eidMatches) {
        $name = [System.Web.HttpUtility]::HtmlDecode($em.Groups["name"].Value).Trim()
        $name = Normalize-EidolonName $name
        $src = $em.Groups["src"].Value.Trim()
        if ($name) {
            $eidolons += [pscustomobject]@{
                Name = $name
                IconUrl = $src
            }
            if ($src) {
                [void]$allIconUrls.Add($src)
            }
        }
    }

    $s3m = [regex]::Match($bonusHtml, "star-3[\s\S]*?</span>(?<v>[\s\S]*?)</div>")
    $s4m = [regex]::Match($bonusHtml, "star-4[\s\S]*?</span>(?<v>[\s\S]*?)</div>")

    if (-not $s3m.Success -or -not $s4m.Success) {
        continue
    }

    $s3 = Clean-Text $s3m.Groups["v"].Value
    $s4 = Clean-Text $s4m.Groups["v"].Value
    $comboOverride = Get-ComboOverride -Eidolons $eidolons -Star3 $s3 -Star4 $s4

    $rows += [pscustomobject]@{
        Category = $comboOverride.Category
        Eidolons = $eidolons
        Star3 = $comboOverride.Star3
        Star4 = $comboOverride.Star4
        N3 = Get-Numeric $comboOverride.Star3
        N4 = Get-Numeric $comboOverride.Star4
    }
}

if ($rows.Count -eq 0) {
    throw "No combo rows were extracted from table #archive."
}

$iconMap = @{}
Write-Host "[2/4] Preparing icons..."
if (-not $KeepRemoteIcons) {
    Write-Host "      Downloading Eidolon icons to $AssetsDir..."
    $assetsPath = Join-Path (Get-Location) $AssetsDir
    New-Item -Path $assetsPath -ItemType Directory -Force | Out-Null

    foreach ($remote in $allIconUrls) {
        if (-not $remote) {
            continue
        }

        $fileName = [System.IO.Path]::GetFileName(([uri]$remote).AbsolutePath)
        if (-not $fileName) {
            continue
        }

        $localPath = Join-Path $assetsPath $fileName
        if (-not (Test-Path $localPath)) {
            Invoke-WebRequest -Uri $remote -OutFile $localPath -UseBasicParsing
        }

        $iconMap[$remote] = ($AssetsDir.Replace("\", "/") + "/" + $fileName)
    }
} else {
    Write-Host "      Keeping remote Eidolon icons (no local download)."
}

$guideIconsPath = Join-Path (Get-Location) $GuideIconsDir
New-Item -Path $guideIconsPath -ItemType Directory -Force | Out-Null
foreach ($entry in $GuideIconSources.GetEnumerator()) {
    $targetPath = Join-Path $guideIconsPath $entry.Key
    if (-not (Test-Path $targetPath)) {
        Invoke-WebRequest -Uri $entry.Value -OutFile $targetPath -UseBasicParsing
    }
}

$hardcodedGuidePath = Join-Path (Get-Location) $DungeonGuideHardcodedFile
$hardcodedDungeonGuideItems = Get-HardcodedDungeonGuideItems -FilePath $hardcodedGuidePath
if ($hardcodedDungeonGuideItems.Count -gt 0) {
    Write-Host ("      Hardcoded dungeon guide entries: " + $hardcodedDungeonGuideItems.Count)
}

$knownEidolonNames = @($rows | ForEach-Object { $_.Eidolons } | ForEach-Object { $_.Name } | Sort-Object -Unique)

$dungeonGuideItems = @($hardcodedDungeonGuideItems)
try {
    Write-Host "      Loading dungeon Eidolon guide data..."
    $liveDungeonGuideItems = Get-DungeonGuideItemsFromSheetPage -SheetPageUrl $DungeonGuideSheetPageUrl -KnownEidolonNames $knownEidolonNames
    if ($liveDungeonGuideItems.Count -eq 0) {
        $liveDungeonGuideItems = Get-DungeonGuideItems -SheetUrl $DungeonGuideSheetUrl -KnownEidolonNames $knownEidolonNames
    }
    $dungeonGuideItems = Merge-DungeonGuideItems -PrimaryItems $liveDungeonGuideItems -FallbackItems $hardcodedDungeonGuideItems
    Write-Host ("      Dungeon guide entries: " + $dungeonGuideItems.Count)
} catch {
    Write-Warning ("Could not load dungeon guide source: " + $_.Exception.Message)
    Write-Warning "Using hardcoded dungeon guide data only."
}

Write-Host "[3/4] Building page HTML..."
$page = Build-PageHtml -Rows $rows -IconMap $iconMap -DungeonGuideItems $dungeonGuideItems

Write-Host "[4/4] Saving file..."
Set-Content -Path $OutputHtml -Value $page -Encoding UTF8

Write-Host "Done."
Write-Host ("Processed combos: " + $rows.Count)
Write-Host ("Categories: " + (($rows | Group-Object Category).Count))
if (-not $KeepRemoteIcons) {
    Write-Host ("Icons mapped locally: " + $iconMap.Count)
}

# Save version for the app to detect updates
$versionPath = Join-Path (Get-Location) "version.txt"
Set-Content -Path $versionPath -Value $rows.Count.ToString() -Encoding UTF8
Write-Host ("Version saved to version.txt: " + $rows.Count)

