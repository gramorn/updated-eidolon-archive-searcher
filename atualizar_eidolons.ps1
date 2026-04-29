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
    [void]$sb.AppendLine("    .info-menu-panel .lucky-pack-btn, .info-menu-panel .wish-coin-btn, .info-menu-panel .limit-break-btn, .info-menu-panel .dungeon-guide-btn, .info-menu-panel .leveling-guide-btn, .info-menu-panel .boost-guide-btn, .info-menu-panel .best-eidolons-btn, .info-menu-panel .useful-links-btn { width:100%; justify-content:flex-start; }")
    [void]$sb.AppendLine("    .best-eidolons-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:flex-start; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .best-eidolons-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .class-guides-panel { max-height:min(70vh, 320px); overflow-y:auto; align-content:start; }")
    [void]$sb.AppendLine("    .class-guide-item { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--chip-bg); display:inline-flex; align-items:center; justify-content:flex-start; padding:0 10px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .useful-links-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:flex-start; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .useful-links-btn:hover { border-color:var(--accent); }")
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
    [void]$sb.AppendLine("    .gear-guide-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:flex-start; text-align:left; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .gear-guide-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .boost-guide-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .boost-guide-btn:hover { border-color:var(--accent); }")
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
    [void]$sb.AppendLine("    .gear-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .gear-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .gear-guide-modal { width:min(760px, 96vw); max-height:90vh; overflow:auto; text-align:left; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .gear-guide-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .gear-guide-modal p { margin:0 0 8px; color:var(--muted); }")
    [void]$sb.AppendLine("    .gear-guide-box { margin-top:10px; border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:10px; }")
    [void]$sb.AppendLine("    .gear-guide-box h4 { margin:0 0 6px; font-size:0.92rem; color:var(--ink); }")
    [void]$sb.AppendLine("    .gear-guide-box h5 { margin:10px 0 4px; font-size:0.84rem; color:var(--ink); font-weight:600; }")
    [void]$sb.AppendLine("    .gear-guide-list { margin:0; padding-left:18px; color:var(--muted); }")
    [void]$sb.AppendLine("    .gear-guide-list li { margin:6px 0; }")
    [void]$sb.AppendLine("    .gear-guide-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .gear-guide-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .gear-guide-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .boost-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .boost-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .boost-guide-modal { width:min(760px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .boost-guide-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .boost-guide-modal p { margin:0 0 8px; color:var(--muted); }")
    [void]$sb.AppendLine("    .boost-guide-tip { margin-top:10px; border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:10px; }")
    [void]$sb.AppendLine("    .boost-guide-tip h4 { margin:0 0 6px; font-size:0.92rem; color:var(--ink); }")
    [void]$sb.AppendLine("    .boost-guide-tip strong { color:var(--ink); }")
    [void]$sb.AppendLine("    .boost-source-wrap { margin-top:8px; border:1px solid var(--line); border-radius:10px; overflow:auto; background:var(--card); }")
    [void]$sb.AppendLine("    .boost-source-table { width:100%; min-width:620px; border-collapse:collapse; }")
    [void]$sb.AppendLine("    .boost-source-table th, .boost-source-table td { border:1px solid var(--line); padding:7px 8px; font-size:0.82rem; text-align:left; color:var(--muted); vertical-align:top; }")
    [void]$sb.AppendLine("    .boost-source-table th { background:var(--chip-bg); color:var(--ink); font-weight:700; }")
    [void]$sb.AppendLine("    .boost-source-table td.item-name { color:var(--ink); font-weight:600; }")
    [void]$sb.AppendLine("    .boost-guide-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .boost-guide-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .boost-guide-close:hover { border-color:var(--accent); }")
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
    [void]$sb.AppendLine("    .useful-links-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .useful-links-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .useful-links-modal { width:min(680px, 96vw); background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .useful-links-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .useful-links-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .useful-links-list { margin:8px 0 0; padding-left:18px; }")
    [void]$sb.AppendLine("    .useful-links-list li { margin:6px 0; }")
    [void]$sb.AppendLine("    .useful-links-list a { color:var(--accent); text-decoration:underline; text-underline-offset:2px; font-weight:600; }")
    [void]$sb.AppendLine("    .useful-links-list a:hover { filter:brightness(1.12); }")
    [void]$sb.AppendLine("    .useful-links-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .useful-links-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .useful-links-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .best-eidolons-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .best-eidolons-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .best-eidolons-modal { width:min(920px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .best-eidolons-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .best-eidolons-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .best-eidolons-warning { margin-top:10px; border:1px solid #b45309; border-radius:10px; background:rgba(245, 158, 11, 0.12); color:var(--ink); padding:10px; }")
    [void]$sb.AppendLine("    .best-eidolons-grid { display:grid; grid-template-columns:repeat(auto-fit, minmax(260px, 1fr)); gap:10px; margin-top:12px; }")
    [void]$sb.AppendLine("    .best-eidolons-section { border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:10px; }")
    [void]$sb.AppendLine("    .best-eidolons-section h4 { margin:0 0 6px; font-size:0.92rem; color:var(--ink); }")
    [void]$sb.AppendLine("    .best-eidolons-list { margin:0; padding-left:0; list-style:none; color:var(--muted); }")
    [void]$sb.AppendLine("    .best-eidolons-list li { margin:6px 0; display:flex; align-items:flex-start; gap:8px; }")
    [void]$sb.AppendLine("    .best-eido-icon { width:28px; height:28px; object-fit:contain; flex-shrink:0; border-radius:3px; margin-top:2px; }")
    [void]$sb.AppendLine("    .eido-sym { color:#f59e0b; font-size:0.72em; vertical-align:super; margin-left:1px; }")
    [void]$sb.AppendLine("    .best-upgrade-tag { display:inline-block; font-size:0.68rem; background:rgba(99,102,241,0.15); color:#818cf8; border-radius:4px; padding:1px 5px; margin-left:3px; white-space:nowrap; vertical-align:middle; font-weight:600; }")
    [void]$sb.AppendLine("    .best-eidolons-legend { font-size:0.75rem; color:var(--muted); margin:6px 0 0; }")
    [void]$sb.AppendLine("    .best-eidolons-legend .eido-sym { font-size:0.9em; vertical-align:baseline; }")
    [void]$sb.AppendLine("    .best-eidolons-footer { margin-top:12px; border-top:1px solid var(--line); padding-top:10px; color:var(--muted); }")
    [void]$sb.AppendLine("    .best-eidolons-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .best-eidolons-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .best-eidolons-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .class-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .class-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .class-guide-modal { width:min(680px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .class-guide-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .class-guide-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .class-guide-list { margin:8px 0 0; padding:0; list-style:none; display:grid; grid-template-columns:repeat(auto-fit, minmax(180px, 1fr)); gap:8px; }")
    [void]$sb.AppendLine("    .class-guide-list li { margin:0; border:1px solid var(--line); border-radius:10px; background:var(--chip-bg); padding:8px 10px; color:var(--ink); font-weight:600; }")
    [void]$sb.AppendLine("    .class-guide-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .class-guide-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .class-guide-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .guide-status { font-size:0.65rem; font-weight:700; border-radius:4px; padding:1px 5px; margin-left:auto; white-space:nowrap; }")
    [void]$sb.AppendLine("    .guide-status-soon { background:rgba(239,68,68,0.15); color:#f87171; }")
    [void]$sb.AppendLine("    .guide-status-wip { background:rgba(234,179,8,0.15); color:#facc15; }")
    [void]$sb.AppendLine("    .guide-status-done { background:rgba(34,197,94,0.15); color:#4ade80; }")
    [void]$sb.AppendLine("    @media (max-width:760px) { .top-row { align-items:stretch; flex-direction:column; } .top-actions { width:100%; justify-content:flex-start; } .lucky-pack-btn, .wish-coin-btn, .limit-break-btn, .dungeon-guide-btn, .leveling-guide-btn, .gear-guide-btn, .boost-guide-btn, .best-eidolons-btn, .class-guide-item, .useful-links-btn { min-height:40px; padding:6px 10px; } .theme-toggle { flex:0 0 auto; } .info-menu-panel { position:static; width:100%; margin-top:8px; } .dungeon-guide-list { grid-template-columns:1fr; } .leveling-guide-list li { align-items:flex-start; flex-direction:column; } .skill-leveling-grid { grid-template-columns:1fr; } th, td { padding:7px 6px; font-size:0.84rem; } }")
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
    [void]$sb.AppendLine("            <button id=`"gearGuideInfoBtn`" class=`"gear-guide-btn`" type=`"button`" title=`"How should I craft my gear?`" aria-label=`"How should I craft my gear?`">Gear Guide</button>")
    [void]$sb.AppendLine("            <button id=`"boostGuideInfoBtn`" class=`"boost-guide-btn`" type=`"button`" title=`"How can I increase my damage?`" aria-label=`"How can I increase my damage?`">Boost your damage</button>")
    [void]$sb.AppendLine("            <button id=`"dungeonGuideInfoBtn`" class=`"dungeon-guide-btn`" type=`"button`" title=`"Where can I find Eidolon spawn locations?`" aria-label=`"Where can I find Eidolon spawn locations?`">Eidolon Spawn Location</button>")
    [void]$sb.AppendLine("            <button id=`"bestEidolonsInfoBtn`" class=`"best-eidolons-btn`" type=`"button`" title=`"Open best eidolons guide`" aria-label=`"Open best eidolons guide`">Best Eidolons</button>")
    [void]$sb.AppendLine("            <button id=`"usefulLinksInfoBtn`" class=`"useful-links-btn`" type=`"button`" title=`"Open useful links`" aria-label=`"Open useful links`">Useful links</button>")
    [void]$sb.AppendLine("          </div>")
    [void]$sb.AppendLine("        </details>")
    [void]$sb.AppendLine("        <details class=`"info-menu`">")
    [void]$sb.AppendLine("          <summary class=`"info-menu-toggle`" aria-label=`"Open class guides menu`">Class Guides ▾</summary>")
    [void]$sb.AppendLine("          <div class=`"info-menu-panel class-guides-panel`">")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Duelist <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Guardian <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Ravager <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Wizard <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Gunslinger <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Grenadier <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Sorcerer <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Bard <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Brawler <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Ranger <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Ronin <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Reaper <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Holy Sword <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Shinobi <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Lancer <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Guitar <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Star Caller <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Whipmaster <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Dragon Nunchaku <span class='guide-status guide-status-soon'>Soon</span></div>")
    [void]$sb.AppendLine("            <div class='class-guide-item'>Stellar Sphere <span class='guide-status guide-status-soon'>Soon</span></div>")
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
    [void]$sb.AppendLine("  <div id=`"gearGuideModal`" class=`"gear-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"gearGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"gear-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"gearGuideTitle`">Gear Guide</h3>")
    [void]$sb.AppendLine("      <p>This section covers practical crafting priorities for your equipment.</p>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Crafting Notes</h4>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Your weapon should use your class element because it deals 20% more elemental damage.</li>")
    [void]$sb.AppendLine("          <li>Your armor element applies only on the chest piece and gives extra defense against that element. Dark element armor is generally preferred.</li>")
    [void]$sb.AppendLine("          <li>Try to craft at least 120%+ quality on equipment. It is less important on armor, but high weapon quality increases damage noticeably.</li>")
    [void]$sb.AppendLine("          <li>The quality cap is 130% for Orange equipment and 140% for Gold equipment.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Weapon Progression by Level</h4>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">The strongest current weapons are farmed in Abyss II for each element. They are the best choices at Lv95, S15, and S35, so after Lv95 you generally do not need other weapon lines.</p>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Below Lv95:</strong> Use reward weapons from Aura and Advanced Gaia (one from Lv1-40 and one from Lv40-75). They can carry you comfortably until Lv95. For sub get any Nocturnal weapon from NPC.</li>")
    [void]$sb.AppendLine("          <li><strong>Lv95:</strong> Craft the Abyss II weapon for your element: Hebe (Ice), Cerberus (Fire), Izanami (Dark), Michaela (Holy), Demeter (Storm), Hermes (Lightning). For physical builds, pick the weapon that gives the best boost to your main skills. If you do not want Abyss II yet, use Lv95 gold with your element or craft Lv90 orange with your preferred core. For sub weapon craft lvl 90 Nocturnal, usually bard one.</li>")
    [void]$sb.AppendLine("          <li><strong>S5:</strong> If you still do not have a Lv95 option, craft your Abyss II element weapon or use an S5 gold weapon with your element. If you crafted lvl90 Nocturnal sub, just keep it. If you didn't, craft either lvl90 or S1.</li>")
    [void]$sb.AppendLine("          <li><strong>S10:</strong> The Lv95 Abyss II weapon is still good here. If you really want to change, craft the S10 orange weapon. You can craft S10 sub Nocturnal weapon if you wish to.</li>")
    [void]$sb.AppendLine("          <li><strong>S15:</strong> Craft the S15 Abyss II weapon for your element. This is your best weapon line until S35.</li>")
    [void]$sb.AppendLine("          <li><strong>S20:</strong> (Optional) Craft Nocturnal sub weapon of your choice (usually bard if you need detail and healing or shuriken if you have enough detail).</li>")
    [void]$sb.AppendLine("          <li><strong>S30:</strong> You can craft S30 orange if you want to, but I recommend sticking with S15 Abyss II. Craft Nocturnal sub weapon of your choice (usually bard if you need detail and healing or shuriken if you have enough detail).</li>")
    [void]$sb.AppendLine("          <li><strong>S35:</strong> You can switch to S35 gold for your element, but it is optional. The best weapon is still Abyss II S35 of your element; S35 Abyss II is difficult to farm, so swap when you are strong enough and can farm it consistently.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Weapon Core Options</h4>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Destroyer:</strong> 10% DEF Shred.</li>")
    [void]$sb.AppendLine("          <li><strong>Nocturnal:</strong> 3% Absorb DMG to HP. This is nerfed in some dungeons.</li>")
    [void]$sb.AppendLine("          <li><strong>Deadly:</strong> 15% CRIT DMG.</li>")
    [void]$sb.AppendLine("          <li><strong>Restorer (Bard Only):</strong> 10% Heal.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Armor / Trophy / Accessories Core Options</h4>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Imperial:</strong> 3% Move SPD.</li>")
    [void]$sb.AppendLine("          <li><strong>Blessed:</strong> 5% EXP Gain.</li>")
    [void]$sb.AppendLine("          <li><strong>Bestial:</strong> 1% DMG + 1% HP.</li>")
    [void]$sb.AppendLine("          <li><strong>Spiky:</strong> 1% DMG + 1% DEF.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Mount Buff</h4>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>40% bonus to your class element skill damage.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Weapon Secret Stone</h4>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">Always get the secret stone for your class skill.</p>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Piercing Secret Stone</strong> — Best in slot, but expensive.</li>")
    [void]$sb.AppendLine("          <li><strong>Lava Secret Stone</strong> — Cheaper than Piercing, and can be farmed in Pyroclastic Purgatory.</li>")
    [void]$sb.AppendLine("          <li><strong>Orange Class Master Stone</strong> — Use as a placeholder before getting Lava or better.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Armor Secret Stone</h4>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">Purchase them at your class Master in Navea. They will be orange — don't worry about the stats. Level them to 70, then upgrade to purple to add one more stat, and they are ready to reroll.</p>")
    [void]$sb.AppendLine("        <h5>Best Stats to Aim For (Rerolling)</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Detail-DMG</strong> (or DMG): +5 / +4 / +3</li>")
    [void]$sb.AppendLine("          <li><strong>CRIT DMG:</strong> +10 / +8 / +6</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">Always aim for <strong>Detail-DMG +5%</strong> or at least <strong>DMG +4%</strong>. The most common strategy is to get <strong>Detail-DMG +5</strong> on the last line, then use a <strong>DMG + Something reroll potion</strong> to aim for double Detail-DMG on the stone.</p>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">With enough economy, you can push further and get a stone with <strong>three damage stats</strong> — for example: <em>The DMG caused is increased by 6% / DMG +3% / Detail-DMG +5%</em>.</p>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Costume</h4>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`"><strong>Important:</strong> Always apply a <strong>Premium / Super Premium Card</strong> to the blue card bought from the Encyclopedia first, then use that blue card with enchants on your costume.</p>")
    [void]$sb.AppendLine("        <h5>Headpiece - 12% DMG To Bosses</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Add 10% Boss DMG Enchant.</li>")
    [void]$sb.AppendLine("          <li>Option A: Add 4% HP + 2% EVA Super Enchant.</li>")
    [void]$sb.AppendLine("          <li>Option B: Add 4% HP + 4% HEAL Super Enchant.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <h5>Body - 20% CRIT DMG To Bosses</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Add 25% Boss CRIT DMG Enchant.</li>")
    [void]$sb.AppendLine("          <li>Add 4% DMG + 2% CRIT Super Enchant.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <h5>Face - Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Add Class Enchant.</li>")
    [void]$sb.AppendLine("          <li>Option A: Add 4% DMG + 2% CRIT Super Enchant.</li>")
    [void]$sb.AppendLine("          <li>Option B: Add 4% DMG + Reduce 4% DMG Taken Super Enchant.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <h5>Back - 8% Move SPD Priority. Otherwise Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Add Move SPD Enchant.</li>")
    [void]$sb.AppendLine("          <li>Add 4% DMG + 4% HP Super Enchant.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <h5>Weapon - 12% Element Skill DMG</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li>Add Class Enchant.</li>")
    [void]$sb.AppendLine("          <li>Add 4% DMG + 2% CRIT Super Enchant.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-actions`"><button id=`"gearGuideCloseBtn`" class=`"gear-guide-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"boostGuideModal`" class=`"boost-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"boostGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"boost-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"boostGuideTitle`">Boost your damage</h3>")
    [void]$sb.AppendLine("      <p>This guide focuses on practical ways to increase your overall damage output.</p>")
    [void]$sb.AppendLine("      <div class=`"boost-guide-tip`">")
    [void]$sb.AppendLine("        <h4>Back Strike</h4>")
    [void]$sb.AppendLine("        <p>Back Strike means attacking enemies from behind. Doing this grants <strong>50% amplified damage</strong>.</p>")
    [void]$sb.AppendLine("        <p>Whenever possible, reposition to stay behind the target and maintain this bonus.</p>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"boost-guide-tip`">")
    [void]$sb.AppendLine("        <h4>Jump Casting</h4>")
    [void]$sb.AppendLine("        <p>Jump Casting is a combat mechanic where you jump and then cast your skills. This helps cancel or shorten many animations that would normally lock you in place.</p>")
    [void]$sb.AppendLine("        <p>It also weaves basic attacks between skills, which increases your total damage output over time.</p>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"boost-guide-tip`">")
    [void]$sb.AppendLine("        <h4>Amplified Damage Sources</h4>")
    [void]$sb.AppendLine("        <p>Reference list of common sources that can raise your amplified damage in combat.</p>")
    [void]$sb.AppendLine("        <div class=`"boost-source-wrap`">")
    [void]$sb.AppendLine("          <table class=`"boost-source-table`">")
    [void]$sb.AppendLine("            <thead><tr><th>Item Name</th><th>Note</th><th>Proc Chance</th><th>Amplified DMG</th></tr></thead>")
    [void]$sb.AppendLine("            <tbody>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`" rowspan=`"3`">Dual Drive</td><td>Weapon cards</td><td>8%</td><td>80%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>Eidolon 1-2 Star</td><td>5%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>Eidolon 3-4 Star</td><td>10%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Back Striker</td><td>Hit behind boss</td><td>100%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Rapid Assault</td><td>SPD over cap bonus</td><td>0.1%-20%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Combo</td><td>Eidolon Archive</td><td>2%-21%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Holy Chest +240</td><td>8 Weapons +30</td><td>4%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Pet</td><td>-</td><td>4%-6%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Zeal</td><td>Attack spec mastery</td><td>10%</td><td>110%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Food / Drink</td><td>Lv101 or Above</td><td>15%</td><td>110%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Supreme Sword Soul</td><td>Holy Spirit</td><td>10%</td><td>179%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Book of Destruction</td><td>Trophy</td><td>20%</td><td>75%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Void Calamity</td><td>Trophy</td><td>10%</td><td>135%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`" rowspan=`"2`">Torque Motor</td><td rowspan=`"2`">Buff</td><td>5%</td><td>150%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>1%</td><td>175%</td></tr>")
    [void]$sb.AppendLine("            </tbody>")
    [void]$sb.AppendLine("          </table>")
    [void]$sb.AppendLine("        </div>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"boost-guide-actions`"><button id=`"boostGuideCloseBtn`" class=`"boost-guide-close`" type=`"button`">Close</button></div>")
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
    [void]$sb.AppendLine("  <div id=`"bestEidolonsModal`" class=`"best-eidolons-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"bestEidolonsTitle`">")
    [void]$sb.AppendLine("    <div class=`"best-eidolons-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"bestEidolonsTitle`">Best Eidolons</h3>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-warning`"><strong>Outdated list:</strong> this information is from July 2024 and may no longer reflect the current best choices.</div>")
    [void]$sb.AppendLine("      <p class=`"best-eidolons-legend`"><span class='eido-sym'>&#9733;</span> = Great with Eidolon Symbol</p>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-grid`">")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Universal Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Best DPS for any build. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00099.png' alt='Otohime' loading='lazy'><span><strong>Otohime:</strong> Top DPS with 10s zeal buff. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00055.png' alt='Tyr' loading='lazy'><span><strong>Tyr:</strong> Best flat DEF shred for any class. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00096.png' alt='Persephone' loading='lazy'><span><strong>Persephone:</strong> 10s DMG &amp; debuff immunity — disable auto-skills and activate manually. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00138.png' alt='Da Qiao' loading='lazy'><span><strong>Da Qiao:</strong> Emergency party healing. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00066.png' alt='Eirene' loading='lazy'><span><strong>Eirene:</strong> Debuff cleanse + 4s DMG &amp; debuff immunity. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Dark Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00077.png' alt='NY Muramasa' loading='lazy'><span><strong>NY Muramasa<span class='eido-sym'>&#9733;</span>:</strong> Main DPS with 5s zeal buff. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00137.png' alt='Eris' loading='lazy'><span><strong>Eris<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00068.png' alt='Hades' loading='lazy'><span><strong>Hades<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00106.png' alt='NY Succubus' loading='lazy'><span><strong>NY Succubus:</strong> Flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00062.png' alt='Muramasa' loading='lazy'><span><strong>Muramasa:</strong> Flat DEF shred. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00073.png' alt='Nidhogg' loading='lazy'><span><strong>Nidhogg<span class='eido-sym'>&#9733;</span>:</strong> Main DPS — no skill upgrades needed.</span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Holy Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00156.png' alt='Guan Yu' loading='lazy'><span><strong>Guan Yu<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00140.png' alt='Gaia' loading='lazy'><span><strong>Gaia<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00098.png' alt='Summer Michaela' loading='lazy'><span><strong>Summer Michaela<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00144.png' alt='Christmas Andrea' loading='lazy'><span><strong>Christmas Andrea:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00072.png' alt='Idunn' loading='lazy'><span><strong>Idunn:</strong> Flat DEF shred + 8s debuff immunity. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00045.png' alt='Alice' loading='lazy'><span><strong>Alice:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Flame Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Main DPS with 8s zeal buff. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00162.png' alt='Cinderella' loading='lazy'><span><strong>Cinderella:</strong> Flat DEF shred + debuff removal. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00151.png' alt='Liu Bei' loading='lazy'><span><strong>Liu Bei<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00120.png' alt='NY Elizabeth' loading='lazy'><span><strong>NY Elizabeth:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00142.png' alt='Anubis' loading='lazy'><span><strong>Anubis<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00121.png' alt='Little Red Riding Hood' loading='lazy'><span><strong>Little Red Riding Hood<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00087.png' alt='Halloween Zashi' loading='lazy'><span><strong>Halloween Zashi<span class='eido-sym'>&#9733;</span>:</strong> Main DPS — no skill upgrades needed.</span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Storm Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00152.png' alt='Summer Rachel' loading='lazy'><span><strong>Summer Rachel:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00148.png' alt='Odin' loading='lazy'><span><strong>Odin<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00112.png' alt='Summer Persephone' loading='lazy'><span><strong>Summer Persephone<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00048.png' alt='Yumikaze' loading='lazy'><span><strong>Yumikaze<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00081.png' alt='Sif' loading='lazy'><span><strong>Sif<span class='eido-sym'>&#9733;</span>:</strong> Emergency healing. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Ice Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00150.png' alt='Poseidon' loading='lazy'><span><strong>Poseidon:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00118.png' alt='Christmas Idunn' loading='lazy'><span><strong>Christmas Idunn<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00145.png' alt='Christmas Sakuya-hime' loading='lazy'><span><strong>Christmas Sakuya-hime<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00157.png' alt='Christmas Little Red Riding Hood' loading='lazy'><span><strong>Christmas Little Red Riding Hood<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00054.png' alt='Lumikki' loading='lazy'><span><strong>Lumikki:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00066.png' alt='Eirene' loading='lazy'><span><strong>Eirene:</strong> Debuff cleanse + 4s DMG &amp; debuff immunity. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Lightning Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00147.png' alt='Zhang Fei' loading='lazy'><span><strong>Zhang Fei:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00114.png' alt='Rachel' loading='lazy'><span><strong>Rachel<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00127.png' alt='Frigga' loading='lazy'><span><strong>Frigga<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred + debuff removal. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00159.png' alt='New Year Anubis' loading='lazy'><span><strong>New Year Anubis:</strong> Fast debuffs for short fights. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00111.png' alt='Salome' loading='lazy'><span><strong>Salome<span class='eido-sym'>&#9733;</span>:</strong> Fast debuffs for short fights. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00122.png' alt='Komainu' loading='lazy'><span><strong>Komainu:</strong> Long-duration party buff. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Physical Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Main DPS with 8s zeal buff. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00140.png' alt='Gaia' loading='lazy'><span><strong>Gaia<span class='eido-sym'>&#9733;</span>:</strong> Weak physical skill DMG buff — last resort only. <span class='best-upgrade-tag'>2nd upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-footer`"><p>I do not know who should be credited for this information. If this is your information and you want credit, feel free to contact me on Discord.</p></div>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-actions`"><button id=`"bestEidolonsCloseBtn`" class=`"best-eidolons-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"usefulLinksModal`" class=`"useful-links-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"usefulLinksTitle`">")
    [void]$sb.AppendLine("    <div class=`"useful-links-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"usefulLinksTitle`">Useful links</h3>")
    [void]$sb.AppendLine("      <p>Community guides and resources.</p>")
    [void]$sb.AppendLine("      <ul class=`"useful-links-list`">")
    [void]$sb.AppendLine("        <li><a href=`"https://docs.google.com/spreadsheets/d/1UVNbfKEjx0wplajRWvolVG4UtV_mPXX5-H8kbbP3d-Q/edit?gid=1553398285#gid=1553398285`" target=`"_blank`" rel=`"noopener noreferrer`">AngelicAse&#39;s Estate Guide</a></li>")
    [void]$sb.AppendLine("        <li><a href=`"https://www.youtube.com/playlist?list=PLggMyxv8HbqxA7mUJmYjZbJv4gtxPyD2h`" target=`"_blank`" rel=`"noopener noreferrer`">Midday&#39;s Oddities Guide</a></li>")
    [void]$sb.AppendLine("        <li><a href=`"https://www.youtube.com/playlist?list=PLggMyxv8HbqwsBPTXzzFNEzuDD3Xv4Ig0`" target=`"_blank`" rel=`"noopener noreferrer`">Midday&#39;s Bond Dungeon Walkthrough</a></li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <div class=`"useful-links-actions`"><button id=`"usefulLinksCloseBtn`" class=`"useful-links-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"classGuideModal`" class=`"class-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"classGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"class-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"classGuideTitle`">Class Guides</h3>")
    [void]$sb.AppendLine("      <p>This menu is ready for class-by-class Aura Kingdom guides.</p>")
    [void]$sb.AppendLine("      <p>Current classes available for future guides:</p>")
    [void]$sb.AppendLine("      <ul class=`"class-guide-list`">")
    [void]$sb.AppendLine("        <li>Duelist</li>")
    [void]$sb.AppendLine("        <li>Guardian</li>")
    [void]$sb.AppendLine("        <li>Ravager</li>")
    [void]$sb.AppendLine("        <li>Wizard</li>")
    [void]$sb.AppendLine("        <li>Gunslinger</li>")
    [void]$sb.AppendLine("        <li>Grenadier</li>")
    [void]$sb.AppendLine("        <li>Sorcerer</li>")
    [void]$sb.AppendLine("        <li>Bard</li>")
    [void]$sb.AppendLine("        <li>Brawler</li>")
    [void]$sb.AppendLine("        <li>Ranger</li>")
    [void]$sb.AppendLine("        <li>Ronin</li>")
    [void]$sb.AppendLine("        <li>Reaper</li>")
    [void]$sb.AppendLine("        <li>Holy Sword</li>")
    [void]$sb.AppendLine("        <li>Shinobi</li>")
    [void]$sb.AppendLine("        <li>Lancer</li>")
    [void]$sb.AppendLine("        <li>Guitar</li>")
    [void]$sb.AppendLine("        <li>Star Caller</li>")
    [void]$sb.AppendLine("        <li>Whipmaster</li>")
    [void]$sb.AppendLine("        <li>Dragon Nunchaku</li>")
    [void]$sb.AppendLine("        <li>Stellar Sphere</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <div class=`"class-guide-actions`"><button id=`"classGuideCloseBtn`" class=`"class-guide-close`" type=`"button`">Close</button></div>")
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
    [void]$sb.AppendLine("    const gearGuideInfoBtn = document.getElementById('gearGuideInfoBtn');")
    [void]$sb.AppendLine("    const gearGuideModal = document.getElementById('gearGuideModal');")
    [void]$sb.AppendLine("    const gearGuideCloseBtn = document.getElementById('gearGuideCloseBtn');")
    [void]$sb.AppendLine("    const boostGuideInfoBtn = document.getElementById('boostGuideInfoBtn');")
    [void]$sb.AppendLine("    const boostGuideModal = document.getElementById('boostGuideModal');")
    [void]$sb.AppendLine("    const boostGuideCloseBtn = document.getElementById('boostGuideCloseBtn');")
    [void]$sb.AppendLine("    const dungeonGuideInfoBtn = document.getElementById('dungeonGuideInfoBtn');")
    [void]$sb.AppendLine("    const dungeonGuideModal = document.getElementById('dungeonGuideModal');")
    [void]$sb.AppendLine("    const dungeonGuideCloseBtn = document.getElementById('dungeonGuideCloseBtn');")
    [void]$sb.AppendLine("    const bestEidolonsInfoBtn = document.getElementById('bestEidolonsInfoBtn');")
    [void]$sb.AppendLine("    const bestEidolonsModal = document.getElementById('bestEidolonsModal');")
    [void]$sb.AppendLine("    const bestEidolonsCloseBtn = document.getElementById('bestEidolonsCloseBtn');")
    [void]$sb.AppendLine("    const usefulLinksInfoBtn = document.getElementById('usefulLinksInfoBtn');")
    [void]$sb.AppendLine("    const usefulLinksModal = document.getElementById('usefulLinksModal');")
    [void]$sb.AppendLine("    const usefulLinksCloseBtn = document.getElementById('usefulLinksCloseBtn');")
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
    [void]$sb.AppendLine("    function openGearGuideModal() { gearGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeGearGuideModal() { gearGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    gearGuideInfoBtn.addEventListener('click', openGearGuideModal);")
    [void]$sb.AppendLine("    gearGuideCloseBtn.addEventListener('click', closeGearGuideModal);")
    [void]$sb.AppendLine("    gearGuideModal.addEventListener('click', (ev) => { if (ev.target === gearGuideModal) closeGearGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && gearGuideModal.classList.contains('show')) closeGearGuideModal(); });")
    [void]$sb.AppendLine("    function openBoostGuideModal() { boostGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeBoostGuideModal() { boostGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    boostGuideInfoBtn.addEventListener('click', openBoostGuideModal);")
    [void]$sb.AppendLine("    boostGuideCloseBtn.addEventListener('click', closeBoostGuideModal);")
    [void]$sb.AppendLine("    boostGuideModal.addEventListener('click', (ev) => { if (ev.target === boostGuideModal) closeBoostGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && boostGuideModal.classList.contains('show')) closeBoostGuideModal(); });")
    [void]$sb.AppendLine("    function openDungeonGuideModal() { dungeonGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeDungeonGuideModal() { dungeonGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    dungeonGuideInfoBtn.addEventListener('click', openDungeonGuideModal);")
    [void]$sb.AppendLine("    dungeonGuideCloseBtn.addEventListener('click', closeDungeonGuideModal);")
    [void]$sb.AppendLine("    dungeonGuideModal.addEventListener('click', (ev) => { if (ev.target === dungeonGuideModal) closeDungeonGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && dungeonGuideModal.classList.contains('show')) closeDungeonGuideModal(); });")
    [void]$sb.AppendLine("    function openBestEidolonsModal() { bestEidolonsModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeBestEidolonsModal() { bestEidolonsModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    bestEidolonsInfoBtn.addEventListener('click', openBestEidolonsModal);")
    [void]$sb.AppendLine("    bestEidolonsCloseBtn.addEventListener('click', closeBestEidolonsModal);")
    [void]$sb.AppendLine("    bestEidolonsModal.addEventListener('click', (ev) => { if (ev.target === bestEidolonsModal) closeBestEidolonsModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && bestEidolonsModal.classList.contains('show')) closeBestEidolonsModal(); });")
    [void]$sb.AppendLine("    function openUsefulLinksModal() { usefulLinksModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeUsefulLinksModal() { usefulLinksModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    usefulLinksInfoBtn.addEventListener('click', openUsefulLinksModal);")
    [void]$sb.AppendLine("    usefulLinksCloseBtn.addEventListener('click', closeUsefulLinksModal);")
    [void]$sb.AppendLine("    usefulLinksModal.addEventListener('click', (ev) => { if (ev.target === usefulLinksModal) closeUsefulLinksModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && usefulLinksModal.classList.contains('show')) closeUsefulLinksModal(); });")
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

