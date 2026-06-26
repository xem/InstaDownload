# =========================
# BUILD.PS1 (UPDATED)
# =========================

$baseDir = Join-Path $PSScriptRoot "downloads"
$thumbRoot = Join-Path $baseDir "thumbs"
$corruptedFile = Join-Path $baseDir "corrupted.txt"

$ffmpeg = Join-Path $PSScriptRoot "ffmpeg.exe"
$ffprobe = Join-Path $PSScriptRoot "ffprobe.exe"

if (!(Test-Path $ffmpeg)) {
    throw "ffmpeg.exe not found in script directory"
}

if (!(Test-Path $ffprobe)) {
    throw "ffprobe.exe not found in script directory"
}

New-Item -ItemType Directory -Force -Path $thumbRoot | Out-Null

# reset corrupted file
"" | Set-Content -Path $corruptedFile -Encoding UTF8

# =========================
# BUILD VIDEO INDEX
# =========================
$videosByYear = [ordered]@{}

$yearDirs = Get-ChildItem $baseDir -Directory |
    Where-Object { $_.Name -match '^\d{4}$' } |
    Sort-Object Name -Descending

foreach ($yearDir in $yearDirs) {

    $year = $yearDir.Name

    Write-Host ""
    Write-Host "Processing year $year"

    $thumbDir = Join-Path $thumbRoot $year
    New-Item -ItemType Directory -Force -Path $thumbDir | Out-Null

    $videosByYear[$year] = @()

    $mp4Files = Get-ChildItem $yearDir.FullName -Filter "*.mp4" -File

    foreach ($mp4 in $mp4Files) {

        # =========================
        # BASIC CORRUPTION CHECK (0 bytes)
        # =========================
        if ($mp4.Length -le 0) {
            Write-Host "[CORRUPTED - 0B] $($mp4.Name)"
            Add-Content -Path $corruptedFile -Value $mp4.FullName
            continue
        }

        # =========================
        # FFPROBE CHECK (moov atom etc.)
        # =========================
        $durationRaw = $null
        $duration = 0.0

        try {
            $durationRaw = & $ffprobe `
                -v error `
                -show_entries format=duration `
                -of default=noprint_wrappers=1:nokey=1 `
                $mp4.FullName
        }
        catch {
            Write-Host "[CORRUPTED - ffprobe fail] $($mp4.Name)"
            Add-Content -Path $corruptedFile -Value $mp4.FullName
            continue
        }

        if ([string]::IsNullOrWhiteSpace($durationRaw)) {
            Write-Host "[CORRUPTED - invalid metadata] $($mp4.Name)"
            Add-Content -Path $corruptedFile -Value $mp4.FullName
            continue
        }

        [double]::TryParse(
            $durationRaw,
            [System.Globalization.NumberStyles]::Any,
            [System.Globalization.CultureInfo]::InvariantCulture,
            [ref]$duration
        ) | Out-Null

        if ($duration -le 0) {
            Write-Host "[CORRUPTED - zero duration] $($mp4.Name)"
            Add-Content -Path $corruptedFile -Value $mp4.FullName
            continue
        }

        # =========================
        # VIDEO IS VALID → ADD TO INDEX
        # =========================
        $videosByYear[$year] += "./downloads/$year/$($mp4.Name)"

        # =========================
        # THUMB PATH (PNG)
        # =========================
        $thumbFile = Join-Path $thumbDir ($mp4.BaseName + ".png")

        if (Test-Path $thumbFile) {
            Write-Host "[SKIP THUMB] $($mp4.Name)"
            continue
        }

        Write-Host "[THUMB] $($mp4.Name)"

        try {

            # =========================
            # SEEK POSITION
            # =========================
            if ($duration -ge 2) {
                $seek = 2
            }
            else {
                $seek = 0
            }

            # =========================
            # GENERATE THUMBNAIL (PNG)
            # =========================
            & $ffmpeg `
                -hide_banner `
                -loglevel error `
                -y `
                -ss $seek `
                -i $mp4.FullName `
                -frames:v 1 `
                -vf "thumbnail,scale=100:150:force_original_aspect_ratio=increase,crop=100:150" `
                -f image2 `
                $thumbFile

            if (!(Test-Path $thumbFile)) {
                Write-Host "[ERROR] thumbnail not created : $($mp4.Name)"
            }

        }
        catch {
            Write-Host "[ERROR] thumbnail failed : $($mp4.Name)"
            Write-Host $_
        }
    }
}

# =========================
# WRITE JAVASCRIPT FILE
# =========================
$json = $videosByYear | ConvertTo-Json -Depth 10

$jsContent = @"
const mp4 = $json;
"@

$jsPath = Join-Path $baseDir "videos.js"

Set-Content `
    -Path $jsPath `
    -Value $jsContent `
    -Encoding UTF8

Write-Host ""
Write-Host "Generated : $jsPath"
Write-Host "Corrupted list : $corruptedFile"
Write-Host "=== BUILD DONE ==="