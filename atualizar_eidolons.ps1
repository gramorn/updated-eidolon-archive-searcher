param(
    [string]$Url = "https://www.aurakingdom-db.com/charts/eidolon-archive",
    [string]$OutputHtml = "index.html",
    [string]$AssetsDir = "assets/eidolons",
    [switch]$KeepRemoteIcons
)

$ErrorActionPreference = "Stop"
Set-StrictMode -Version Latest
Add-Type -AssemblyName System.Web

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

function Build-PageHtml {
    param(
        [array]$Rows,
        [hashtable]$IconMap
    )

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
    [void]$sb.AppendLine("    html { background-color:#0f141d; } body { margin:0; font-family: `"Segoe UI`", Tahoma, sans-serif; background: radial-gradient(circle at top, var(--bg-top), var(--bg)); color:var(--ink); } body[data-theme='light'] { background-color:#fff6ef; }")
    [void]$sb.AppendLine("    .wrap { width:min(1100px, 94vw); margin: 8px auto 24px; }")
    [void]$sb.AppendLine("    h1 { margin:0 0 2px; font-size: clamp(1rem, 2vw, 1.4rem); }")
    [void]$sb.AppendLine("    p { margin:0; color:var(--muted); font-size:0.85rem; }")
    [void]$sb.AppendLine("    .topbar { position: sticky; top:0; z-index:10; padding:6px 0; backdrop-filter: blur(6px); background: color-mix(in srgb, var(--bg-top) 78%, transparent); border-bottom:1px solid var(--line); margin-bottom:8px; }")
    [void]$sb.AppendLine("    .search { width:100%; border:1px solid var(--line); border-radius:10px; padding:6px 10px; font-size:0.9rem; background:var(--input-bg); color:var(--input-ink); }")
    [void]$sb.AppendLine("    .section { background:var(--card); border:1px solid var(--line); border-radius:12px; padding:12px; margin-top:14px; box-shadow:0 8px 22px rgba(0,0,0,.28); }")
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
    [void]$sb.AppendLine("    .theme-toggle { width:40px; height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); color:var(--ink); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; }")
    [void]$sb.AppendLine("    .theme-toggle:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .theme-icon { font-size:18px; line-height:1; }")
    [void]$sb.AppendLine("    @media (max-width:760px) { .top-row { align-items:center; } }")
    [void]$sb.AppendLine("  </style>")
    [void]$sb.AppendLine("</head>")
    [void]$sb.AppendLine("<body style=`"background-color:#0f141d`">")
    [void]$sb.AppendLine("  <div class=`"topbar`"><div class=`"wrap`">")
    [void]$sb.AppendLine("    <div class=`"top-row`">")
    [void]$sb.AppendLine("      <div>")
    [void]$sb.AppendLine("        <h1>Eidolon Archive</h1>")
    [void]$sb.AppendLine("        <p>Data automatically extracted from AuraKingdom-DB.</p>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <button id=`"themeToggle`" class=`"theme-toggle`" type=`"button`" aria-label=`"Switch to light theme`" title=`"Switch to light theme`"><span id=`"themeIcon`" class=`"theme-icon`">☀</span></button>")
    [void]$sb.AppendLine("    </div>")
    [void]$sb.AppendLine("    <input id=`"q`" class=`"search`" placeholder=`"Search by Eidolon, combo or bonus...`" title=`"Type to filter combos by Eidolon, combo, or bonus`" aria-label=`"Search combos`">")
    [void]$sb.AppendLine("  </div></div>")
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
if (-not $KeepRemoteIcons) {
    Write-Host "[2/4] Downloading icons to $AssetsDir..."
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
    Write-Host "[2/4] Keeping remote icons (no local download)."
}

Write-Host "[3/4] Building page HTML..."
$page = Build-PageHtml -Rows $rows -IconMap $iconMap

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

