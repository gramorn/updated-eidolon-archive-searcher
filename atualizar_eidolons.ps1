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
$EidolonWishesUrl = "https://www.aurakingdom-db.com/charts/eidolon-wishes"
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
        "H?ur" = "H�dur"
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

function Get-EidolonWishStatsTotals {
    param([string]$WishesUrl)

    try {
        $response = Invoke-WebRequest -Uri $WishesUrl -UseBasicParsing
        $html = $response.Content
        if (-not $html) {
            return @()
        }

        $statsTableMatch = [regex]::Match($html, '<div id="stats"[\s\S]*?<table[\s\S]*?</table>', 'IgnoreCase')
        if (-not $statsTableMatch.Success) {
            return @()
        }

        $statsTable = $statsTableMatch.Value

        $headerMatches = [regex]::Matches($statsTable, '<th[^>]*>(?<header>[^<]+)</th>', 'IgnoreCase')
        $rowMatch = [regex]::Match($statsTable, '<tbody>[\s\S]*?<tr>(?<row>[\s\S]*?)</tr>', 'IgnoreCase')
        if ($headerMatches.Count -eq 0 -or -not $rowMatch.Success) {
            return @()
        }

        $valueMatches = [regex]::Matches($rowMatch.Groups['row'].Value, '<td[^>]*>(?<value>[^<]*)</td>', 'IgnoreCase')
        if ($valueMatches.Count -eq 0) {
            return @()
        }

        $limit = [Math]::Min($headerMatches.Count, $valueMatches.Count)
        $totals = @()

        for ($i = 0; $i -lt $limit; $i++) {
            $name = [System.Web.HttpUtility]::HtmlDecode($headerMatches[$i].Groups['header'].Value).Trim()
            $value = [System.Web.HttpUtility]::HtmlDecode($valueMatches[$i].Groups['value'].Value).Trim()
            if ($name -and $value) {
                $totals += [pscustomobject]@{
                    Name = $name
                    Value = $value
                }
            }
        }

        return $totals
    } catch {
        Write-Warning ("Could not load Eidolon Wishes stat totals: " + $_.Exception.Message)
        return @()
    }
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
        [array]$DungeonGuideItems,
        [array]$WishStatsTotals,
        [pscustomobject]$LuckyPackTotals
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
    [void]$sb.AppendLine("  <!-- Google tag (gtag.js) -->")
    [void]$sb.AppendLine("  <script async src=`"https://www.googletagmanager.com/gtag/js?id=G-HDB0XXMDZ4`"></script>")
    [void]$sb.AppendLine("  <script>")
    [void]$sb.AppendLine("    window.dataLayer = window.dataLayer || [];")
    [void]$sb.AppendLine("    function gtag(){dataLayer.push(arguments);}")
    [void]$sb.AppendLine("    gtag('js', new Date());")
    [void]$sb.AppendLine("    gtag('config', 'G-HDB0XXMDZ4');")
    [void]$sb.AppendLine("  </script>")
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
    [void]$sb.AppendLine("    .theme-icon { display:inline-flex; align-items:center; justify-content:center; width:20px; height:20px; }")
    [void]$sb.AppendLine("    .theme-icon svg { display:block; width:20px; height:20px; }")
    [void]$sb.AppendLine("    .lang-selector { position:relative; display:none; align-items:center; gap:2px; }")
    [void]$sb.AppendLine("    .lang-btn { background:none; border:1px solid transparent; border-radius:6px; cursor:pointer; padding:3px 5px; line-height:1; display:none; align-items:center; transition:border-color 0.15s, background 0.15s; }")
    [void]$sb.AppendLine("    .lang-btn img { width:22px; height:15px; object-fit:cover; border-radius:2px; display:block; }")
    [void]$sb.AppendLine("    .lang-btn.active { display:inline-flex; border-color:var(--accent); }")
    [void]$sb.AppendLine("    .lang-selector.open .lang-btn { display:inline-flex; }")
    [void]$sb.AppendLine("    .lang-btn:hover { border-color:var(--line); background:var(--chip-bg); }")
    [void]$sb.AppendLine("    .lang-btn.active:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .lucky-pack-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .lucky-pack-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .lucky-pack-modal { width:min(680px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .lucky-pack-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .lucky-pack-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .lucky-pack-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .lucky-pack-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .lucky-pack-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .lucky-pack-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .lucky-pack-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .wish-coin-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .wish-coin-modal { width:min(680px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .wish-coin-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .wish-coin-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .wish-coin-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .wish-coin-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .wish-coin-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .wish-coin-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .limit-break-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .limit-break-modal { width:min(680px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
    [void]$sb.AppendLine("    .limit-break-modal h3 { margin:0 0 8px; font-size:1.02rem; color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-modal p { margin:0 0 8px; }")
    [void]$sb.AppendLine("    .limit-break-list { margin:6px 0 0; padding-left:18px; color:var(--ink); }")
    [void]$sb.AppendLine("    .limit-break-list li { margin:4px 0; }")
    [void]$sb.AppendLine("    .limit-break-actions { display:flex; justify-content:flex-end; margin-top:12px; }")
    [void]$sb.AppendLine("    .limit-break-close { height:36px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); cursor:pointer; padding:0 14px; }")
    [void]$sb.AppendLine("    .limit-break-close:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .leveling-guide-modal-backdrop { position:fixed; inset:0; background:rgba(3, 8, 18, 0.65); display:none; align-items:center; justify-content:center; z-index:80; padding:16px; }")
    [void]$sb.AppendLine("    .leveling-guide-modal-backdrop.show { display:flex; }")
    [void]$sb.AppendLine("    .leveling-guide-modal { width:min(760px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
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
    [void]$sb.AppendLine("    .q-white { background:#e5e7eb; color:#374151; }")
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
    [void]$sb.AppendLine("    .useful-links-modal { width:min(680px, 96vw); max-height:90vh; overflow:auto; background:var(--card); border:1px solid var(--line); border-radius:12px; padding:14px; box-shadow:0 20px 48px rgba(0,0,0,.45); }")
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
    [void]$sb.AppendLine("          <summary class=`"info-menu-toggle`" aria-label=`"Open info menu`" data-i18n=`"nav_guides`">Guides ?</summary>")
    [void]$sb.AppendLine("          <div class=`"info-menu-panel`">")
    [void]$sb.AppendLine("            <button id=`"luckyPackInfoBtn`" class=`"lucky-pack-btn`" type=`"button`" title=`"What are Eidolon Lucky Packs?`" aria-label=`"What are Eidolon Lucky Packs?`">What is <img class=`"lucky-pack-icon`" src=`"assets/icons/I80914.png`" alt=`"Eidolon Lucky Pack`">?</button>")
    [void]$sb.AppendLine("            <button id=`"wishCoinInfoBtn`" class=`"wish-coin-btn`" type=`"button`" title=`"What are Eidolon Wish Coins?`" aria-label=`"What are Eidolon Wish Coins?`">What is <img class=`"wish-coin-icon`" src=`"assets/icons/I81010.png`" alt=`"Eidolon Wish Coin`">?</button>")
    [void]$sb.AppendLine("            <button id=`"limitBreakInfoBtn`" class=`"limit-break-btn`" type=`"button`" title=`"What are Card Breakthrough Devices?`" aria-label=`"What are Card Breakthrough Devices?`">What is <img class=`"limit-break-icon`" src=`"assets/icons/I80781.png`" alt=`"Card Breakthrough Device`">?</button>")
    [void]$sb.AppendLine("            <button id=`"holyChestGuideInfoBtn`" class=`"boost-guide-btn`" type=`"button`" title=`"Holy Chest guide`" aria-label=`"Holy Chest guide`">Holy Chest</button>")
    [void]$sb.AppendLine("            <button id=`"levelingGuideInfoBtn`" class=`"leveling-guide-btn`" type=`"button`" title=`"How to level Eidolons from 25 to 80?`" aria-label=`"How to level Eidolons from 25 to 80?`">Eidolon Leveling</button>")
    [void]$sb.AppendLine("            <button id=`"gearGuideInfoBtn`" class=`"gear-guide-btn`" type=`"button`" title=`"How should I craft my gear?`" aria-label=`"How should I craft my gear?`">Gear Guide</button>")
    [void]$sb.AppendLine("            <button id=`"boostGuideInfoBtn`" class=`"boost-guide-btn`" type=`"button`" title=`"How can I increase my damage?`" aria-label=`"How can I increase my damage?`">Boost your damage</button>")
    [void]$sb.AppendLine("            <button id=`"eidolonStarsGuideInfoBtn`" class=`"boost-guide-btn`" type=`"button`" title=`"How to optimize Eidolon stars?`" aria-label=`"How to optimize Eidolon stars?`">Eidolon Stars</button>")
    [void]$sb.AppendLine("            <button id=`"dungeonGuideInfoBtn`" class=`"dungeon-guide-btn`" type=`"button`" title=`"Where can I find Eidolon spawn locations?`" aria-label=`"Where can I find Eidolon spawn locations?`">Eidolon Spawn Location</button>")
    [void]$sb.AppendLine("            <button id=`"bestEidolonsInfoBtn`" class=`"best-eidolons-btn`" type=`"button`" title=`"Open best eidolons guide`" aria-label=`"Open best eidolons guide`">Best Eidolons</button>")
    [void]$sb.AppendLine("            <button id=`"usefulLinksInfoBtn`" class=`"useful-links-btn`" type=`"button`" title=`"Open useful links`" aria-label=`"Open useful links`">Useful links</button>")
    [void]$sb.AppendLine("          </div>")
    [void]$sb.AppendLine("        </details>")
    [void]$sb.AppendLine("        <details class=`"info-menu`">")
    [void]$sb.AppendLine("          <summary class=`"info-menu-toggle`" aria-label=`"Open class guides menu`" data-i18n=`"nav_class_guides`">Class Guides ?</summary>")
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
    [void]$sb.AppendLine("        <div class='lang-selector' role='group' aria-label='Language'>")
    [void]$sb.AppendLine("          <button class='lang-btn active' data-lang='en' title='English' type='button'><img src='https://flagcdn.com/20x15/us.png' alt='English' width='20' height='15'/></button>")
    [void]$sb.AppendLine("          <button class='lang-btn' data-lang='pt' title='Portugu�s (Brasil)' type='button'><img src='https://flagcdn.com/20x15/br.png' alt='Portugu�s' width='20' height='15'/></button>")
    [void]$sb.AppendLine("          <button class='lang-btn' data-lang='es' title='Espa�ol' type='button'><img src='https://flagcdn.com/20x15/es.png' alt='Espa�ol' width='20' height='15'/></button>")
    [void]$sb.AppendLine("          <button class='lang-btn' data-lang='de' title='Deutsch' type='button'><img src='https://flagcdn.com/20x15/de.png' alt='Deutsch' width='20' height='15'/></button>")
    [void]$sb.AppendLine("          <button class='lang-btn' data-lang='fr' title='Fran�ais' type='button'><img src='https://flagcdn.com/20x15/fr.png' alt='Fran�ais' width='20' height='15'/></button>")
    [void]$sb.AppendLine("        </div>")
    [void]$sb.AppendLine("        <button id=`"aboutInfoBtn`" class=`"boost-guide-btn`" type=`"button`" title=`"About this project`" aria-label=`"About this project`">About</button>")
    [void]$sb.AppendLine("        <button id=`"themeToggle`" class=`"theme-toggle`" type=`"button`" aria-label=`"Switch to light theme`" title=`"Switch to light theme`"><span id=`"themeIcon`" class=`"theme-icon`"></span></button>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("    <input id=`"q`" class=`"search`" placeholder=`"Search by Eidolon, combo or bonus...`" data-i18n-placeholder=`"search_placeholder`" title=`"Type to filter combos by Eidolon, combo, or bonus`" aria-label=`"Search combos`">")
    [void]$sb.AppendLine("  </div></div>")
    [void]$sb.AppendLine("  <div id=`"luckyPackModal`" class=`"lucky-pack-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"luckyPackTitle`">")
    [void]$sb.AppendLine("    <div class=`"lucky-pack-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"luckyPackTitle`" data-i18n=`"modal_lucky_pack_title`">Eidolon Lucky Packs</h3>")
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
    [void]$sb.AppendLine("      <p>Current maximum level 8 intimacy totals based on the current Eidolon count:</p>")
    if ($LuckyPackTotals) {
        [void]$sb.AppendLine("      <ul class=`"lucky-pack-list`">")
        [void]$sb.AppendLine("        <li>Eidolons counted: $($LuckyPackTotals.EidolonCount)</li>")
        [void]$sb.AppendLine("        <li>DMG: $($LuckyPackTotals.DMG)</li>")
        [void]$sb.AppendLine("        <li>CRIT: $($LuckyPackTotals.CRIT)</li>")
        [void]$sb.AppendLine("        <li>SPD: $($LuckyPackTotals.SPD)</li>")
        [void]$sb.AppendLine("        <li>EVA: $($LuckyPackTotals.EVA)</li>")
        [void]$sb.AppendLine("        <li>HP: $($LuckyPackTotals.HP)</li>")
        [void]$sb.AppendLine("        <li>DEF: $($LuckyPackTotals.DEF)</li>")
        [void]$sb.AppendLine("      </ul>")
    }
    [void]$sb.AppendLine("      <div class=`"lucky-pack-actions`"><button id=`"luckyPackCloseBtn`" class=`"lucky-pack-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"wishCoinModal`" class=`"wish-coin-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"wishCoinTitle`">")
    [void]$sb.AppendLine("    <div class=`"wish-coin-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"wishCoinTitle`" data-i18n=`"modal_wish_coin_title`">Eidolon Wish Coins</h3>")
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
    [void]$sb.AppendLine("      <p>Current maximum stats from Eidolon Wishes (Stats Totals):</p>")
    if ($WishStatsTotals -and $WishStatsTotals.Count -gt 0) {
        [void]$sb.AppendLine("      <ul class=`"wish-coin-list`">")
        foreach ($stat in $WishStatsTotals) {
            $safeName = [System.Web.HttpUtility]::HtmlEncode([string]$stat.Name)
            $safeValue = [System.Web.HttpUtility]::HtmlEncode([string]$stat.Value)
            [void]$sb.AppendLine("        <li><strong>$($safeName):</strong> $($safeValue)</li>")
        }
        [void]$sb.AppendLine("      </ul>")
    } else {
        [void]$sb.AppendLine("      <p><em>Stats totals are currently unavailable from the source page.</em></p>")
    }
    [void]$sb.AppendLine("      <div class=`"wish-coin-actions`"><button id=`"wishCoinCloseBtn`" class=`"wish-coin-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"limitBreakModal`" class=`"limit-break-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"limitBreakTitle`">")
    [void]$sb.AppendLine("    <div class=`"limit-break-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"limitBreakTitle`" data-i18n=`"modal_limit_break_title`">Card Breakthrough Devices</h3>")
    [void]$sb.AppendLine("      <p>Card Breakthrough Devices are used to increase the breakthrough level of a card from 1 to 10.</p>")
    [void]$sb.AppendLine("      <p>Reaching level 10 unlocks the card's <strong>Status Bonus</strong>, applied permanently to your character.</p>")
    [void]$sb.AppendLine("      <p>Device tier required per level:</p>")
    [void]$sb.AppendLine("      <ul class=`"limit-break-list`">")
    [void]$sb.AppendLine("        <li>Levels 1�3: Basic Card Breakthrough Device</li>")
    [void]$sb.AppendLine("        <li>Levels 4�7: Intermediate Card Breakthrough Device</li>")
    [void]$sb.AppendLine("        <li>Levels 7�10: Advanced Card Breakthrough Device</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p>Current maximum status gains available from cards (full breakthrough) are shown below:</p>")
    [void]$sb.AppendLine("      <div class=`"boost-source-wrap`">")
    [void]$sb.AppendLine("        <table class=`"boost-source-table`">")
    [void]$sb.AppendLine("          <thead><tr><th>Stats</th><th>Bonus</th><th>Quantity</th><th>Total Bonus</th></tr></thead>")
    [void]$sb.AppendLine("          <tbody>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">DMG</td><td>179</td><td>132</td><td>23628</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">CRIT</td><td>70</td><td>133</td><td>9310</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">SPD</td><td>35</td><td>134</td><td>4690</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">HP</td><td>218</td><td>133</td><td>28994</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">DEF</td><td>56</td><td>134</td><td>7504</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">EVA</td><td>67</td><td>131</td><td>8777</td></tr>")
    [void]$sb.AppendLine("          </tbody>")
    [void]$sb.AppendLine("        </table>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <p>Prioritize reaching level 10 on cards with the strongest Status Bonuses for your build.</p>")
    [void]$sb.AppendLine("      <div class=`"limit-break-actions`"><button id=`"limitBreakCloseBtn`" class=`"limit-break-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"holyChestGuideModal`" class=`"limit-break-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"holyChestGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"limit-break-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"holyChestGuideTitle`">Holy Chest</h3>")
    [void]$sb.AppendLine("      <h4>Holy Chest Tips</h4>")
    [void]$sb.AppendLine("      <p>The Holy Chest is a system where you can slot up to <strong>9 gold weapons</strong>. The higher their fortification level, the stronger the bonuses you receive. Each weapon has its own Holy Chest bonus, which can be viewed by pressing <strong>TAB</strong> on the weapon's details.</p>")
    [void]$sb.AppendLine("      <p>The Holy Chest is <strong>shared across all characters on your account</strong>, but the bonuses only apply to characters whose level is <strong>equal to or lower than the weapon level</strong> inside the chest. This is why using <strong>Lv95 Abyss II weapons</strong> is recommended � they cover all current endgame characters.</p>")
    [void]$sb.AppendLine("      <ul>")
    [void]$sb.AppendLine("        <li><strong>Early goal � +15:</strong> Fortify your weapons to at least +15 to unlock the <strong>Dragon Points bonus</strong> and, for Abyss II weapons, the full elemental damage bonus.</li>")
    [void]$sb.AppendLine("        <li><strong>Final goal � +30:</strong> Reach +30 on all 9 weapons to unlock every bonus, including <strong>elemental penetration</strong> on Abyss II weapons.</li>")
    [void]$sb.AppendLine("        <li><strong>Best weapons to use:</strong> Lv95 Abyss II weapons (Hebe, Cerberus, Izanami, Michaela, Demeter, Hermes). They provide the highest bonuses at both +15 and +30.</li>")
    [void]$sb.AppendLine("        <li><strong>Best source of elemental damage:</strong> Each weapon gives up to <strong>17% damage against a specific element</strong>, for a maximum of <strong>153% elemental damage</strong> across all 9 slots.</li>")
    [void]$sb.AppendLine("        <li><strong>Priority elements:</strong> Focus on <strong>Dark, Lightning, Storm, and Ice</strong> � these are the main elements needed for Vault of Eternity (floors 8�12, party).</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <h4>Awakening Holy Chest</h4>")
    [void]$sb.AppendLine("      <p>This table shows the success percentage for upgrading the AHC level for different gold weapon levels. The higher the weapon level, the less fortification is needed to achieve a higher success percentage.</p>")
    [void]$sb.AppendLine("      <h5>Fortification Chance Table</h5>")
    [void]$sb.AppendLine("      <div class=`"boost-source-wrap`">")
    [void]$sb.AppendLine("        <table class=`"boost-source-table`">")
    [void]$sb.AppendLine("          <thead><tr><th>Fortification Level</th><th>Lv65</th><th>Lv75</th><th>Lv85</th><th>Lv95</th><th>Lv105</th><th>Lv115</th><th>Lv125</th><th>Slv5</th><th>Slv15</th><th>Slv25</th><th>Slv35</th></tr></thead>")
    [void]$sb.AppendLine("          <tbody>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">11</td><td>0.71%</td><td>0.82%</td><td>0.94%</td><td>1.04%</td><td>1.15%</td><td>1.26%</td><td>1.38%</td><td>1.16%</td><td>1.27%</td><td>1.38%</td><td>1.49%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">12</td><td>1.63%</td><td>1.88%</td><td>2.13%</td><td>2.38%</td><td>2.63%</td><td>2.88%</td><td>3.13%</td><td>2.63%</td><td>2.88%</td><td>3.13%</td><td>3.38%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">13</td><td>2.60%</td><td>3.00%</td><td>3.40%</td><td>3.80%</td><td>4.20%</td><td>4.60%</td><td>5.00%</td><td>4.20%</td><td>4.60%</td><td>5.00%</td><td>5.40%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">14</td><td>3.90%</td><td>4.50%</td><td>5.10%</td><td>5.70%</td><td>6.30%</td><td>6.90%</td><td>7.25%</td><td>6.30%</td><td>6.90%</td><td>7.50%</td><td>8.10%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">15</td><td>5.53%</td><td>6.38%</td><td>7.22%</td><td>8.08%</td><td>8.93%</td><td>9.77%</td><td>10.63%</td><td>8.93%</td><td>9.78%</td><td>10.60%</td><td>11.40%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">16</td><td>7.67%</td><td>8.85%</td><td>10.03%</td><td>11.21%</td><td>12.39%</td><td>13.57%</td><td>14.75%</td><td>12.39%</td><td>13.57%</td><td>14.70%</td><td>15.90%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">17</td><td>10.20%</td><td>11.78%</td><td>13.35%</td><td>14.91%</td><td>16.49%</td><td>18.06%</td><td>19.63%</td><td>16.48%</td><td>18.06%</td><td>19.60%</td><td>21.20%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">18</td><td>12.93%</td><td>14.93%</td><td>16.92%</td><td>18.91%</td><td>20.90%</td><td>22.88%</td><td>24.88%</td><td>20.90%</td><td>22.89%</td><td>24.80%</td><td>26.80%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">19</td><td>16.38%</td><td>18.90%</td><td>21.42%</td><td>23.94%</td><td>26.46%</td><td>28.98%</td><td>31.50%</td><td>26.46%</td><td>28.98%</td><td>31.50%</td><td>34.00%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">20</td><td>20.80%</td><td>24.00%</td><td>27.20%</td><td>30.40%</td><td>33.60%</td><td>36.80%</td><td>40.00%</td><td>33.60%</td><td>36.80%</td><td>40.00%</td><td>43.20%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">21</td><td>23.07%</td><td>26.62%</td><td>30.18%</td><td>33.72%</td><td>37.27%</td><td>40.82%</td><td>44.38%</td><td>37.28%</td><td>40.83%</td><td>44.30%</td><td>47.90%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">22</td><td>26.00%</td><td>30.00%</td><td>34.00%</td><td>38.00%</td><td>42.00%</td><td>46.00%</td><td>50.00%</td><td>42.00%</td><td>46.00%</td><td>50.00%</td><td>54.00%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">23</td><td>29.44%</td><td>33.97%</td><td>38.51%</td><td>43.03%</td><td>47.56%</td><td>52.10%</td><td>56.63%</td><td>47.57%</td><td>52.09%</td><td>56.60%</td><td>61.10%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">24</td><td>33.34%</td><td>38.48%</td><td>43.61%</td><td>48.74%</td><td>53.86%</td><td>59.00%</td><td>64.13%</td><td>53.87%</td><td>59.00%</td><td>64.10%</td><td>69.20%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">25</td><td>37.76%</td><td>43.57%</td><td>49.38%</td><td>55.19%</td><td>61.00%</td><td>66.81%</td><td>72.62%</td><td>61.01%</td><td>66.82%</td><td>72.60%</td><td>78.40%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">26</td><td>42.51%</td><td>49.05%</td><td>55.59%</td><td>62.13%</td><td>68.67%</td><td>75.21%</td><td>81.75%</td><td>68.67%</td><td>75.21%</td><td>81.70%</td><td>88.20%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">27</td><td>47.38%</td><td>54.67%</td><td>61.97%</td><td>69.25%</td><td>76.54%</td><td>83.83%</td><td>91.13%</td><td>76.55%</td><td>83.84%</td><td>91.10%</td><td>98.40%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">28</td><td>52.39%</td><td>60.45%</td><td>68.51%</td><td>76.57%</td><td>84.63%</td><td>92.69%</td><td>100.00%</td><td>84.63%</td><td>92.69%</td><td>100.00%</td><td>100.00%</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">29</td><td>58.63%</td><td>67.65%</td><td>76.67%</td><td>85.69%</td><td>94.71%</td><td>100.00%</td><td>100.00%</td><td>94.71%</td><td>100.00%</td><td>-</td><td>-</td></tr>")
    [void]$sb.AppendLine("            <tr><td class=`"item-name`">30</td><td>65.00%</td><td>75.00%</td><td>85.00%</td><td>95.00%</td><td>100.00%</td><td>100.00%</td><td>100.00%</td><td>100.00%</td><td>-</td><td>-</td><td>-</td></tr>")
    [void]$sb.AppendLine("          </tbody>")
    [void]$sb.AppendLine("        </table>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"limit-break-actions`"><button id=`"holyChestGuideCloseBtn`" class=`"limit-break-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"levelingGuideModal`" class=`"leveling-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"levelingGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"leveling-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"levelingGuideTitle`" data-i18n=`"modal_leveling_title`">Eidolon Leveling</h3>")
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
    [void]$sb.AppendLine("        <h4>Skill Upgrade Points</h4>")
    [void]$sb.AppendLine("        <p>Upgrading Eidolon skills earns <strong>Skill Upgrade Points</strong> based on the skill's quality. Only the points of the current highest quality are counted and do not accumulate. Skills from different Eidolons on the same account can be accumulated.</p>")
    [void]$sb.AppendLine("        <ul class=`"skill-leveling-grid`">")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-white`">White</span><span>0 pts</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-green`">Green</span><span>10 pts</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-blue`">Blue</span><span>50 pts</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-orange`">Orange</span><span>140 pts</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-purple`">Purple</span><span>300 pts</span></li>")
    [void]$sb.AppendLine("          <li><span class=`"quality-chip q-gold`">Gold</span><span>550 pts</span></li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <p><em>The Total Skill Upgrade Points refer to the sum of the Skill Upgrade Points of all Eidolons in the account. Points for different skills of the same Eidolon are calculated separately.</em></p>")
    [void]$sb.AppendLine("        <h4>Reward Milestone</h4>")
    [void]$sb.AppendLine("        <p>At <strong>4520 total points</strong> you unlock the following permanent bonuses:</p>")
    [void]$sb.AppendLine("        <ul>")
    [void]$sb.AppendLine("          <li>14% All Attribute Damage</li>")
    [void]$sb.AppendLine("          <li>15% DMG to Bosses</li>")
    [void]$sb.AppendLine("          <li>5% Penetration</li>")
    [void]$sb.AppendLine("          <li>16% Detail Damage</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"leveling-guide-actions`"><button id=`"levelingGuideCloseBtn`" class=`"leveling-guide-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"gearGuideModal`" class=`"gear-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"gearGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"gear-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"gearGuideTitle`" data-i18n=`"modal_gear_title`">Gear Guide</h3>")
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
    [void]$sb.AppendLine("          <li><strong>Piercing Secret Stone</strong> � Best in slot, but expensive.</li>")
    [void]$sb.AppendLine("          <li><strong>Lava Secret Stone</strong> � Cheaper than Piercing, and can be farmed in Pyroclastic Purgatory.</li>")
    [void]$sb.AppendLine("          <li><strong>Orange Class Master Stone</strong> � Use as a placeholder before getting Lava or better.</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"gear-guide-box`">")
    [void]$sb.AppendLine("        <h4>Armor Secret Stone</h4>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">Purchase them at your class Master in Navea. They will be orange � don't worry about the stats. Level them to 70, then upgrade to purple to add one more stat, and they are ready to reroll.</p>")
    [void]$sb.AppendLine("        <h5>Best Stats to Aim For (Rerolling)</h5>")
    [void]$sb.AppendLine("        <ul class=`"gear-guide-list`">")
    [void]$sb.AppendLine("          <li><strong>Detail-DMG</strong> (or DMG): +5 / +4 / +3</li>")
    [void]$sb.AppendLine("          <li><strong>CRIT DMG:</strong> +10 / +8 / +6</li>")
    [void]$sb.AppendLine("        </ul>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">Always aim for <strong>Detail-DMG +5%</strong> or at least <strong>DMG +4%</strong>. The most common strategy is to get <strong>Detail-DMG +5</strong> on the last line, then use a <strong>DMG + Something reroll potion</strong> to aim for double Detail-DMG on the stone.</p>")
    [void]$sb.AppendLine("        <p class=`"gear-guide-note`">With enough economy, you can push further and get a stone with <strong>three damage stats</strong> � for example: <em>The DMG caused is increased by 6% / DMG +3% / Detail-DMG +5%</em>.</p>")
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
    [void]$sb.AppendLine("      <h3 id=`"boostGuideTitle`" data-i18n=`"modal_boost_title`">Boost your damage</h3>")
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
    [void]$sb.AppendLine("              <tr><td class=`"item-name`" rowspan=`"4`">Dual Drive</td><td>Weapon cards</td><td>8%</td><td>80%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>Eidolon 1-2 Star</td><td>5%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>Eidolon 3-4 Star</td><td>10%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>Pet</td><td>4%-6%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Back Striker</td><td>Hit behind boss</td><td>100%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Rapid Assault</td><td>SPD over cap bonus</td><td>0.1%-20%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Combo</td><td>Eidolon Archive</td><td>2%-21%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Holy Chest +240</td><td>8 Weapons +30</td><td>4%</td><td>50%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Zeal</td><td>Attack spec mastery</td><td>10%</td><td>110%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Food / Drink</td><td>Lv101 or Above</td><td>15%</td><td>110%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Supreme Sword Soul</td><td>Holy Spirit</td><td>10%</td><td>179%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Book of Destruction</td><td>Trophy</td><td>20%</td><td>75%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Void Calamity</td><td>Trophy</td><td>10%</td><td>135%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`">Time and Years trophy fort +25</td><td>Trophy</td><td>5%</td><td>90%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`" rowspan=`"2`">Sacred Sky Soul Bead</td><td rowspan=`"2`">Buff</td><td>10%</td><td>75%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>10%</td><td>125%</td></tr>")
    [void]$sb.AppendLine("              <tr><td class=`"item-name`" rowspan=`"2`">Torque Motor</td><td rowspan=`"2`">Buff</td><td>5%</td><td>150%</td></tr>")
    [void]$sb.AppendLine("              <tr><td>1%</td><td>175%</td></tr>")
    [void]$sb.AppendLine("            </tbody>")
    [void]$sb.AppendLine("          </table>")
    [void]$sb.AppendLine("        </div>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"boost-guide-actions`"><button id=`"boostGuideCloseBtn`" class=`"boost-guide-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"eidolonStarsGuideModal`" class=`"limit-break-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"eidolonStarsGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"limit-break-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"eidolonStarsGuideTitle`">Eidolon Stars</h3>")
    [void]$sb.AppendLine("      <p>Each Eidolon can have up to 4 star bonuses, unlocked by leveling and evolving the Eidolon.</p>")
    [void]$sb.AppendLine("      <p>Stars 1 and 2 provide lower-tier bonuses, while stars 3 and 4 provide higher-tier bonuses.</p>")
    [void]$sb.AppendLine("      <p>For star stats, the standard recommendation is to keep <strong>1 lower-tier and 1 higher-tier damage bonus for your element</strong>. The other 2 bonuses should be selected based on your build and current stats.</p>")
    [void]$sb.AppendLine("      <h4>Case 1: Carry all dungeons and VoE 1-9</h4>")
    [void]$sb.AppendLine("      <p><strong>If Total CDMG is 40+ below Cap CDMG:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li><strong>X (lower-tier):</strong> 20 CDMG / 8% DMG / 5% Double Attack</li>")
    [void]$sb.AppendLine("        <li><strong>Y (higher-tier):</strong> 40 CDMG / 16% DMG / 10% Double Attack</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p><strong>If CDMG is at Cap CDMG:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li><strong>X (lower-tier):</strong> 8% DMG / 5% Double Attack / 15% DMG to elementals</li>")
    [void]$sb.AppendLine("        <li><strong>Y (higher-tier):</strong> 16% DMG / 10% Double Attack / 30% DMG to elementals</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <h4>Case 2: Carry VoE 1-12</h4>")
    [void]$sb.AppendLine("      <p><strong>If Total CDMG is 40+ below Cap CDMG:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li><strong>X (lower-tier):</strong> 20 CDMG / 8% DMG / 5% Double Attack</li>")
    [void]$sb.AppendLine("        <li><strong>Y (higher-tier):</strong> 40 CDMG / 10% Double Attack / 8% DMG</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p><strong>If CDMG is at Cap CDMG:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li><strong>X (lower-tier):</strong> 5% Double Attack / 15% DMG to elementals / 8% DMG</li>")
    [void]$sb.AppendLine("        <li><strong>Y (higher-tier):</strong> 10% Double Attack / 30% DMG to elementals / 16% DMG</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <h4>Examples</h4>")
    [void]$sb.AppendLine("      <p><strong>If CDMG is not close to cap:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li>Star 1: Fire Skill Damage 15%</li>")
    [void]$sb.AppendLine("        <li>Star 2: Crit Damage +20%</li>")
    [void]$sb.AppendLine("        <li>Star 3: Fire Skill Damage +30%</li>")
    [void]$sb.AppendLine("        <li>Star 4: Crit Damage +40%</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p><strong>If CDMG is close to cap:</strong></p>")
    [void]$sb.AppendLine("      <ul class=`"boost-source-list`">")
    [void]$sb.AppendLine("        <li>Star 1: Fire Skill Damage 15%</li>")
    [void]$sb.AppendLine("        <li>Star 2: Double Attack 5%</li>")
    [void]$sb.AppendLine("        <li>Star 3: Fire Skill Damage +30%</li>")
    [void]$sb.AppendLine("        <li>Star 4: Double Attack 10%</li>")
    [void]$sb.AppendLine("      </ul>")
    [void]$sb.AppendLine("      <p><strong>Notes:</strong> Total CDMG = Primary CDMG + CDMG against bosses.</p>")
    [void]$sb.AppendLine("      <p>If your CDMG is only 20 to 30 below Cap CDMG, use X from Case 2.1 and Y from Case 2.2.</p>")
    [void]$sb.AppendLine("      <p><strong>Credits:</strong> Van</p>")
    [void]$sb.AppendLine("      <div class=`"limit-break-actions`"><button id=`"eidolonStarsGuideCloseBtn`" class=`"limit-break-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"aboutModal`" class=`"limit-break-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"aboutModalTitle`">")
    [void]$sb.AppendLine("    <div class=`"limit-break-modal`" style=`"max-width:560px`">")
    [void]$sb.AppendLine("      <h3 id=`"aboutModalTitle`">About this Project</h3>")
    [void]$sb.AppendLine("      <p>The goal of this project is to provide an updated and user-friendly information hub for the entire Aura Kingdom community.</p>")
    [void]$sb.AppendLine("      <p>The Eidolon archive is <strong>automatically updated every Thursday</strong> to keep the data fresh even without manual maintenance.</p>")
    [void]$sb.AppendLine("      <p>If you find any bugs, want to contribute information, or help with a class guide, feel free to reach out on Discord: <strong>gramorn</strong>.</p>")
    [void]$sb.AppendLine("      <hr style=`"border-color:rgba(255,255,255,0.15);margin:14px 0`">")
    [void]$sb.AppendLine("      <p><strong>Special thanks</strong> to everyone who helped gather information:</p>")
    [void]$sb.AppendLine("      <p style=`"text-align:center;font-size:1.05em`">Van &nbsp;&bull;&nbsp; CherryLips &nbsp;&bull;&nbsp; Leonhart</p>")
    [void]$sb.AppendLine("      <div class=`"limit-break-actions`"><button id=`"aboutCloseBtn`" class=`"limit-break-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"dungeonGuideModal`" class=`"dungeon-guide-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"dungeonGuideTitle`">")
    [void]$sb.AppendLine("    <div class=`"dungeon-guide-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"dungeonGuideTitle`" data-i18n=`"modal_dungeon_title`">Eidolon Spawn Location</h3>")
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
    [void]$sb.AppendLine("      <h3 id=`"bestEidolonsTitle`" data-i18n=`"modal_best_eidolons_title`">Best Eidolons</h3>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-warning`"><strong>Outdated list:</strong> this information is from July 2024 and may no longer reflect the current best choices.</div>")
    [void]$sb.AppendLine("      <p class=`"best-eidolons-legend`"><span class='eido-sym'>&#9733;</span> = Great with Eidolon Symbol</p>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-grid`">")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Universal Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Best DPS for any build. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00099.png' alt='Otohime' loading='lazy'><span><strong>Otohime:</strong> Top DPS with 10s zeal buff. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00055.png' alt='Tyr' loading='lazy'><span><strong>Tyr:</strong> Best flat DEF shred for any class. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00096.png' alt='Persephone' loading='lazy'><span><strong>Persephone:</strong> 10s DMG &amp; debuff immunity � disable auto-skills and activate manually. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00138.png' alt='Da Qiao' loading='lazy'><span><strong>Da Qiao:</strong> Emergency party healing. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00066.png' alt='Eirene' loading='lazy'><span><strong>Eirene:</strong> Debuff cleanse + 4s DMG &amp; debuff immunity. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Dark Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00077.png' alt='NY Muramasa' loading='lazy'><span><strong>NY Muramasa<span class='eido-sym'>&#9733;</span>:</strong> Main DPS with 5s zeal buff. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00137.png' alt='Eris' loading='lazy'><span><strong>Eris<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00068.png' alt='Hades' loading='lazy'><span><strong>Hades<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00106.png' alt='NY Succubus' loading='lazy'><span><strong>NY Succubus:</strong> Flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00062.png' alt='Muramasa' loading='lazy'><span><strong>Muramasa:</strong> Flat DEF shred. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00073.png' alt='Nidhogg' loading='lazy'><span><strong>Nidhogg<span class='eido-sym'>&#9733;</span>:</strong> Main DPS &ndash; no skill upgrades needed.</span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Holy Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00156.png' alt='Guan Yu' loading='lazy'><span><strong>Guan Yu<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00140.png' alt='Gaia' loading='lazy'><span><strong>Gaia<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00098.png' alt='Summer Michaela' loading='lazy'><span><strong>Summer Michaela<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00144.png' alt='Christmas Andrea' loading='lazy'><span><strong>Christmas Andrea:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00072.png' alt='Idunn' loading='lazy'><span><strong>Idunn:</strong> Flat DEF shred + 8s debuff immunity. <span class='best-upgrade-tag'>2nd upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00045.png' alt='Alice' loading='lazy'><span><strong>Alice:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Flame Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Main DPS with 8s zeal buff. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00162.png' alt='Cinderella' loading='lazy'><span><strong>Cinderella:</strong> Flat DEF shred + debuff removal. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00151.png' alt='Liu Bei' loading='lazy'><span><strong>Liu Bei<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00120.png' alt='NY Elizabeth' loading='lazy'><span><strong>NY Elizabeth:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00142.png' alt='Anubis' loading='lazy'><span><strong>Anubis<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00121.png' alt='Little Red Riding Hood' loading='lazy'><span><strong>Little Red Riding Hood<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00087.png' alt='Halloween Zashi' loading='lazy'><span><strong>Halloween Zashi<span class='eido-sym'>&#9733;</span>:</strong> Main DPS &ndash; no skill upgrades needed.</span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Storm Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00152.png' alt='Summer Rachel' loading='lazy'><span><strong>Summer Rachel:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00148.png' alt='Odin' loading='lazy'><span><strong>Odin<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00112.png' alt='Summer Persephone' loading='lazy'><span><strong>Summer Persephone<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00048.png' alt='Yumikaze' loading='lazy'><span><strong>Yumikaze<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00081.png' alt='Sif' loading='lazy'><span><strong>Sif<span class='eido-sym'>&#9733;</span>:</strong> Emergency healing. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Ice Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00150.png' alt='Poseidon' loading='lazy'><span><strong>Poseidon:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00118.png' alt='Christmas Idunn' loading='lazy'><span><strong>Christmas Idunn<span class='eido-sym'>&#9733;</span>:</strong> Main DPS + flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00145.png' alt='Christmas Sakuya-hime' loading='lazy'><span><strong>Christmas Sakuya-hime<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00157.png' alt='Christmas Little Red Riding Hood' loading='lazy'><span><strong>Christmas Little Red Riding Hood<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00054.png' alt='Lumikki' loading='lazy'><span><strong>Lumikki:</strong> Flat DEF shred. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00066.png' alt='Eirene' loading='lazy'><span><strong>Eirene:</strong> Debuff cleanse + 4s DMG &amp; debuff immunity. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Lightning Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00147.png' alt='Zhang Fei' loading='lazy'><span><strong>Zhang Fei:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00114.png' alt='Rachel' loading='lazy'><span><strong>Rachel<span class='eido-sym'>&#9733;</span>:</strong> Main DPS. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00127.png' alt='Frigga' loading='lazy'><span><strong>Frigga<span class='eido-sym'>&#9733;</span>:</strong> Flat DEF shred + debuff removal. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00159.png' alt='New Year Anubis' loading='lazy'><span><strong>New Year Anubis:</strong> Fast debuffs for short fights. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00111.png' alt='Salome' loading='lazy'><span><strong>Salome<span class='eido-sym'>&#9733;</span>:</strong> Fast debuffs for short fights. <span class='best-upgrade-tag'>1st upgrade</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00122.png' alt='Komainu' loading='lazy'><span><strong>Komainu:</strong> Long-duration party buff. <span class='best-upgrade-tag'>1st upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("        <section class='best-eidolons-section'><h4>Physical Eidolons</h4><ul class='best-eidolons-list'><li><img class='best-eido-icon' src='assets/eidolons/P00146.png' alt='NY Queen of Hearts' loading='lazy'><span><strong>NY Queen of Hearts:</strong> Main DPS with 8s zeal buff. <span class='best-upgrade-tag'>all upgrades</span></span></li><li><img class='best-eido-icon' src='assets/eidolons/P00140.png' alt='Gaia' loading='lazy'><span><strong>Gaia<span class='eido-sym'>&#9733;</span>:</strong> Weak physical skill DMG buff &ndash; last resort only. <span class='best-upgrade-tag'>2nd upgrade</span></span></li></ul></section>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-footer`"><p>I do not know who should be credited for this information. If this is your information and you want credit, feel free to contact me on Discord.</p></div>")
    [void]$sb.AppendLine("      <div class=`"best-eidolons-actions`"><button id=`"bestEidolonsCloseBtn`" class=`"best-eidolons-close`" type=`"button`">Close</button></div>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("  </div>")
    [void]$sb.AppendLine("  <div id=`"usefulLinksModal`" class=`"useful-links-modal-backdrop`" role=`"dialog`" aria-modal=`"true`" aria-labelledby=`"usefulLinksTitle`">")
    [void]$sb.AppendLine("    <div class=`"useful-links-modal`">")
    [void]$sb.AppendLine("      <h3 id=`"usefulLinksTitle`" data-i18n=`"modal_useful_links_title`">Useful links</h3>")
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
    [void]$sb.AppendLine("      <h3 id=`"classGuideTitle`" data-i18n=`"modal_class_guide_title`">Class Guides</h3>")
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
    [void]$sb.AppendLine("    const holyChestGuideInfoBtn = document.getElementById('holyChestGuideInfoBtn');")
    [void]$sb.AppendLine("    const holyChestGuideModal = document.getElementById('holyChestGuideModal');")
    [void]$sb.AppendLine("    const holyChestGuideCloseBtn = document.getElementById('holyChestGuideCloseBtn');")
    [void]$sb.AppendLine("    const levelingGuideInfoBtn = document.getElementById('levelingGuideInfoBtn');")
    [void]$sb.AppendLine("    const levelingGuideModal = document.getElementById('levelingGuideModal');")
    [void]$sb.AppendLine("    const levelingGuideCloseBtn = document.getElementById('levelingGuideCloseBtn');")
    [void]$sb.AppendLine("    const gearGuideInfoBtn = document.getElementById('gearGuideInfoBtn');")
    [void]$sb.AppendLine("    const gearGuideModal = document.getElementById('gearGuideModal');")
    [void]$sb.AppendLine("    const gearGuideCloseBtn = document.getElementById('gearGuideCloseBtn');")
    [void]$sb.AppendLine("    const boostGuideInfoBtn = document.getElementById('boostGuideInfoBtn');")
    [void]$sb.AppendLine("    const boostGuideModal = document.getElementById('boostGuideModal');")
    [void]$sb.AppendLine("    const boostGuideCloseBtn = document.getElementById('boostGuideCloseBtn');")
    [void]$sb.AppendLine("    const eidolonStarsGuideInfoBtn = document.getElementById('eidolonStarsGuideInfoBtn');")
    [void]$sb.AppendLine("    const eidolonStarsGuideModal = document.getElementById('eidolonStarsGuideModal');")
    [void]$sb.AppendLine("    const eidolonStarsGuideCloseBtn = document.getElementById('eidolonStarsGuideCloseBtn');")
    [void]$sb.AppendLine("    const dungeonGuideInfoBtn = document.getElementById('dungeonGuideInfoBtn');")
    [void]$sb.AppendLine("    const dungeonGuideModal = document.getElementById('dungeonGuideModal');")
    [void]$sb.AppendLine("    const dungeonGuideCloseBtn = document.getElementById('dungeonGuideCloseBtn');")
    [void]$sb.AppendLine("    const bestEidolonsInfoBtn = document.getElementById('bestEidolonsInfoBtn');")
    [void]$sb.AppendLine("    const bestEidolonsModal = document.getElementById('bestEidolonsModal');")
    [void]$sb.AppendLine("    const bestEidolonsCloseBtn = document.getElementById('bestEidolonsCloseBtn');")
    [void]$sb.AppendLine("    const usefulLinksInfoBtn = document.getElementById('usefulLinksInfoBtn');")
    [void]$sb.AppendLine("    const usefulLinksModal = document.getElementById('usefulLinksModal');")
    [void]$sb.AppendLine("    const usefulLinksCloseBtn = document.getElementById('usefulLinksCloseBtn');")
    [void]$sb.AppendLine("    const aboutInfoBtn = document.getElementById('aboutInfoBtn');")
    [void]$sb.AppendLine("    const aboutModal = document.getElementById('aboutModal');")
    [void]$sb.AppendLine("    const aboutCloseBtn = document.getElementById('aboutCloseBtn');")
    [void]$sb.AppendLine("    function applyTheme(theme) {")
    [void]$sb.AppendLine("      const t = (theme === 'light') ? 'light' : 'dark';")
    [void]$sb.AppendLine("      document.body.setAttribute('data-theme', t);")
    [void]$sb.AppendLine("      document.body.style.backgroundColor = (t === 'dark') ? '#0f141d' : '#fff6ef';")
    [void]$sb.AppendLine("      themeIcon.innerHTML = (t === 'dark')")
    [void]$sb.AppendLine("        ? '<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"white\" aria-hidden=\"true\"><circle cx=\"12\" cy=\"12\" r=\"5\"/><g stroke=\"white\" stroke-width=\"2\" stroke-linecap=\"round\"><line x1=\"12\" y1=\"2\" x2=\"12\" y2=\"5\"/><line x1=\"12\" y1=\"19\" x2=\"12\" y2=\"22\"/><line x1=\"2\" y1=\"12\" x2=\"5\" y2=\"12\"/><line x1=\"19\" y1=\"12\" x2=\"22\" y2=\"12\"/><line x1=\"4.22\" y1=\"4.22\" x2=\"6.34\" y2=\"6.34\"/><line x1=\"17.66\" y1=\"17.66\" x2=\"19.78\" y2=\"19.78\"/><line x1=\"19.78\" y1=\"4.22\" x2=\"17.66\" y2=\"6.34\"/><line x1=\"6.34\" y1=\"17.66\" x2=\"4.22\" y2=\"19.78\"/></g></svg>'")
    [void]$sb.AppendLine("        : '<svg xmlns=\"http://www.w3.org/2000/svg\" viewBox=\"0 0 24 24\" fill=\"black\" aria-hidden=\"true\"><path d=\"M21 12.79A9 9 0 1 1 11.21 3a7 7 0 0 0 9.79 9.79z\"/></svg>';")
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
    [void]$sb.AppendLine("    function openHolyChestGuideModal() { holyChestGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeHolyChestGuideModal() { holyChestGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    holyChestGuideInfoBtn.addEventListener('click', openHolyChestGuideModal);")
    [void]$sb.AppendLine("    holyChestGuideCloseBtn.addEventListener('click', closeHolyChestGuideModal);")
    [void]$sb.AppendLine("    holyChestGuideModal.addEventListener('click', (ev) => { if (ev.target === holyChestGuideModal) closeHolyChestGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && holyChestGuideModal.classList.contains('show')) closeHolyChestGuideModal(); });")
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
    [void]$sb.AppendLine("    function openEidolonStarsGuideModal() { eidolonStarsGuideModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeEidolonStarsGuideModal() { eidolonStarsGuideModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    eidolonStarsGuideInfoBtn.addEventListener('click', openEidolonStarsGuideModal);")
    [void]$sb.AppendLine("    eidolonStarsGuideCloseBtn.addEventListener('click', closeEidolonStarsGuideModal);")
    [void]$sb.AppendLine("    eidolonStarsGuideModal.addEventListener('click', (ev) => { if (ev.target === eidolonStarsGuideModal) closeEidolonStarsGuideModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && eidolonStarsGuideModal.classList.contains('show')) closeEidolonStarsGuideModal(); });")
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
    [void]$sb.AppendLine("    function openAboutModal() { aboutModal.classList.add('show'); }")
    [void]$sb.AppendLine("    function closeAboutModal() { aboutModal.classList.remove('show'); }")
    [void]$sb.AppendLine("    aboutInfoBtn.addEventListener('click', openAboutModal);")
    [void]$sb.AppendLine("    aboutCloseBtn.addEventListener('click', closeAboutModal);")
    [void]$sb.AppendLine("    aboutModal.addEventListener('click', (ev) => { if (ev.target === aboutModal) closeAboutModal(); });")
    [void]$sb.AppendLine("    document.addEventListener('keydown', (ev) => { if (ev.key === 'Escape' && aboutModal.classList.contains('show')) closeAboutModal(); });")
    # i18n
    $translationsJs = @'
    const TRANSLATIONS = {
      en: {
        nav_guides: "Guides \u25be",
        nav_class_guides: "Class Guides \u25be",
        btn_what_is: "What is",
        btn_eidolon_leveling: "Eidolon Leveling",
        btn_gear_guide: "Gear Guide",
        btn_boost_damage: "Boost your damage",
        btn_spawn_location: "Eidolon Spawn Location",
        btn_best_eidolons: "Best Eidolons",
        btn_useful_links: "Useful links",
        btn_close: "Close",
        search_placeholder: "Search by Eidolon, combo or bonus...",
        modal_best_eidolons_title: "Best Eidolons",
        modal_best_eidolons_warning_label: "Outdated list:",
        modal_best_eidolons_warning_text: " this information is from July 2024 and may no longer reflect the current best choices.",
        modal_best_eidolons_legend: "= Great with Eidolon Symbol",
        modal_best_eidolons_footer: "I do not know who should be credited for this information. If this is your information and you want credit, feel free to contact me on Discord.",
        section_universal: "Universal Eidolons",
        section_dark: "Dark Eidolons",
        section_holy: "Holy Eidolons",
        section_flame: "Flame Eidolons",
        section_storm: "Storm Eidolons",
        section_ice: "Ice Eidolons",
        section_lightning: "Lightning Eidolons",
        section_physical: "Physical Eidolons",
        modal_useful_links_title: "Useful links",
        modal_useful_links_intro: "Community guides and resources.",
        modal_class_guide_title: "Class Guides",
        modal_class_guide_intro: "This menu is ready for class-by-class Aura Kingdom guides.",
        modal_lucky_pack_title: "Eidolon Lucky Packs",
        modal_lucky_pack_p1: "Eidolon Lucky Packs are used at the Eidolon Den in your house to level up intimacy.",
        modal_lucky_pack_p2: "The basic stats gained by intimacy leveling are applied to your character:",
        modal_lucky_pack_p3: "Because of this, all Eidolons should be leveled to at least intimacy level 8. It usually takes about 280 Eidolon Lucky Packs to go from level 1 to 8. Level 10 is optional.",
        modal_wish_coin_title: "Eidolon Wish Coins",
        modal_wish_coin_p1: "Wish Coins are used to fulfill an Eidolon's wish without needing to gather what they ask for. They are a shortcut to fulfill wishes.",
        modal_wish_coin_p2: "All stats gained this way are applied to your character.",
        modal_wish_coin_cost: "Wish Coin cost per wish level:",
        modal_wish_coin_outro: "All Eidolons should have their wishes fulfilled. This is one of the greatest sources of raw stats.",
        modal_limit_break_title: "Card Breakthrough Devices",
        modal_limit_break_p1: "Card Breakthrough Devices are used to increase the breakthrough level of a card from 1 to 10.",
        modal_limit_break_p2: "Reaching level 10 unlocks the card's <strong>Status Bonus</strong>, applied permanently to your character.",
        modal_limit_break_tier: "Device tier required per level:",
        modal_limit_break_t1: "Levels 1\u20133: Basic Card Breakthrough Device",
        modal_limit_break_t2: "Levels 4\u20137: Intermediate Card Breakthrough Device",
        modal_limit_break_t3: "Levels 7\u201310: Advanced Card Breakthrough Device",
        modal_limit_break_outro: "Prioritize reaching level 10 on cards with the strongest Status Bonuses for your build.",
        modal_leveling_title: "Eidolon Leveling",
        modal_leveling_p1: "To level an Eidolon from level 25 to 80, you can use the crystals below:",
        modal_skill_leveling_title: "Eidolon Skill Leveling (Mana Starstone)",
        modal_skill_leveling_p: "Leveling the skills of your main Eidolons is very important, because their skills gain stronger and additional buffs/debuffs.",
        modal_skill_leveling_total: "Total Mana Starstone needed: 6700",
        modal_gear_title: "Gear Guide",
        modal_gear_intro: "This section covers practical crafting priorities for your equipment.",
        gear_crafting_notes: "Crafting Notes",
        gear_weapon_progression: "Weapon Progression by Level",
        gear_weapon_core: "Weapon Core Options",
        gear_armor_core: "Armor / Trophy / Accessories Core Options",
        gear_mount_buff: "Mount Buff",
        gear_weapon_stone: "Weapon Secret Stone",
        gear_armor_stone: "Armor Secret Stone",
        gear_armor_stone_reroll: "Best Stats to Aim For (Rerolling)",
        gear_costume: "Costume",
        gear_crafting_li1: "Your weapon should use your class element because it deals 20% more elemental damage.",
        gear_crafting_li2: "Your armor element applies only on the chest piece and gives extra defense against that element. Dark element armor is generally preferred.",
        gear_crafting_li3: "Try to craft at least 120%+ quality on equipment. It is less important on armor, but high weapon quality increases damage noticeably.",
        gear_crafting_li4: "The quality cap is 130% for Orange equipment and 140% for Gold equipment.",
        gear_wp_note: "The strongest current weapons are farmed in Abyss II for each element. They are the best choices at Lv95, S15, and S35, so after Lv95 you generally do not need other weapon lines.",
        gear_wp_li1: "<strong>Below Lv95:</strong> Use reward weapons from Aura and Advanced Gaia (one from Lv1-40 and one from Lv40-75). They can carry you comfortably until Lv95.",
        gear_wp_li2: "<strong>Lv95:</strong> Craft the Abyss II weapon for your element: Hebe (Ice), Cerberus (Fire), Izanami (Dark), Michaela (Holy), Demeter (Storm), Hermes (Lightning). For physical builds, pick the weapon that gives the best boost to your main skills. If you do not want Abyss II yet, use Lv95 gold with your element or craft Lv90 orange with your preferred core.",
        gear_wp_li3: "<strong>S5:</strong> If you still do not have a Lv95 option, craft your Abyss II element weapon or use an S5 gold weapon with your element.",
        gear_wp_li4: "<strong>S10:</strong> The Lv95 Abyss II weapon is still good here. If you really want to change, craft the S10 orange weapon.",
        gear_wp_li5: "<strong>S15:</strong> Craft the S15 Abyss II weapon for your element. This is your best weapon line until S35.",
        gear_wp_li6: "<strong>S35:</strong> You can switch to S35 gold for your element, but it is optional. The best weapon is still Abyss II S35 of your element; S35 Abyss II is difficult to farm, so swap when you are strong enough and can farm it consistently.",
        gear_wc_li1: "<strong>Destroyer:</strong> 10% DEF Shred.",
        gear_wc_li2: "<strong>Nocturnal:</strong> 3% Absorb DMG to HP. This is nerfed in some dungeons.",
        gear_wc_li3: "<strong>Deadly:</strong> 15% CRIT DMG.",
        gear_wc_li4: "<strong>Restorer (Bard Only):</strong> 10% Heal.",
        gear_ac_li1: "<strong>Imperial:</strong> 3% Move SPD.",
        gear_ac_li2: "<strong>Blessed:</strong> 5% EXP Gain.",
        gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
        gear_ac_li4: "<strong>Spiky:</strong> 1% DMG + 1% DEF.",
        gear_mb_li1: "40% bonus to your class element skill damage.",
        gear_ws_note: "Always get the secret stone for your class skill.",
        gear_ws_li1: "<strong>Piercing Secret Stone</strong> \u2014 Best in slot, but expensive.",
        gear_ws_li2: "<strong>Lava Secret Stone</strong> \u2014 Cheaper than Piercing, and can be farmed in Pyroclastic Purgatory.",
        gear_ws_li3: "<strong>Orange Class Master Stone</strong> \u2014 Use as a placeholder before getting Lava or better.",
        gear_as_note1: "Purchase them at your class Master in Navea. They will be orange \u2014 don't worry about the stats. Level them to 70, then upgrade to purple to add one more stat, and they are ready to reroll.",
        gear_as_li1: "<strong>Detail-DMG</strong> (or DMG): +5 / +4 / +3",
        gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
        gear_as_note2: "Always aim for <strong>Detail-DMG +5%</strong> or at least <strong>DMG +4%</strong>. The most common strategy is to get <strong>Detail-DMG +5</strong> on the last line, then use a <strong>DMG + Something reroll potion</strong> to aim for double Detail-DMG on the stone.",
        gear_as_note3: "With enough economy, you can push further and get a stone with <strong>three damage stats</strong> \u2014 for example: <em>The DMG caused is increased by 6% / DMG +3% / Detail-DMG +5%</em>.",
        gear_costume_note: "<strong>Important:</strong> Always apply a <strong>Premium / Super Premium Card</strong> to the blue card bought from the Encyclopedia first, then use that blue card with enchants on your costume.",
        gear_costume_h5_head: "Headpiece - 12% DMG To Bosses",
        gear_costume_head_li1: "Add 10% Boss DMG Enchant.",
        gear_costume_head_li2: "Option A: Add 4% HP + 2% EVA Super Enchant.",
        gear_costume_head_li3: "Option B: Add 4% HP + 4% HEAL Super Enchant.",
        gear_costume_h5_body: "Body - 20% CRIT DMG To Bosses",
        gear_costume_body_li1: "Add 25% Boss CRIT DMG Enchant.",
        gear_costume_body_li2: "Add 4% DMG + 2% CRIT Super Enchant.",
        gear_costume_h5_face: "Face - Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_face_li1: "Add Class Enchant.",
        gear_costume_face_li2: "Option A: Add 4% DMG + 2% CRIT Super Enchant.",
        gear_costume_face_li3: "Option B: Add 4% DMG + Reduce 4% DMG Taken Super Enchant.",
        gear_costume_h5_back: "Back - 8% Move SPD Priority. Otherwise Pick What You Need Most (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_back_li1: "Add Move SPD Enchant.",
        gear_costume_back_li2: "Add 4% DMG + 4% HP Super Enchant.",
        gear_costume_h5_weapon: "Weapon - 12% Element Skill DMG",
        gear_costume_weapon_li1: "Add Class Enchant.",
        gear_costume_weapon_li2: "Add 4% DMG + 2% CRIT Super Enchant.",
        modal_boost_title: "Boost your damage",
        modal_boost_intro: "This guide focuses on practical ways to increase your overall damage output.",
        boost_back_strike: "Back Strike",
        boost_back_strike_p1: "Back Strike means attacking enemies from behind. Doing this grants <strong>50% amplified damage</strong>.",
        boost_back_strike_p2: "Whenever possible, reposition to stay behind the target and maintain this bonus.",
        boost_jump_casting: "Jump Casting",
        boost_jump_p1: "Jump Casting is a combat mechanic where you jump and then cast your skills. This helps cancel or shorten many animations that would normally lock you in place.",
        boost_jump_p2: "It also weaves basic attacks between skills, which increases your total damage output over time.",
        boost_amp_sources: "Amplified Damage Sources",
        boost_amp_intro: "Reference list of common sources that can raise your amplified damage in combat.",
        modal_dungeon_title: "Eidolon Spawn Location",
        modal_dungeon_note: "<strong>Note:</strong> Eidolons not listed here may be obtained from the Loyalty Points shop, by buying from other players, through the Auction House, by playing Paragon, or from in-game events.",
      },
      pt: {
        nav_guides: "Guias \u25be",
        nav_class_guides: "Guias de Classe \u25be",
        btn_what_is: "O que \u00e9",
        btn_eidolon_leveling: "Nivelar Eidolon",
        btn_gear_guide: "Guia de Equipamento",
        btn_boost_damage: "Aumente seu dano",
        btn_spawn_location: "Local de Apari\u00e7\u00e3o do Eidolon",
        btn_best_eidolons: "Melhores Eidolons",
        btn_useful_links: "Links \u00fateis",
        btn_close: "Fechar",
        search_placeholder: "Buscar por Eidolon, combo ou b\u00f4nus...",
        modal_best_eidolons_title: "Melhores Eidolons",
        modal_best_eidolons_warning_label: "Lista desatualizada:",
        modal_best_eidolons_warning_text: " estas informa\u00e7\u00f5es s\u00e3o de julho de 2024 e podem n\u00e3o refletir mais as melhores escolhas atuais.",
        modal_best_eidolons_legend: "= \u00d3timo com S\u00edmbolo de Eidolon",
        modal_best_eidolons_footer: "N\u00e3o sei a quem creditar esta informa\u00e7\u00e3o. Se for sua e quiser cr\u00e9dito, entre em contato comigo no Discord.",
        section_universal: "Eidolons Universais",
        section_dark: "Eidolons das Trevas",
        section_holy: "Eidolons Sagrados",
        section_flame: "Eidolons de Fogo",
        section_storm: "Eidolons de Tempestade",
        section_ice: "Eidolons de Gelo",
        section_lightning: "Eidolons de Raio",
        section_physical: "Eidolons F\u00edsicos",
        modal_useful_links_title: "Links \u00fateis",
        modal_useful_links_intro: "Guias e recursos da comunidade.",
        modal_class_guide_title: "Guias de Classe",
        modal_class_guide_intro: "Este menu est\u00e1 pronto para guias por classe do Aura Kingdom.",
        modal_lucky_pack_title: "Lucky Packs de Eidolon",
        modal_lucky_pack_p1: "Os Lucky Packs de Eidolon s\u00e3o usados no Covil do Eidolon em sua casa para aumentar a intimidade.",
        modal_lucky_pack_p2: "Os atributos b\u00e1sicos obtidos ao aumentar a intimidade s\u00e3o aplicados ao seu personagem:",
        modal_lucky_pack_p3: "Por isso, todos os Eidolons devem ser levados ao n\u00edvel 8 de intimidade. Geralmente s\u00e3o necess\u00e1rios cerca de 280 Lucky Packs para ir do n\u00edvel 1 ao 8. O n\u00edvel 10 \u00e9 opcional.",
        modal_wish_coin_title: "Moedas de Desejo de Eidolon",
        modal_wish_coin_p1: "As Moedas de Desejo s\u00e3o usadas para cumprir o desejo de um Eidolon sem precisar reunir os itens solicitados. S\u00e3o um atalho para cumprir desejos.",
        modal_wish_coin_p2: "Todos os atributos obtidos dessa forma s\u00e3o aplicados ao seu personagem.",
        modal_wish_coin_cost: "Custo de Moedas de Desejo por n\u00edvel:",
        modal_wish_coin_outro: "Todos os Eidolons devem ter seus desejos cumpridos. Esta \u00e9 uma das maiores fontes de atributos.",
        modal_limit_break_title: "Dispositivos de Avan\u00e7o de Carta",
        modal_limit_break_p1: "Os Dispositivos de Avan\u00e7o de Carta s\u00e3o usados para aumentar o n\u00edvel de avan\u00e7o de uma carta de 1 a 10.",
        modal_limit_break_p2: "Chegar ao n\u00edvel 10 desbloqueia o <strong>B\u00f4nus de Status</strong> da carta, aplicado permanentemente ao seu personagem.",
        modal_limit_break_tier: "Tier do dispositivo necess\u00e1rio por n\u00edvel:",
        modal_limit_break_t1: "N\u00edveis 1\u20133: Dispositivo de Avan\u00e7o B\u00e1sico",
        modal_limit_break_t2: "N\u00edveis 4\u20137: Dispositivo de Avan\u00e7o Intermedi\u00e1rio",
        modal_limit_break_t3: "N\u00edveis 7\u201310: Dispositivo de Avan\u00e7o Avan\u00e7ado",
        modal_limit_break_outro: "Priorize chegar ao n\u00edvel 10 nas cartas com os B\u00f4nus de Status mais fortes para sua build.",
        modal_leveling_title: "Nivelamento de Eidolon",
        modal_leveling_p1: "Para nivelar um Eidolon do n\u00edvel 25 ao 80, voc\u00ea pode usar os cristais abaixo:",
        modal_skill_leveling_title: "Nivelamento de Habilidades do Eidolon (Mana Starstone)",
        modal_skill_leveling_p: "Nivelar as habilidades dos seus Eidolons principais \u00e9 muito importante, pois elas ficam mais fortes e ganham buffs/debuffs adicionais.",
        modal_skill_leveling_total: "Total de Mana Starstone necess\u00e1rio: 6700",
        modal_gear_title: "Guia de Equipamento",
        modal_gear_intro: "Esta se\u00e7\u00e3o cobre as prioridades pr\u00e1ticas de cria\u00e7\u00e3o do seu equipamento.",
        gear_crafting_notes: "Notas de Cria\u00e7\u00e3o",
        gear_weapon_progression: "Progress\u00e3o de Armas por N\u00edvel",
        gear_weapon_core: "Op\u00e7\u00f5es de N\u00facleo de Arma",
        gear_armor_core: "Op\u00e7\u00f5es de N\u00facleo de Armadura / Trof\u00e9u / Acess\u00f3rios",
        gear_mount_buff: "Buff de Montaria",
        gear_weapon_stone: "Pedra Secreta de Arma",
        gear_armor_stone: "Pedra Secreta de Armadura",
        gear_armor_stone_reroll: "Melhores Atributos a Buscar (Reroll)",
        gear_costume: "Fantasia",
        gear_crafting_li1: "Sua arma deve usar o elemento da sua classe pois causa 20% mais dano elemental.",
        gear_crafting_li2: "O elemento da armadura se aplica apenas na pe\u00e7a do peito e d\u00e1 defesa extra contra aquele elemento. Armadura de elemento Escurid\u00e3o \u00e9 geralmente preferida.",
        gear_crafting_li3: "Tente craftar equipamentos com pelo menos 120%+ de qualidade. \u00c9 menos importante na armadura, mas uma alta qualidade de arma aumenta o dano notavelmente.",
        gear_crafting_li4: "O limite de qualidade \u00e9 130% para equipamentos Laranja e 140% para equipamentos Ouro.",
        gear_wp_note: "As armas mais fortes atualmente s\u00e3o farmadas no Abyss II para cada elemento. Elas s\u00e3o as melhores escolhas no Lv95, S15 e S35, ent\u00e3o ap\u00f3s o Lv95 voc\u00ea geralmente n\u00e3o precisa de outras linhas de armas.",
        gear_wp_li1: "<strong>Abaixo do Lv95:</strong> Use armas de recompensa do Aura e do Gaia Avan\u00e7ado (uma do Lv1-40 e outra do Lv40-75). Elas podem te carregar confortavelmente at\u00e9 o Lv95.",
        gear_wp_li2: "<strong>Lv95:</strong> Crafta a arma do Abyss II para o seu elemento: Hebe (Gelo), Cerberus (Fogo), Izanami (Escurid\u00e3o), Michaela (Sagrado), Demeter (Tempestade), Hermes (Raio). Para builds f\u00edsicas, escolha a arma que d\u00e1 o melhor boost \u00e0s suas habilidades principais. Se n\u00e3o quiser Abyss II ainda, use ouro Lv95 com seu elemento ou crafta laranja Lv90 com o n\u00facleo preferido.",
        gear_wp_li3: "<strong>S5:</strong> Se ainda n\u00e3o tiver op\u00e7\u00e3o Lv95, crafta a arma de elemento do Abyss II ou use uma arma ouro S5 com seu elemento.",
        gear_wp_li4: "<strong>S10:</strong> A arma Abyss II Lv95 ainda \u00e9 boa aqui. Se realmente quiser mudar, crafta a arma laranja S10.",
        gear_wp_li5: "<strong>S15:</strong> Crafta a arma Abyss II S15 para o seu elemento. Esta \u00e9 sua melhor linha de arma at\u00e9 o S35.",
        gear_wp_li6: "<strong>S35:</strong> Voc\u00ea pode trocar para ouro S35 do seu elemento, mas \u00e9 opcional. A melhor arma ainda \u00e9 o Abyss II S35 do seu elemento; o Abyss II S35 \u00e9 dif\u00edcil de farmar, ent\u00e3o troque quando estiver forte o suficiente e conseguir farmar consistentemente.",
        gear_wc_li1: "<strong>Destruidor:</strong> 10% de redu\u00e7\u00e3o de DEF.",
        gear_wc_li2: "<strong>Noturno:</strong> 3% de absor\u00e7\u00e3o de dano para HP. Isso \u00e9 limitado em algumas masmorras.",
        gear_wc_li3: "<strong>Mortal:</strong> 15% de CRIT DMG.",
        gear_wc_li4: "<strong>Restaurador (Apenas Bardo):</strong> 10% de Cura.",
        gear_ac_li1: "<strong>Imperial:</strong> 3% de Velocidade de Movimento.",
        gear_ac_li2: "<strong>Aben\u00e7oado:</strong> 5% de Ganho de EXP.",
        gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
        gear_ac_li4: "<strong>Espinhoso:</strong> 1% DMG + 1% DEF.",
        gear_mb_li1: "40% de b\u00f4nus no dano de habilidade do elemento da sua classe.",
        gear_ws_note: "Sempre pegue a pedra secreta para a habilidade da sua classe.",
        gear_ws_li1: "<strong>Pedra Secreta Perfurante</strong> \u2014 Melhor no slot, mas cara.",
        gear_ws_li2: "<strong>Pedra Secreta de Lava</strong> \u2014 Mais barata que a Perfurante e pode ser farmada no Purga\u00adT\u00f3rio Pirocl\u00e1stico.",
        gear_ws_li3: "<strong>Pedra Mestre de Classe Laranja</strong> \u2014 Use como substituta antes de conseguir Lava ou melhor.",
        gear_as_note1: "Compre no Mestre da sua classe em Navea. Ser\u00e3o laranjas \u2014 n\u00e3o se preocupe com os atributos. Suba para o n\u00edvel 70, depois evolua para roxo para adicionar mais um atributo, e estar\u00e3o prontas para reroll.",
        gear_as_li1: "<strong>Detail-DMG</strong> (ou DMG): +5 / +4 / +3",
        gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
        gear_as_note2: "Sempre mire em <strong>Detail-DMG +5%</strong> ou pelo menos <strong>DMG +4%</strong>. A estrat\u00e9gia mais comum \u00e9 conseguir <strong>Detail-DMG +5</strong> na \u00faltima linha, depois usar uma <strong>po\u00e7\u00e3o de reroll DMG + Algo</strong> para ter Detail-DMG duplo na pedra.",
        gear_as_note3: "Com economia suficiente, voc\u00ea pode ir mais longe e conseguir uma pedra com <strong>tr\u00eas atributos de dano</strong> \u2014 por exemplo: <em>O DMG causado aumenta em 6% / DMG +3% / Detail-DMG +5%</em>.",
        gear_costume_note: "<strong>Importante:</strong> Sempre aplique um <strong>Card Premium / Super Premium</strong> no card azul comprado da Enciclop\u00e9dia primeiro, depois use esse card azul com encantamentos na sua fantasia.",
        gear_costume_h5_head: "Capacete - 12% de DMG para Chefes",
        gear_costume_head_li1: "Adicione Encantamento de 10% de DMG para Chefes.",
        gear_costume_head_li2: "Op\u00e7\u00e3o A: Adicione Super Encantamento de 4% HP + 2% EVA.",
        gear_costume_head_li3: "Op\u00e7\u00e3o B: Adicione Super Encantamento de 4% HP + 4% HEAL.",
        gear_costume_h5_body: "Corpo - 20% de CRIT DMG para Chefes",
        gear_costume_body_li1: "Adicione Encantamento de 25% de CRIT DMG para Chefes.",
        gear_costume_body_li2: "Adicione Super Encantamento de 4% DMG + 2% CRIT.",
        gear_costume_h5_face: "Rosto - Escolha o que Mais Precisa (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_face_li1: "Adicione Encantamento de Classe.",
        gear_costume_face_li2: "Op\u00e7\u00e3o A: Adicione Super Encantamento de 4% DMG + 2% CRIT.",
        gear_costume_face_li3: "Op\u00e7\u00e3o B: Adicione Super Encantamento de 4% DMG + Reduzir 4% DMG Recebido.",
        gear_costume_h5_back: "Costas - Prioridade de 8% Velocidade de Movimento. Caso contr\u00e1rio, Escolha o que Mais Precisa (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_back_li1: "Adicione Encantamento de Velocidade de Movimento.",
        gear_costume_back_li2: "Adicione Super Encantamento de 4% DMG + 4% HP.",
        gear_costume_h5_weapon: "Arma - 12% de DMG de Habilidade Elemental",
        gear_costume_weapon_li1: "Adicione Encantamento de Classe.",
        gear_costume_weapon_li2: "Adicione Super Encantamento de 4% DMG + 2% CRIT.",
        modal_boost_title: "Aumente seu dano",
        modal_boost_intro: "Este guia foca em maneiras pr\u00e1ticas de aumentar seu dano geral.",
        boost_back_strike: "Ataque Pelas Costas",
        boost_back_strike_p1: "Ataque Pelas Costas significa atacar inimigos por tr\u00e1s. Isso concede 50% de dano amplificado.",
        boost_back_strike_p2: "Sempre que poss\u00edvel, reposicione-se para ficar atr\u00e1s do alvo e manter esse b\u00f4nus.",
        boost_jump_casting: "Conjura\u00e7\u00e3o em Salto",
        boost_jump_p1: "Conjura\u00e7\u00e3o em Salto \u00e9 uma mec\u00e2nica de combate onde voc\u00ea pula e depois usa suas habilidades. Isso ajuda a cancelar ou encurtar muitas anima\u00e7\u00f5es que normalmente te imobilizariam.",
        boost_jump_p2: "Tamb\u00e9m intercala ataques b\u00e1sicos entre habilidades, aumentando seu dano total ao longo do tempo.",
        boost_amp_sources: "Fontes de Dano Amplificado",
        boost_amp_intro: "Lista de refer\u00eancia de fontes comuns que podem aumentar seu dano amplificado em combate.",
        modal_dungeon_title: "Local de Apari\u00e7\u00e3o do Eidolon",
        modal_dungeon_note: "<strong>Nota:</strong> Eidolons n\u00e3o listados aqui podem ser obtidos na loja de Pontos de Lealdade, comprando de outros jogadores, pelo Mercado, jogando Paragon ou em eventos do jogo.",
      },
      es: {
        nav_guides: "Gu\u00edas \u25be",
        nav_class_guides: "Gu\u00edas de Clase \u25be",
        btn_what_is: "\u00bfQu\u00e9 es",
        btn_eidolon_leveling: "Nivelar Eidolon",
        btn_gear_guide: "Gu\u00eda de Equipo",
        btn_boost_damage: "Aumenta tu da\u00f1o",
        btn_spawn_location: "Ubicaci\u00f3n de Aparici\u00f3n",
        btn_best_eidolons: "Mejores Eidolons",
        btn_useful_links: "Enlaces \u00fatiles",
        btn_close: "Cerrar",
        search_placeholder: "Buscar por Eidolon, combo o bonificaci\u00f3n...",
        modal_best_eidolons_title: "Mejores Eidolons",
        modal_best_eidolons_warning_label: "Lista desactualizada:",
        modal_best_eidolons_warning_text: " esta informaci\u00f3n es de julio de 2024 y puede no reflejar las mejores opciones actuales.",
        modal_best_eidolons_legend: "= Excelente con S\u00edmbolo de Eidolon",
        modal_best_eidolons_footer: "No s\u00e9 a qui\u00e9n acreditar esta informaci\u00f3n. Si es tuya y quieres cr\u00e9dito, cont\u00e1ctame en Discord.",
        section_universal: "Eidolons Universales",
        section_dark: "Eidolons Oscuros",
        section_holy: "Eidolons Sagrados",
        section_flame: "Eidolons de Fuego",
        section_storm: "Eidolons de Tormenta",
        section_ice: "Eidolons de Hielo",
        section_lightning: "Eidolons de Rayo",
        section_physical: "Eidolons F\u00edsicos",
        modal_useful_links_title: "Enlaces \u00fatiles",
        modal_useful_links_intro: "Gu\u00edas y recursos de la comunidad.",
        modal_class_guide_title: "Gu\u00edas de Clase",
        modal_class_guide_intro: "Este men\u00fa est\u00e1 listo para gu\u00edas de clase de Aura Kingdom.",
        modal_lucky_pack_title: "Paquetes de Suerte de Eidolon",
        modal_lucky_pack_p1: "Los Paquetes de Suerte de Eidolon se usan en la Guarida del Eidolon en tu casa para subir la intimidad.",
        modal_lucky_pack_p2: "Los atributos b\u00e1sicos obtenidos al subir la intimidad se aplican a tu personaje:",
        modal_lucky_pack_p3: "Por eso, todos los Eidolons deben llegar al nivel 8 de intimidad. Generalmente se necesitan unos 280 paquetes para ir del nivel 1 al 8. El nivel 10 es opcional.",
        modal_wish_coin_title: "Monedas de Deseo de Eidolon",
        modal_wish_coin_p1: "Las Monedas de Deseo se usan para cumplir el deseo de un Eidolon sin necesitar reunir los objetos pedidos.",
        modal_wish_coin_p2: "Todos los atributos obtenidos as\u00ed se aplican a tu personaje.",
        modal_wish_coin_cost: "Costo de Monedas de Deseo por nivel:",
        modal_wish_coin_outro: "Todos los Eidolons deben tener sus deseos cumplidos. Es una de las mayores fuentes de atributos.",
        modal_limit_break_title: "Dispositivos de Avance de Carta",
        modal_limit_break_p1: "Los Dispositivos de Avance de Carta se usan para aumentar el nivel de avance de una carta del 1 al 10.",
        modal_limit_break_p2: "Llegar al nivel 10 desbloquea el <strong>Bono de Estado</strong> de la carta, aplicado permanentemente a tu personaje.",
        modal_limit_break_tier: "Nivel de dispositivo requerido por nivel:",
        modal_limit_break_t1: "Niveles 1\u20133: Dispositivo de Avance B\u00e1sico",
        modal_limit_break_t2: "Niveles 4\u20137: Dispositivo de Avance Intermedio",
        modal_limit_break_t3: "Niveles 7\u201310: Dispositivo de Avance Avanzado",
        modal_limit_break_outro: "Prioriza llegar al nivel 10 en las cartas con los Bonos de Estado m\u00e1s fuertes para tu build.",
        modal_leveling_title: "Nivelaci\u00f3n de Eidolon",
        modal_leveling_p1: "Para nivelar un Eidolon del nivel 25 al 80, puedes usar los cristales a continuaci\u00f3n:",
        modal_skill_leveling_title: "Nivelaci\u00f3n de Habilidades del Eidolon (Mana Starstone)",
        modal_skill_leveling_p: "Nivelar las habilidades de tus Eidolons principales es muy importante, ya que sus habilidades se vuelven m\u00e1s fuertes y ganan buffs/debuffs adicionales.",
        modal_skill_leveling_total: "Total de Mana Starstone necesario: 6700",
        modal_gear_title: "Gu\u00eda de Equipo",
        modal_gear_intro: "Esta secci\u00f3n cubre las prioridades pr\u00e1cticas de fabricaci\u00f3n de tu equipo.",
        gear_crafting_notes: "Notas de Fabricaci\u00f3n",
        gear_weapon_progression: "Progresi\u00f3n de Armas por Nivel",
        gear_weapon_core: "Opciones de N\u00facleo de Arma",
        gear_armor_core: "Opciones de N\u00facleo de Armadura / Trofeo / Accesorios",
        gear_mount_buff: "Buff de Montura",
        gear_weapon_stone: "Piedra Secreta de Arma",
        gear_armor_stone: "Piedra Secreta de Armadura",
        gear_armor_stone_reroll: "Mejores Atributos a Buscar (Reroll)",
        gear_costume: "Disfraz",
        gear_crafting_li1: "Tu arma debe usar el elemento de tu clase porque causa un 20% m\u00e1s de da\u00f1o elemental.",
        gear_crafting_li2: "El elemento de la armadura solo se aplica en la pieza de pecho y da defensa extra contra ese elemento. La armadura de elemento Oscuridad es generalmente preferida.",
        gear_crafting_li3: "Intenta fabricar equipamiento con al menos 120%+ de calidad. Es menos importante en la armadura, pero una alta calidad de arma aumenta el da\u00f1o notablemente.",
        gear_crafting_li4: "El l\u00edmite de calidad es 130% para equipo Naranja y 140% para equipo Dorado.",
        gear_wp_note: "Las armas m\u00e1s fuertes actualmente se farmean en Abyss II para cada elemento. Son las mejores opciones en Lv95, S15 y S35, as\u00ed que despu\u00e9s del Lv95 generalmente no necesitas otras l\u00edneas de armas.",
        gear_wp_li1: "<strong>Bajo Lv95:</strong> Usa armas de recompensa de Aura y Gaia Avanzado (una de Lv1-40 y una de Lv40-75). Pueden llevarte c\u00f3modamente hasta Lv95.",
        gear_wp_li2: "<strong>Lv95:</strong> Fabrica el arma de Abyss II para tu elemento: Hebe (Hielo), Cerberus (Fuego), Izanami (Oscuridad), Michaela (Sagrado), Demeter (Tormenta), Hermes (Rayo). Para builds f\u00edsicas, elige el arma que d\u00e9 el mejor boost a tus habilidades principales. Si a\u00fan no quieres Abyss II, usa oro Lv95 con tu elemento o fabrica naranja Lv90 con tu n\u00facleo preferido.",
        gear_wp_li3: "<strong>S5:</strong> Si a\u00fan no tienes opci\u00f3n Lv95, fabrica el arma de elemento Abyss II o usa un arma de oro S5 con tu elemento.",
        gear_wp_li4: "<strong>S10:</strong> El arma Abyss II Lv95 sigue siendo buena aqu\u00ed. Si realmente quieres cambiar, fabrica el arma naranja S10.",
        gear_wp_li5: "<strong>S15:</strong> Fabrica el arma Abyss II S15 para tu elemento. Esta es tu mejor l\u00ednea de arma hasta S35.",
        gear_wp_li6: "<strong>S35:</strong> Puedes cambiar a oro S35 para tu elemento, pero es opcional. El mejor arma sigue siendo Abyss II S35 de tu elemento; S35 Abyss II es dif\u00edcil de farmear, as\u00ed que cambia cuando seas lo suficientemente fuerte y puedas farmearlo consistentemente.",
        gear_wc_li1: "<strong>Destructor:</strong> 10% de reducci\u00f3n de DEF.",
        gear_wc_li2: "<strong>Nocturno:</strong> 3% de absorci\u00f3n de da\u00f1o a HP. Esto est\u00e1 reducido en algunas mazmorras.",
        gear_wc_li3: "<strong>Mortal:</strong> 15% de CRIT DMG.",
        gear_wc_li4: "<strong>Restaurador (Solo Bardo):</strong> 10% de Curaci\u00f3n.",
        gear_ac_li1: "<strong>Imperial:</strong> 3% de Velocidad de Movimiento.",
        gear_ac_li2: "<strong>Bendecido:</strong> 5% de Ganancia de EXP.",
        gear_ac_li3: "<strong>Bestial:</strong> 1% DMG + 1% HP.",
        gear_ac_li4: "<strong>Espinoso:</strong> 1% DMG + 1% DEF.",
        gear_mb_li1: "40% de bonificaci\u00f3n al da\u00f1o de habilidad del elemento de tu clase.",
        gear_ws_note: "Siempre consigue la piedra secreta para la habilidad de tu clase.",
        gear_ws_li1: "<strong>Piedra Secreta Perforante</strong> \u2014 La mejor en slot, pero cara.",
        gear_ws_li2: "<strong>Piedra Secreta de Lava</strong> \u2014 M\u00e1s barata que la Perforante y puede farmearse en el Purgatorio Pirocl\u00e1stico.",
        gear_ws_li3: "<strong>Piedra Maestra de Clase Naranja</strong> \u2014 \u00dasala como sustituta antes de conseguir Lava o mejor.",
        gear_as_note1: "C\u00f3mpralas en el Maestro de tu clase en Navea. Ser\u00e1n naranjas \u2014 no te preocupes por los atributos. S\u00fabelas al nivel 70, luego mej\u00f3ralas a morado para a\u00f1adir un atributo m\u00e1s, y estar\u00e1n listas para reroll.",
        gear_as_li1: "<strong>Detail-DMG</strong> (o DMG): +5 / +4 / +3",
        gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
        gear_as_note2: "Siempre apunta a <strong>Detail-DMG +5%</strong> o al menos <strong>DMG +4%</strong>. La estrategia m\u00e1s com\u00fan es conseguir <strong>Detail-DMG +5</strong> en la \u00faltima l\u00ednea, luego usar una <strong>poci\u00f3n de reroll DMG + Algo</strong> para apuntar a doble Detail-DMG en la piedra.",
        gear_as_note3: "Con suficiente econom\u00eda, puedes ir m\u00e1s lejos y conseguir una piedra con <strong>tres estad\u00edsticas de da\u00f1o</strong> \u2014 por ejemplo: <em>El DMG causado aumenta en 6% / DMG +3% / Detail-DMG +5%</em>.",
        gear_costume_note: "<strong>Importante:</strong> Siempre aplica una <strong>Carta Premium / Super Premium</strong> a la carta azul comprada de la Enciclopedia primero, luego usa esa carta azul con encantamientos en tu disfraz.",
        gear_costume_h5_head: "Cabeza - 12% DMG a Jefes",
        gear_costume_head_li1: "A\u00f1ade Encantamiento de 10% DMG a Jefes.",
        gear_costume_head_li2: "Opci\u00f3n A: A\u00f1ade Super Encantamiento de 4% HP + 2% EVA.",
        gear_costume_head_li3: "Opci\u00f3n B: A\u00f1ade Super Encantamiento de 4% HP + 4% HEAL.",
        gear_costume_h5_body: "Cuerpo - 20% CRIT DMG a Jefes",
        gear_costume_body_li1: "A\u00f1ade Encantamiento de 25% CRIT DMG a Jefes.",
        gear_costume_body_li2: "A\u00f1ade Super Encantamiento de 4% DMG + 2% CRIT.",
        gear_costume_h5_face: "Cara - Elige lo que M\u00e1s Necesites (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_face_li1: "A\u00f1ade Encantamiento de Clase.",
        gear_costume_face_li2: "Opci\u00f3n A: A\u00f1ade Super Encantamiento de 4% DMG + 2% CRIT.",
        gear_costume_face_li3: "Opci\u00f3n B: A\u00f1ade Super Encantamiento de 4% DMG + Reducir 4% DMG Recibido.",
        gear_costume_h5_back: "Espalda - Prioridad de 8% Velocidad de Movimiento. De lo contrario, Elige lo que M\u00e1s Necesites (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_back_li1: "A\u00f1ade Encantamiento de Velocidad de Movimiento.",
        gear_costume_back_li2: "A\u00f1ade Super Encantamiento de 4% DMG + 4% HP.",
        gear_costume_h5_weapon: "Arma - 12% DMG de Habilidad Elemental",
        gear_costume_weapon_li1: "A\u00f1ade Encantamento de Clase.",
        gear_costume_weapon_li2: "A\u00f1ade Super Encantamiento de 4% DMG + 2% CRIT.",
        modal_boost_title: "Aumenta tu da\u00f1o",
        modal_boost_intro: "Esta gu\u00eda se enfoca en formas pr\u00e1cticas de aumentar tu da\u00f1o general.",
        boost_back_strike: "Golpe por la Espalda",
        boost_back_strike_p1: "Golpe por la Espalda significa atacar enemigos por detr\u00e1s. Hacer esto otorga un 50% de da\u00f1o amplificado.",
        boost_back_strike_p2: "Siempre que sea posible, repos\u00edci\u00f3nate para estar detr\u00e1s del objetivo y mantener este bonus.",
        boost_jump_casting: "Lanzamiento en Salto",
        boost_jump_p1: "El Lanzamiento en Salto es una mec\u00e1nica de combate en la que saltas y luego lanzas tus habilidades. Esto ayuda a cancelar o acortar muchas animaciones que normalmente te detendr\u00edan.",
        boost_jump_p2: "Tambi\u00e9n intercala ataques b\u00e1sicos entre habilidades, lo que aumenta tu da\u00f1o total con el tiempo.",
        boost_amp_sources: "Fuentes de Da\u00f1o Amplificado",
        boost_amp_intro: "Lista de referencia de fuentes comunes que pueden aumentar tu da\u00f1o amplificado en combate.",
        modal_dungeon_title: "Ubicaci\u00f3n de Aparici\u00f3n del Eidolon",
        modal_dungeon_note: "<strong>Nota:</strong> Los Eidolons no listados aqu\u00ed pueden obtenerse en la tienda de Puntos de Lealtad, comprando a otros jugadores, por la Casa de Subastas, jugando Paragon o en eventos del juego.",
      },
      de: {
        nav_guides: "Guides \u25be",
        nav_class_guides: "Klassen-Guides \u25be",
        btn_what_is: "Was ist",
        btn_eidolon_leveling: "Eidolon leveln",
        btn_gear_guide: "Ausr\u00fcstungs-Guide",
        btn_boost_damage: "Schaden erh\u00f6hen",
        btn_spawn_location: "Eidolon-Fundorte",
        btn_best_eidolons: "Beste Eidolons",
        btn_useful_links: "N\u00fctzliche Links",
        btn_close: "Schlie\u00dfen",
        search_placeholder: "Nach Eidolon, Kombination oder Bonus suchen...",
        modal_best_eidolons_title: "Beste Eidolons",
        modal_best_eidolons_warning_label: "Veraltete Liste:",
        modal_best_eidolons_warning_text: " Diese Informationen stammen aus Juli 2024 und spiegeln m\u00f6glicherweise nicht mehr die aktuell besten Optionen wider.",
        modal_best_eidolons_legend: "= Hervorragend mit Eidolon-Symbol",
        modal_best_eidolons_footer: "Ich wei\u00df nicht, wem diese Information zugeschrieben werden sollte. Falls es deine ist und du eine Erw\u00e4hnung m\u00f6chtest, kontaktiere mich auf Discord.",
        section_universal: "Universelle Eidolons",
        section_dark: "Dunkle Eidolons",
        section_holy: "Heilige Eidolons",
        section_flame: "Flammen-Eidolons",
        section_storm: "Sturm-Eidolons",
        section_ice: "Eis-Eidolons",
        section_lightning: "Blitz-Eidolons",
        section_physical: "Physische Eidolons",
        modal_useful_links_title: "N\u00fctzliche Links",
        modal_useful_links_intro: "Community-Guides und Ressourcen.",
        modal_class_guide_title: "Klassen-Guides",
        modal_class_guide_intro: "Dieses Men\u00fc ist bereit f\u00fcr klassenspezifische Aura Kingdom Guides.",
        modal_lucky_pack_title: "Eidolon-Gl\u00fcckspakete",
        modal_lucky_pack_p1: "Eidolon-Gl\u00fcckspakete werden im Eidolon-Hort in deinem Haus verwendet, um Intimit\u00e4t zu steigern.",
        modal_lucky_pack_p2: "Die durch Intimit\u00e4t gewonnenen Basiswerte werden auf deinen Charakter angewendet:",
        modal_lucky_pack_p3: "Deshalb sollten alle Eidolons mindestens auf Intimit\u00e4tslevel 8 gebracht werden. Es dauert etwa 280 Pakete, um von Level 1 auf 8 zu kommen. Level 10 ist optional.",
        modal_wish_coin_title: "Eidolon-Wunschm\u00fcnzen",
        modal_wish_coin_p1: "Wunschm\u00fcnzen werden verwendet, um den Wunsch eines Eidolons zu erf\u00fcllen, ohne die geforderten Gegenst\u00e4nde sammeln zu m\u00fcssen.",
        modal_wish_coin_p2: "Alle so gewonnenen Werte werden auf deinen Charakter angewendet.",
        modal_wish_coin_cost: "Kosten der Wunschm\u00fcnzen pro Wunschstufe:",
        modal_wish_coin_outro: "Alle Eidolons sollten ihre W\u00fcnsche erf\u00fcllt haben. Das ist eine der gr\u00f6\u00dften Quellen f\u00fcr Rohwerte.",
        modal_limit_break_title: "Karten-Durchbruchger\u00e4te",
        modal_limit_break_p1: "Karten-Durchbruchger\u00e4te werden verwendet, um den Durchbruchlevel einer Karte von 1 auf 10 zu erh\u00f6hen.",
        modal_limit_break_p2: "Level 10 zu erreichen schaltet den <strong>Statusbonus</strong> der Karte frei, der dauerhaft auf deinen Charakter angewendet wird.",
        modal_limit_break_tier: "Ben\u00f6tigte Ger\u00e4testufe pro Level:",
        modal_limit_break_t1: "Level 1\u20133: Einfaches Durchbruchger\u00e4t",
        modal_limit_break_t2: "Level 4\u20137: Mittleres Durchbruchger\u00e4t",
        modal_limit_break_t3: "Level 7\u201310: Fortgeschrittenes Durchbruchger\u00e4t",
        modal_limit_break_outro: "Priorisiere das Erreichen von Level 10 bei Karten mit den st\u00e4rksten Statusboni f\u00fcr deinen Build.",
        modal_leveling_title: "Eidolon leveln",
        modal_leveling_p1: "Um ein Eidolon von Level 25 auf 80 zu bringen, kannst du folgende Kristalle verwenden:",
        modal_skill_leveling_title: "Eidolon-F\u00e4higkeiten leveln (Mana Starstone)",
        modal_skill_leveling_p: "Das Leveln der F\u00e4higkeiten deiner Haupt-Eidolons ist sehr wichtig, da sie st\u00e4rker werden und zus\u00e4tzliche Buffs/Debuffs erhalten.",
        modal_skill_leveling_total: "Ben\u00f6tigte Mana Starstones gesamt: 6700",
        modal_gear_title: "Ausr\u00fcstungs-Guide",
        modal_gear_intro: "Dieser Abschnitt behandelt praktische Herstellungspriori\u00e4ten f\u00fcr deine Ausr\u00fcstung.",
        gear_crafting_notes: "Handwerkshinweise",
        gear_weapon_progression: "Waffenprogression nach Level",
        gear_weapon_core: "Waffenkern-Optionen",
        gear_armor_core: "R\u00fcstungs- / Troph\u00e4en- / Zubeh\u00f6r-Kern-Optionen",
        gear_mount_buff: "Reittier-Buff",
        gear_weapon_stone: "Waffen-Geheimstein",
        gear_armor_stone: "R\u00fcstungs-Geheimstein",
        gear_armor_stone_reroll: "Beste Werte f\u00fcr Reroll",
        gear_costume: "Kost\u00fcm",
        gear_crafting_li1: "Deine Waffe sollte dein Klassenelement verwenden, da sie 20% mehr Elementarschaden verursacht.",
        gear_crafting_li2: "Das R\u00fcstungselement gilt nur f\u00fcr das Brustteil und gibt zus\u00e4tzliche Verteidigung gegen dieses Element. Dunkel-Element-R\u00fcstung wird generell bevorzugt.",
        gear_crafting_li3: "Versuche, Ausr\u00fcstung mit mindestens 120%+ Qualit\u00e4t herzustellen. Bei R\u00fcstungen ist es weniger wichtig, aber hohe Waffenqualit\u00e4t erh\u00f6ht den Schaden deutlich.",
        gear_crafting_li4: "Die Qualit\u00e4tsgrenze betr\u00e4gt 130% f\u00fcr Orange-Ausr\u00fcstung und 140% f\u00fcr Gold-Ausr\u00fcstung.",
        gear_wp_note: "Die st\u00e4rksten aktuellen Waffen werden in Abyss II f\u00fcr jedes Element gefarmt. Sie sind die besten Optionen bei Lv95, S15 und S35, daher ben\u00f6tigst du nach Lv95 generell keine anderen Waffenlinien.",
        gear_wp_li1: "<strong>Unter Lv95:</strong> Verwende Belohnungswaffen aus Aura und Advanced Gaia (eine von Lv1-40 und eine von Lv40-75). Sie k\u00f6nnen dich komfortabel bis Lv95 tragen.",
        gear_wp_li2: "<strong>Lv95:</strong> Stelle die Abyss-II-Waffe f\u00fcr dein Element her: Hebe (Eis), Cerberus (Feuer), Izanami (Dunkel), Michaela (Heilig), Demeter (Sturm), Hermes (Blitz). W\u00e4hle f\u00fcr physische Builds die Waffe, die deinen Hauptf\u00e4higkeiten den besten Boost gibt. Wenn du Abyss II noch nicht m\u00f6chtest, verwende Lv95 Gold mit deinem Element oder stelle Lv90 Orange mit deinem bevorzugten Kern her.",
        gear_wp_li3: "<strong>S5:</strong> Wenn du noch keine Lv95-Option hast, stelle die Abyss-II-Elementwaffe her oder verwende eine S5-Gold-Waffe mit deinem Element.",
        gear_wp_li4: "<strong>S10:</strong> Die Lv95-Abyss-II-Waffe ist hier noch gut. Wenn du wirklich wechseln m\u00f6chtest, stelle die S10-Orange-Waffe her.",
        gear_wp_li5: "<strong>S15:</strong> Stelle die S15-Abyss-II-Waffe f\u00fcr dein Element her. Dies ist deine beste Waffenlinie bis S35.",
        gear_wp_li6: "<strong>S35:</strong> Du kannst auf S35 Gold f\u00fcr dein Element wechseln, aber es ist optional. Die beste Waffe ist immer noch Abyss II S35 deines Elements; S35 Abyss II ist schwer zu farmen, also wechsle, wenn du stark genug bist und es konsistent farmen kannst.",
        gear_wc_li1: "<strong>Vernichter:</strong> 10% DEF-Reduzierung.",
        gear_wc_li2: "<strong>Nachtaktiv:</strong> 3% Schadensabsorption zu HP. Dies wird in einigen Dungeons geschw\u00e4cht.",
        gear_wc_li3: "<strong>T\u00f6dlich:</strong> 15% CRIT DMG.",
        gear_wc_li4: "<strong>Restaurierer (Nur Barde):</strong> 10% Heilung.",
        gear_ac_li1: "<strong>Imperial:</strong> 3% Bewegungsgeschwindigkeit.",
        gear_ac_li2: "<strong>Gesegnet:</strong> 5% EXP-Gewinn.",
        gear_ac_li3: "<strong>Bestialisch:</strong> 1% DMG + 1% HP.",
        gear_ac_li4: "<strong>Stachelig:</strong> 1% DMG + 1% DEF.",
        gear_mb_li1: "40% Bonus auf den Elementarf\u00e4higkeitsschaden deiner Klasse.",
        gear_ws_note: "Hole immer den Geheimstein f\u00fcr deine Klassenf\u00e4higkeit.",
        gear_ws_li1: "<strong>Durchdringender Geheimstein</strong> \u2014 Bestes im Slot, aber teuer.",
        gear_ws_li2: "<strong>Lava-Geheimstein</strong> \u2014 G\u00fcnstiger als Durchdringend und kann im Pyroclastic Purgatory gefarmt werden.",
        gear_ws_li3: "<strong>Oranger Klassen-Meister-Stein</strong> \u2014 Als Platzhalter verwenden, bis Lava oder besser verf\u00fcgbar ist.",
        gear_as_note1: "Kaufe sie beim Klassenmeister in Navea. Sie werden Orange sein \u2014 mach dir keine Sorgen um die Werte. Bringe sie auf Level 70, dann verbessere sie auf Lila, um einen weiteren Wert hinzuzuf\u00fcgen, und sie sind bereit zum Reroll.",
        gear_as_li1: "<strong>Detail-DMG</strong> (oder DMG): +5 / +4 / +3",
        gear_as_li2: "<strong>CRIT DMG:</strong> +10 / +8 / +6",
        gear_as_note2: "Ziele immer auf <strong>Detail-DMG +5%</strong> oder mindestens <strong>DMG +4%</strong>. Die h\u00e4ufigste Strategie ist, <strong>Detail-DMG +5</strong> in der letzten Zeile zu erhalten, dann einen <strong>DMG + Irgendetwas Reroll-Trank</strong> zu verwenden, um doppeltes Detail-DMG auf dem Stein zu erzielen.",
        gear_as_note3: "Mit genug Ressourcen kannst du noch weiter gehen und einen Stein mit <strong>drei Schadenswerten</strong> erhalten \u2014 zum Beispiel: <em>Der verursachte DMG wird um 6% erh\u00f6ht / DMG +3% / Detail-DMG +5%</em>.",
        gear_costume_note: "<strong>Wichtig:</strong> Wende zuerst immer eine <strong>Premium / Super Premium Karte</strong> auf die blaue Karte aus der Enzyklop\u00e4die an, dann verwende diese blaue Karte mit Verzauberungen auf deinem Kost\u00fcm.",
        gear_costume_h5_head: "Kopfst\u00fcck - 12% DMG gegen Bosse",
        gear_costume_head_li1: "F\u00fcge eine 10% Boss-DMG-Verzauberung hinzu.",
        gear_costume_head_li2: "Option A: F\u00fcge eine Super-Verzauberung mit 4% HP + 2% EVA hinzu.",
        gear_costume_head_li3: "Option B: F\u00fcge eine Super-Verzauberung mit 4% HP + 4% HEAL hinzu.",
        gear_costume_h5_body: "K\u00f6rper - 20% CRIT DMG gegen Bosse",
        gear_costume_body_li1: "F\u00fcge eine 25% Boss-CRIT-DMG-Verzauberung hinzu.",
        gear_costume_body_li2: "F\u00fcge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
        gear_costume_h5_face: "Gesicht - W\u00e4hle, was du am meisten brauchst (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_face_li1: "F\u00fcge eine Klassenverzauberung hinzu.",
        gear_costume_face_li2: "Option A: F\u00fcge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
        gear_costume_face_li3: "Option B: F\u00fcge eine Super-Verzauberung mit 4% DMG + Reduziere 4% erlittenen DMG hinzu.",
        gear_costume_h5_back: "R\u00fccken - Priorit\u00e4t auf 8% Bewegungsgeschwindigkeit. Ansonsten w\u00e4hle, was du am meisten brauchst (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_back_li1: "F\u00fcge eine Bewegungsgeschwindigkeits-Verzauberung hinzu.",
        gear_costume_back_li2: "F\u00fcge eine Super-Verzauberung mit 4% DMG + 4% HP hinzu.",
        gear_costume_h5_weapon: "Waffe - 12% Elementarf\u00e4higkeits-DMG",
        gear_costume_weapon_li1: "F\u00fcge eine Klassenverzauberung hinzu.",
        gear_costume_weapon_li2: "F\u00fcge eine Super-Verzauberung mit 4% DMG + 2% CRIT hinzu.",
        modal_boost_title: "Schaden erh\u00f6hen",
        modal_boost_intro: "Dieser Guide konzentriert sich auf praktische Wege, deinen Gesamtschaden zu steigern.",
        boost_back_strike: "R\u00fcckenangriff",
        boost_back_strike_p1: "R\u00fcckenangriff bedeutet, Feinde von hinten anzugreifen. Dadurch erh\u00e4ltst du 50% verst\u00e4rkten Schaden.",
        boost_back_strike_p2: "Positioniere dich wann immer m\u00f6glich hinter dem Ziel, um diesen Bonus aufrechtzuerhalten.",
        boost_jump_casting: "Sprungwirken",
        boost_jump_p1: "Sprungwirken ist eine Kampfmechanik, bei der du springst und dann deine F\u00e4higkeiten einsetzt. Dies hilft, viele Animationen zu unterbrechen oder zu verk\u00fcrzen, die dich normalerweise festhalten w\u00fcrden.",
        boost_jump_p2: "Es verwebt auch normale Angriffe zwischen F\u00e4higkeiten, was deinen Gesamtschaden \u00fcber die Zeit erh\u00f6ht.",
        boost_amp_sources: "Quellen f\u00fcr verst\u00e4rkten Schaden",
        boost_amp_intro: "Referenzliste g\u00e4ngiger Quellen, die deinen verst\u00e4rkten Schaden im Kampf erh\u00f6hen k\u00f6nnen.",
        modal_dungeon_title: "Eidolon-Fundorte",
        modal_dungeon_note: "<strong>Hinweis:</strong> Eidolons, die hier nicht aufgef\u00fchrt sind, k\u00f6nnen im Treue-Punkte-Shop, durch den Kauf von anderen Spielern, \u00fcber das Auktionshaus, durch Paragon oder bei In-Game-Events erhalten werden.",
      },
      fr: {
        nav_guides: "Guides \u25be",
        nav_class_guides: "Guides de Classe \u25be",
        btn_what_is: "Qu'est-ce que",
        btn_eidolon_leveling: "Monter en niveau l'Eidolon",
        btn_gear_guide: "Guide d'\u00c9quipement",
        btn_boost_damage: "Augmenter vos d\u00e9g\u00e2ts",
        btn_spawn_location: "Emplacements d'Apparition",
        btn_best_eidolons: "Meilleurs Eidolons",
        btn_useful_links: "Liens utiles",
        btn_close: "Fermer",
        search_placeholder: "Rechercher par Eidolon, combo ou bonus...",
        modal_best_eidolons_title: "Meilleurs Eidolons",
        modal_best_eidolons_warning_label: "Liste obsol\u00e8te :",
        modal_best_eidolons_warning_text: " ces informations datent de juillet 2024 et peuvent ne plus refl\u00e9ter les meilleurs choix actuels.",
        modal_best_eidolons_legend: "= Excellent avec le Symbole d'Eidolon",
        modal_best_eidolons_footer: "Je ne sais pas \u00e0 qui attribuer ces informations. Si c'est le v\u00f4tre et que vous souhaitez une mention, contactez-moi sur Discord.",
        section_universal: "Eidolons Universels",
        section_dark: "Eidolons des T\u00e9n\u00e8bres",
        section_holy: "Eidolons Sacr\u00e9s",
        section_flame: "Eidolons de Feu",
        section_storm: "Eidolons de Temp\u00eate",
        section_ice: "Eidolons de Glace",
        section_lightning: "Eidolons de Foudre",
        section_physical: "Eidolons Physiques",
        modal_useful_links_title: "Liens utiles",
        modal_useful_links_intro: "Guides et ressources communautaires.",
        modal_class_guide_title: "Guides de Classe",
        modal_class_guide_intro: "Ce menu est pr\u00eat pour des guides par classe d'Aura Kingdom.",
        modal_lucky_pack_title: "Packs Chanceux d'Eidolon",
        modal_lucky_pack_p1: "Les Packs Chanceux d'Eidolon sont utilis\u00e9s dans la Tani\u00e8re de l'Eidolon dans votre maison pour augmenter l'intimit\u00e9.",
        modal_lucky_pack_p2: "Les statistiques de base obtenues en montant l'intimit\u00e9 sont appliqu\u00e9es \u00e0 votre personnage :",
        modal_lucky_pack_p3: "C'est pourquoi tous les Eidolons devraient atteindre au moins le niveau 8 d'intimit\u00e9. Il faut environ 280 packs pour passer du niveau 1 au niveau 8. Le niveau 10 est optionnel.",
        modal_wish_coin_title: "Pi\u00e8ces de Souhait d'Eidolon",
        modal_wish_coin_p1: "Les Pi\u00e8ces de Souhait sont utilis\u00e9es pour exaucer le v\u0153u d'un Eidolon sans avoir besoin de rassembler les objets demand\u00e9s.",
        modal_wish_coin_p2: "Toutes les statistiques ainsi obtenues sont appliqu\u00e9es \u00e0 votre personnage.",
        modal_wish_coin_cost: "Co\u00fbt en Pi\u00e8ces de Souhait par niveau de v\u0153u :",
        modal_wish_coin_outro: "Tous les Eidolons devraient avoir leurs v\u0153ux exauc\u00e9s. C'est l'une des plus grandes sources de statistiques brutes.",
        modal_limit_break_title: "Dispositifs de Perc\u00e9e de Carte",
        modal_limit_break_p1: "Les Dispositifs de Perc\u00e9e de Carte sont utilis\u00e9s pour augmenter le niveau de perc\u00e9e d'une carte de 1 \u00e0 10.",
        modal_limit_break_p2: "Atteindre le niveau 10 d\u00e9bloquee le <strong>Bonus de Statut</strong> de la carte, appliqu\u00e9 d\u00e9finitivement \u00e0 votre personnage.",
        modal_limit_break_tier: "Niveau de dispositif requis par niveau :",
        modal_limit_break_t1: "Niveaux 1\u20133 : Dispositif de Perc\u00e9e Basique",
        modal_limit_break_t2: "Niveaux 4\u20137 : Dispositif de Perc\u00e9e Interm\u00e9diaire",
        modal_limit_break_t3: "Niveaux 7\u201310 : Dispositif de Perc\u00e9e Avanc\u00e9",
        modal_limit_break_outro: "Privil\u00e9giez le niveau 10 sur les cartes avec les Bonus de Statut les plus puissants pour votre build.",
        modal_leveling_title: "Mont\u00e9e en Niveau de l'Eidolon",
        modal_leveling_p1: "Pour monter un Eidolon du niveau 25 au niveau 80, vous pouvez utiliser les cristaux ci-dessous :",
        modal_skill_leveling_title: "Mont\u00e9e en Niveau des Comp\u00e9tences (Mana Starstone)",
        modal_skill_leveling_p: "Monter en niveau les comp\u00e9tences de vos Eidolons principaux est tr\u00e8s important, car leurs comp\u00e9tences deviennent plus puissantes et gagnent des buffs/debuffs suppl\u00e9mentaires.",
        modal_skill_leveling_total: "Total de Mana Starstone n\u00e9cessaire : 6700",
        modal_gear_title: "Guide d'\u00c9quipement",
        modal_gear_intro: "Cette section couvre les priorit\u00e9s pratiques de fabrication de votre \u00e9quipement.",
        gear_crafting_notes: "Notes de Fabrication",
        gear_weapon_progression: "Progression des Armes par Niveau",
        gear_weapon_core: "Options de Noyau d'Arme",
        gear_armor_core: "Options de Noyau d'Armure / Troph\u00e9e / Accessoires",
        gear_mount_buff: "Bonus de Monture",
        gear_weapon_stone: "Pierre Secr\u00e8te d'Arme",
        gear_armor_stone: "Pierre Secr\u00e8te d'Armure",
        gear_armor_stone_reroll: "Meilleures Statistiques \u00e0 Viser (Reroll)",
        gear_costume: "Costume",
        gear_crafting_li1: "Votre arme doit utiliser l'\u00e9l\u00e9ment de votre classe car elle inflige 20% de d\u00e9g\u00e2ts \u00e9l\u00e9mentaires suppl\u00e9mentaires.",
        gear_crafting_li2: "L'\u00e9l\u00e9ment de l'armure s'applique uniquement sur la pi\u00e8ce de poitrine et offre une d\u00e9fense suppl\u00e9mentaire contre cet \u00e9l\u00e9ment. L'armure de l'\u00e9l\u00e9ment T\u00e9n\u00e8bres est g\u00e9n\u00e9ralement pr\u00e9f\u00e9r\u00e9e.",
        gear_crafting_li3: "Essayez de fabriquer des \u00e9quipements avec au moins 120%+ de qualit\u00e9. C'est moins important pour l'armure, mais une haute qualit\u00e9 d'arme augmente les d\u00e9g\u00e2ts notablement.",
        gear_crafting_li4: "Le plafond de qualit\u00e9 est de 130% pour l'\u00e9quipement Orange et de 140% pour l'\u00e9quipement Or.",
        gear_wp_note: "Les armes actuelles les plus puissantes se farment dans Abyss II pour chaque \u00e9l\u00e9ment. Elles sont les meilleurs choix \u00e0 Lv95, S15 et S35, donc apr\u00e8s Lv95 vous n'avez g\u00e9n\u00e9ralement pas besoin d'autres lignes d'armes.",
        gear_wp_li1: "<strong>En dessous de Lv95 :</strong> Utilisez les armes de r\u00e9compense d'Aura et de Gaia Avanc\u00e9 (une de Lv1-40 et une de Lv40-75). Elles peuvent vous porter confortablement jusqu'\u00e0 Lv95.",
        gear_wp_li2: "<strong>Lv95 :</strong> Fabriquez l'arme Abyss II pour votre \u00e9l\u00e9ment : Hebe (Glace), Cerberus (Feu), Izanami (T\u00e9n\u00e8bres), Michaela (Saint), Demeter (Temp\u00eate), Hermes (Foudre). Pour les builds physiques, choisissez l'arme qui offre le meilleur boost \u00e0 vos comp\u00e9tences principales. Si vous ne voulez pas encore Abyss II, utilisez l'or Lv95 avec votre \u00e9l\u00e9ment ou fabriquez l'orange Lv90 avec votre noyau pr\u00e9f\u00e9r\u00e9.",
        gear_wp_li3: "<strong>S5 :</strong> Si vous n'avez toujours pas d'option Lv95, fabriquez l'arme \u00e9l\u00e9mentaire Abyss II ou utilisez une arme en or S5 avec votre \u00e9l\u00e9ment.",
        gear_wp_li4: "<strong>S10 :</strong> L'arme Abyss II Lv95 est toujours bonne ici. Si vous voulez vraiment changer, fabriquez l'arme orange S10.",
        gear_wp_li5: "<strong>S15 :</strong> Fabriquez l'arme Abyss II S15 pour votre \u00e9l\u00e9ment. C'est votre meilleure ligne d'arme jusqu'\u00e0 S35.",
        gear_wp_li6: "<strong>S35 :</strong> Vous pouvez passer \u00e0 l'or S35 pour votre \u00e9l\u00e9ment, mais c'est optionnel. La meilleure arme est toujours Abyss II S35 de votre \u00e9l\u00e9ment ; S35 Abyss II est difficile \u00e0 farmer, alors changez quand vous \u00eates assez fort et pouvez le farmer r\u00e9guli\u00e8rement.",
        gear_wc_li1: "<strong>Destructeur :</strong> 10% de r\u00e9duction de DEF.",
        gear_wc_li2: "<strong>Nocturne :</strong> 3% d'absorption de d\u00e9g\u00e2ts en HP. Ceci est r\u00e9duit dans certains donjons.",
        gear_wc_li3: "<strong>Mortel :</strong> 15% de CRIT DMG.",
        gear_wc_li4: "<strong>Restaurateur (Barde uniquement) :</strong> 10% de Soin.",
        gear_ac_li1: "<strong>Imp\u00e9rial :</strong> 3% de Vitesse de D\u00e9placement.",
        gear_ac_li2: "<strong>B\u00e9ni :</strong> 5% de Gain d'EXP.",
        gear_ac_li3: "<strong>Bestial :</strong> 1% DMG + 1% HP.",
        gear_ac_li4: "<strong>\u00c9pineux :</strong> 1% DMG + 1% DEF.",
        gear_mb_li1: "40% de bonus aux d\u00e9g\u00e2ts de comp\u00e9tence \u00e9l\u00e9mentaire de votre classe.",
        gear_ws_note: "Obtenez toujours la pierre secr\u00e8te pour la comp\u00e9tence de votre classe.",
        gear_ws_li1: "<strong>Pierre Secr\u00e8te Per\u00e7ante</strong> \u2014 La meilleure dans son emplacement, mais ch\u00e8re.",
        gear_ws_li2: "<strong>Pierre Secr\u00e8te de Lave</strong> \u2014 Moins ch\u00e8re que la Per\u00e7ante et peut \u00eatre farm\u00e9e dans le Purgatoire Pyroclastique.",
        gear_ws_li3: "<strong>Pierre Ma\u00eetre de Classe Orange</strong> \u2014 \u00c0 utiliser comme rempla\u00e7ante avant d'obtenir Lave ou mieux.",
        gear_as_note1: "Achetez-les chez le Ma\u00eetre de votre classe \u00e0 Navea. Elles seront orange \u2014 ne vous inqui\u00e9tez pas des statistiques. Montez-les au niveau 70, puis am\u00e9liorez-les en violet pour ajouter une statistique suppl\u00e9mentaire, et elles seront pr\u00eates pour le reroll.",
        gear_as_li1: "<strong>Detail-DMG</strong> (ou DMG) : +5 / +4 / +3",
        gear_as_li2: "<strong>CRIT DMG :</strong> +10 / +8 / +6",
        gear_as_note2: "Visez toujours <strong>Detail-DMG +5%</strong> ou au moins <strong>DMG +4%</strong>. La strat\u00e9gie la plus courante est d'obtenir <strong>Detail-DMG +5</strong> sur la derni\u00e8re ligne, puis d'utiliser une <strong>potion de reroll DMG + Quelque chose</strong> pour viser le double Detail-DMG sur la pierre.",
        gear_as_note3: "Avec assez d'\u00e9conomie, vous pouvez aller plus loin et obtenir une pierre avec <strong>trois statistiques de d\u00e9g\u00e2ts</strong> \u2014 par exemple : <em>Les DMG caus\u00e9s augmentent de 6% / DMG +3% / Detail-DMG +5%</em>.",
        gear_costume_note: "<strong>Important :</strong> Appliquez toujours une <strong>Carte Premium / Super Premium</strong> \u00e0 la carte bleue achet\u00e9e dans l'Encyclop\u00e9die d'abord, puis utilisez cette carte bleue avec des enchantements sur votre costume.",
        gear_costume_h5_head: "Coiffe - 12% DMG contre les Boss",
        gear_costume_head_li1: "Ajoutez un Enchantement de 10% DMG contre les Boss.",
        gear_costume_head_li2: "Option A : Ajoutez un Super Enchantement de 4% HP + 2% EVA.",
        gear_costume_head_li3: "Option B : Ajoutez un Super Enchantement de 4% HP + 4% HEAL.",
        gear_costume_h5_body: "Corps - 20% CRIT DMG contre les Boss",
        gear_costume_body_li1: "Ajoutez un Enchantement de 25% CRIT DMG contre les Boss.",
        gear_costume_body_li2: "Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
        gear_costume_h5_face: "Visage - Choisissez ce dont vous avez le plus besoin (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_face_li1: "Ajoutez un Enchantement de Classe.",
        gear_costume_face_li2: "Option A : Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
        gear_costume_face_li3: "Option B : Ajoutez un Super Enchantement de 4% DMG + R\u00e9duire 4% DMG re\u00e7us.",
        gear_costume_h5_back: "Dos - Priorit\u00e9 \u00e0 8% Vitesse de D\u00e9placement. Sinon, Choisissez ce dont vous avez le plus besoin (7% DMG / 7% SPD / 7% CRIT)",
        gear_costume_back_li1: "Ajoutez un Enchantement de Vitesse de D\u00e9placement.",
        gear_costume_back_li2: "Ajoutez un Super Enchantement de 4% DMG + 4% HP.",
        gear_costume_h5_weapon: "Arme - 12% DMG de Comp\u00e9tence \u00c9l\u00e9mentaire",
        gear_costume_weapon_li1: "Ajoutez un Enchantement de Classe.",
        gear_costume_weapon_li2: "Ajoutez un Super Enchantement de 4% DMG + 2% CRIT.",
        modal_boost_title: "Augmenter vos d\u00e9g\u00e2ts",
        modal_boost_intro: "Ce guide se concentre sur les moyens pratiques d'augmenter vos d\u00e9g\u00e2ts globaux.",
        boost_back_strike: "Frappe dans le Dos",
        boost_back_strike_p1: "La Frappe dans le Dos consiste \u00e0 attaquer les ennemis par derri\u00e8re. Cela accorde <strong>50% de d\u00e9g\u00e2ts amplifi\u00e9s</strong>.",
        boost_back_strike_p2: "Chaque fois que possible, repositionnez-vous pour rester derri\u00e8re la cible et maintenir ce bonus.",
        boost_jump_casting: "Lancement en Saut",
        boost_jump_p1: "Le Lancement en Saut est une m\u00e9canique de combat o\u00f9 vous sautez puis lancez vos comp\u00e9tences. Cela aide \u00e0 annuler ou raccourcir de nombreuses animations qui vous immobiliseraient normalement.",
        boost_jump_p2: "Il intercale \u00e9galement des attaques de base entre les comp\u00e9tences, ce qui augmente vos d\u00e9g\u00e2ts totaux au fil du temps.",
        boost_amp_sources: "Sources de D\u00e9g\u00e2ts Amplifi\u00e9s",
        boost_amp_intro: "Liste de r\u00e9f\u00e9rence des sources courantes pouvant augmenter vos d\u00e9g\u00e2ts amplifi\u00e9s en combat.",
        modal_dungeon_title: "Emplacements d'Apparition des Eidolons",
        modal_dungeon_note: "<strong>Note :</strong> Les Eidolons non list\u00e9s ici peuvent \u00eatre obtenus dans la boutique de Points de Fid\u00e9lit\u00e9, en achetant \u00e0 d'autres joueurs, via la Maison des Ventes, en jouant \u00e0 Paragon ou lors d'\u00e9v\u00e9nements en jeu.",
      },
    };
    function applyLang(lang) {
      const t = TRANSLATIONS[lang] || TRANSLATIONS.en;
      document.querySelectorAll('[data-i18n]').forEach(el => {
        const key = el.getAttribute('data-i18n');
        if (t[key] !== undefined) el.textContent = t[key];
      });
      document.querySelectorAll('[data-i18n-html]').forEach(el => {
        const key = el.getAttribute('data-i18n-html');
        if (t[key] !== undefined) el.innerHTML = t[key];
      });
      document.querySelectorAll('[data-i18n-placeholder]').forEach(el => {
        const key = el.getAttribute('data-i18n-placeholder');
        if (t[key] !== undefined) el.setAttribute('placeholder', t[key]);
      });
      document.querySelectorAll('.lang-btn').forEach(btn => {
        btn.classList.toggle('active', btn.getAttribute('data-lang') === lang);
      });
      localStorage.setItem('eidolonLang', lang);
    }
    const infoMenus = Array.from(document.querySelectorAll('.info-menu'));
    infoMenus.forEach(menu => {
      menu.addEventListener('toggle', () => {
        if (menu.open) infoMenus.forEach(other => { if (other !== menu && other.open) other.open = false; });
      });
    });
    const langSelector = document.querySelector('.lang-selector');
    langSelector.querySelectorAll('.lang-btn').forEach(btn => {
      btn.addEventListener('click', e => {
        e.stopPropagation();
        if (!langSelector.classList.contains('open')) { langSelector.classList.add('open'); }
        else { applyLang(btn.getAttribute('data-lang')); langSelector.classList.remove('open'); }
      });
    });
    document.addEventListener('click', e => { if (!langSelector.contains(e.target)) langSelector.classList.remove('open'); });
    applyLang(localStorage.getItem('eidolonLang') || 'en');
'@
    foreach ($line in $translationsJs -split "`n") {
        [void]$sb.AppendLine($line.TrimEnd())
    }
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
$eidolonCount = $knownEidolonNames.Count
$luckyPackTotals = [pscustomobject]@{
    EidolonCount = $eidolonCount
    CRIT = 46 * $eidolonCount
    HP = 145 * $eidolonCount
    EVA = 61 * $eidolonCount
    DMG = 119 * $eidolonCount
    SPD = 38 * $eidolonCount
    DEF = 23 * $eidolonCount
}

Write-Host "      Loading Eidolon Wishes stat totals..."
$wishStatsTotals = @(Get-EidolonWishStatsTotals -WishesUrl $EidolonWishesUrl)
if ($wishStatsTotals.Count -gt 0) {
    Write-Host ("      Wish stat totals loaded: " + $wishStatsTotals.Count)
} else {
    Write-Warning "Could not load Wish stat totals. Continuing without totals section values."
}

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
$page = Build-PageHtml -Rows $rows -IconMap $iconMap -DungeonGuideItems $dungeonGuideItems -WishStatsTotals $wishStatsTotals -LuckyPackTotals $luckyPackTotals

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

