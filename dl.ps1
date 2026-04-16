# =========================
# CONFIG
# =========================
$yt = Join-Path $PSScriptRoot "yt-dlp.exe"
$baseDir = Join-Path $PSScriptRoot "downloads"

New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

# delay (seconds)
$sleepBetween = 5

# =========================
# JSON LOAD
# =========================
$raw = Get-Content "liked_posts.json" -Raw | ConvertFrom-Json

if ($raw -is [System.Collections.IEnumerable]) {
    $posts = $raw
}
elseif ($raw.PSObject.Properties.Name -contains "likes_media_likes") {
    $posts = $raw.likes_media_likes
}
else {
    $keys = $raw.PSObject.Properties.Name | Where-Object { $_ -match '^\d+$' } | Sort-Object {[int]$_}
    $posts = foreach ($k in $keys) { $raw.$k }
}

Write-Host "Links : $($posts.Count)"

# =============
# DOWNLOAD LOOP
# =============
foreach ($post in $posts) {

    try {
        $urlBlock = $post.label_values | Where-Object { $_.label -eq "URL" }
        if (-not $urlBlock) { continue }

        $url = $urlBlock.value
        if (-not $url) { continue }

        # extract ID Instagram
        $match = [regex]::Match($url, "/(p|reel|tv)/([^/?]+)/?")
        if (-not $match.Success) {
            Write-Host "[SKIP] unknown url : $url"
            continue
        }

        $instaID = $match.Groups[2].Value

        # year
        $timestamp = $post.timestamp
        if ($timestamp) {
            $year = [datetimeoffset]::FromUnixTimeSeconds($timestamp).Year
        } else {
            $year = "unknown"
        }

        $outDir = Join-Path $baseDir $year
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null

        $expectedMp4 = Join-Path $outDir "$instaID.mp4"

        # =========================
        # SKIP if present
        # =========================
        if (Test-Path $expectedMp4) {
            Write-Host "[SKIP] existe déjà : $instaID.mp4"
            continue
        }

        Write-Host "[$year] DL : $url"

        # capture output
        $output = & $yt `
            --ignore-errors `
            --no-warnings `
            --retries 3 `
            --force-ipv4 `
            --sleep-requests 1 `
            --sleep-interval 3 `
            --max-sleep-interval 7 `
            --output "$outDir/%(id)s.%(ext)s" `
            "$url" 2>&1

        # =========================
        # DETECT ERRORS
        # =========================
        # normaliser sortie texte
        $outText = $output -join "`n"

        # =========================
        # RATE LIMIT (STOP)
        # =========================
        if ($outText -match "(?i)rate.?limit|too many requests|429") {
            Write-Host ""
            Write-Host "[RATE LIMIT] stop"
            Write-Host $outText
            break
        }

        # =========================
        # NOT AVAILABLE (SKIP)
        # =========================
        if ($outText -match "(?i)isn't available|not available|private|login required|restricted") {
            Write-Host "[SKIP] not available : $instaID"
            continue
        }

        # =========================
        # OTHER ERRORS (optional)
        # =========================
        if ($LASTEXITCODE -ne 0) {
            Write-Host "[ERROR] yt-dlp can't download : $instaID"
            continue
        }

        # =========================
        # SLEEP BETWEEN DL
        # =========================
        Start-Sleep -Seconds $sleepBetween

    }
    catch {
        Write-Host "[ERROR] $_"
    }
}

Write-Host "=== END ==="