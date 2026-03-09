# Pack addon into ProfLevelHelper folder and create ProfLevelHelper.zip.
# Excludes: .git/, this script, ProfLevelHelper/ (output dir), *.zip

$ErrorActionPreference = "Stop"
$scriptPath = $PSCommandPath
$packRoot = Split-Path $scriptPath -Parent
$destFolderName = "ProfLevelHelper"
$destFolder = Join-Path $packRoot $destFolderName
$zipPath = Join-Path $packRoot "$destFolderName.zip"

# Remove existing output folder and zip from previous run
if (Test-Path $destFolder) {
    Remove-Item $destFolder -Recurse -Force
}
if (Test-Path $zipPath) {
    Remove-Item $zipPath -Force
}

New-Item -ItemType Directory -Path $destFolder | Out-Null

$packRootLen = $packRoot.Length
$allFiles = Get-ChildItem -Path $packRoot -Recurse -File -Force

foreach ($f in $allFiles) {
    $full = $f.FullName
    $rel = $full.Substring($packRootLen).TrimStart([System.IO.Path]::DirectorySeparatorChar).TrimStart('/')
    $relNorm = $rel -replace '/', '\'

    # Exclude .git/
    if ($relNorm -match '^\.git\\' -or $relNorm -eq '.git') { continue }
    # Exclude this script
    if ($full -eq $scriptPath) { continue }
    # Exclude ProfLevelHelper/ (output folder)
    if ($relNorm -match '^ProfLevelHelper\\' -or $relNorm -eq 'ProfLevelHelper') { continue }
    # Exclude *.zip
    if ($f.Extension -eq '.zip') { continue }

    $destPath = Join-Path $destFolder $rel
    $destDir = Split-Path $destPath -Parent
    if (-not (Test-Path $destDir)) {
        New-Item -ItemType Directory -Path $destDir -Force | Out-Null
    }
    Copy-Item -LiteralPath $full -Destination $destPath -Force
}

Compress-Archive -Path $destFolder -DestinationPath $zipPath -Force
Remove-Item $destFolder -Recurse -Force

Write-Host "Done: $zipPath"
