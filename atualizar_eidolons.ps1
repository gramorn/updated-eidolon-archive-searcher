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
$GuideIconSources = @{
    "I80914.png" = "https://cdn.aurakingdom-db.com/images/icons/I80914.png"
    "I81010.png" = "https://cdn.aurakingdom-db.com/images/icons/I81010.png"
    "I80781.png" = "https://cdn.aurakingdom-db.com/images/icons/I80781.png"
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
    [void]$sb.AppendLine("    .lucky-pack-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .lucky-pack-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .lucky-pack-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .wish-coin-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .wish-coin-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .wish-coin-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
    [void]$sb.AppendLine("    .limit-break-btn { height:40px; border-radius:10px; border:1px solid var(--line); background:var(--card); display:inline-flex; align-items:center; justify-content:center; cursor:pointer; padding:0 10px; gap:6px; color:var(--ink); font-size:0.82rem; font-weight:600; }")
    [void]$sb.AppendLine("    .limit-break-btn:hover { border-color:var(--accent); }")
    [void]$sb.AppendLine("    .limit-break-icon { width:24px; height:24px; border-radius:6px; object-fit:cover; }")
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
    [void]$sb.AppendLine("    @media (max-width:760px) { .top-row { align-items:stretch; flex-direction:column; } .top-actions { width:100%; justify-content:flex-start; } .lucky-pack-btn, .wish-coin-btn, .limit-break-btn { min-height:40px; padding:6px 10px; } .theme-toggle { flex:0 0 auto; } th, td { padding:7px 6px; font-size:0.84rem; } }")
    [void]$sb.AppendLine("  </style>")
    [void]$sb.AppendLine("</head>")
    [void]$sb.AppendLine("<body style=`"background-color:#0f141d`">")
    [void]$sb.AppendLine("  <div class=`"topbar`"><div class=`"wrap`">")
    [void]$sb.AppendLine("    <div class=`"top-row`">")
    [void]$sb.AppendLine("      <div>")
    [void]$sb.AppendLine("        <h1>Eidolon Archive</h1>")
    [void]$sb.AppendLine("        <p>Data automatically extracted from AuraKingdom-DB.</p>")
    [void]$sb.AppendLine("      </div>")
    [void]$sb.AppendLine("      <div class=`"top-actions`">")
    [void]$sb.AppendLine("        <button id=`"luckyPackInfoBtn`" class=`"lucky-pack-btn`" type=`"button`" title=`"What are Eidolon Lucky Packs?`" aria-label=`"What are Eidolon Lucky Packs?`">What is <img class=`"lucky-pack-icon`" src=`"assets/icons/I80914.png`" alt=`"Eidolon Lucky Pack`">?</button>")
    [void]$sb.AppendLine("        <button id=`"wishCoinInfoBtn`" class=`"wish-coin-btn`" type=`"button`" title=`"What are Eidolon Wish Coins?`" aria-label=`"What are Eidolon Wish Coins?`">What is <img class=`"wish-coin-icon`" src=`"assets/icons/I81010.png`" alt=`"Eidolon Wish Coin`">?</button>")
    [void]$sb.AppendLine("        <button id=`"limitBreakInfoBtn`" class=`"limit-break-btn`" type=`"button`" title=`"What are Card Breakthrough Devices?`" aria-label=`"What are Card Breakthrough Devices?`">What is <img class=`"limit-break-icon`" src=`"assets/icons/I80781.png`" alt=`"Card Breakthrough Device`">?</button>")
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

