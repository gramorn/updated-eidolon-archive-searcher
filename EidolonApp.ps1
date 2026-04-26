# EidolonApp.ps1 - Eidolon Archive Desktop Launcher
# Opens content in app mode (Edge), checks updates in background,
# notifies the user, and updates when accepted.

$ErrorActionPreference = "SilentlyContinue"

$ScriptDir   = if ($PSScriptRoot) { $PSScriptRoot } else { Split-Path -Parent $MyInvocation.MyCommand.Path }
$IndexFile   = Join-Path $ScriptDir "index.html"
$UpdateScr   = Join-Path $ScriptDir "atualizar_eidolons.ps1"
$VersionFile = Join-Path $ScriptDir "version.txt"
$TargetUrl   = "https://www.aurakingdom-db.com/charts/eidolon-archive"

Add-Type -AssemblyName PresentationFramework

# --- Local version ---
$localCount = 0
if (Test-Path $VersionFile) {
    [int]::TryParse(((Get-Content $VersionFile -Raw -Encoding UTF8).Trim()), [ref]$localCount) | Out-Null
}

# --- Locate Edge ---
$EdgeExe = @(
    "$env:ProgramFiles\Microsoft\Edge\Application\msedge.exe",
    "${env:ProgramFiles(x86)}\Microsoft\Edge\Application\msedge.exe",
    "$env:LocalAppData\Microsoft\Edge\Application\msedge.exe"
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$FileUri = "file:///" + $IndexFile.Replace('\', '/')

# --- Open content immediately ---
$edgeProc = $null
if ($EdgeExe) {
    $edgeProc = Start-Process $EdgeExe -ArgumentList "--app=$FileUri", "--window-size=1280,820" -PassThru
} else {
    Start-Process $FileUri
}

# --- Check update in background ---
$rs = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rs.ApartmentState = "STA"
$rs.Open()

$ps = [System.Management.Automation.PowerShell]::Create()
$ps.Runspace = $rs

$ps.AddScript({
    param($url)
    try {
        $req = [System.Net.HttpWebRequest]::Create($url)
        $req.Timeout    = 8000
        $req.UserAgent  = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36"
        $req.AutomaticDecompression = [System.Net.DecompressionMethods]::GZip
        $resp = $req.GetResponse()
        $sr   = New-Object System.IO.StreamReader($resp.GetResponseStream())
        $html = $sr.ReadToEnd()
        $sr.Close(); $resp.Close()

        $m = [regex]::Match($html, '<table id="archive"[\s\S]*?<tbody>([\s\S]*?)</tbody>')
        if (-not $m.Success) { return -1 }
        return ([regex]::Matches($m.Groups[1].Value, '<tr>')).Count
    } catch {
        return -1
    }
}).AddArgument($TargetUrl) | Out-Null

$handle = $ps.BeginInvoke()

# Wait for result (max 12 seconds)
$waited = 0
while (-not $handle.IsCompleted -and $waited -lt 12000) {
    [System.Threading.Thread]::Sleep(300)
    $waited += 300
}

if (-not $handle.IsCompleted) {
    # No response - exit silently
    $ps.Dispose(); $rs.Dispose()
    exit 0
}

$liveCount = [int]($ps.EndInvoke($handle) | Select-Object -First 1)
$ps.Dispose(); $rs.Dispose()

# --- Compare versions ---
# liveCount = number of <tr> rows in archive tbody (= online combo count)
# localCount = combo count saved in version.txt after last update
if ($liveCount -gt 0 -and ($localCount -eq 0 -or $liveCount -gt $localCount)) {

    $msg = if ($localCount -eq 0) {
        "New content detected online ($liveCount entries).`n`nDownload and generate the page now?"
    } else {
        "Update available!`n`nOnline entries : $liveCount`nLocal version  : $localCount`n`nUpdate now?"
    }

    $ans = [System.Windows.MessageBox]::Show(
        $msg,
        "Eidolon Archive - Update Available",
        [System.Windows.MessageBoxButton]::YesNo,
        [System.Windows.MessageBoxImage]::Question
    )

    if ($ans -eq [System.Windows.MessageBoxResult]::Yes) {
        # Close current Edge window (best effort)
        if ($edgeProc -and -not $edgeProc.HasExited) {
            $edgeProc.CloseMainWindow() | Out-Null
            $edgeProc.WaitForExit(2000) | Out-Null
            if (-not $edgeProc.HasExited) {
                $edgeProc | Stop-Process -Force
            }
        }

        # Run update script from the correct folder
        Push-Location $ScriptDir
        try {
            & $UpdateScr
        } finally {
            Pop-Location
        }

        # Reopen Edge with updated content
        if ($EdgeExe) {
            Start-Process $EdgeExe -ArgumentList "--app=$FileUri", "--window-size=1280,820"
        } else {
            Start-Process $FileUri
        }
    }
}
