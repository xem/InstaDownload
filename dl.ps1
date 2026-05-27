# =========================
# CONFIG
# =========================
$yt = Join-Path $PSScriptRoot "yt-dlp.exe"
$baseDir = Join-Path $PSScriptRoot "downloads"
$cookies = Join-Path $PSScriptRoot "cookies.txt"

New-Item -ItemType Directory -Force -Path $baseDir | Out-Null

# slows down IG scraping massively
$sleepBetween = 20   # seconds

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

# =========================
# DOWNLOAD LOOP
# =========================
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

        # year from timestamp
        $timestamp = $post.timestamp
        if ($timestamp) {
            $year = [datetimeoffset]::FromUnixTimeSeconds($timestamp).Year
        } else {
            $year = "unknown"
        }

        $outDir = Join-Path $baseDir $year
        New-Item -ItemType Directory -Force -Path $outDir | Out-Null

        $expectedMp4 = Join-Path $outDir "$instaID.mp4"

        # SKIP if already present
        if (Test-Path $expectedMp4) {
            Write-Host "[SKIP] already exists : $instaID.mp4"
            continue
        }

        Write-Host "[$year] DL : $url"

        # build yt-dlp command
        $cmd = @(
            "--ignore-errors",
            "--no-warnings",
            "--retries", "3",
            "--force-ipv4",
            "--sleep-requests", "5",
            "--sleep-interval", "10",
            "--max-sleep-interval", "20",
            "--output", "$outDir/%(id)s.%(ext)s"
        )

        if (Test-Path $cookies) {
            $cmd += @("--cookies", $cookies)
        }

        # execute yt-dlp
        $output = & $yt @cmd "$url" 2>&1
        $outText = $output -join "`n"

        # =========================
        # RATE LIMIT → STOP
        # =========================
        if ($outText -match "(?i)rate.?limit|429|too many requests") {
            Write-Host ""
            Write-Host "[RATE LIMIT] stop execution"
            Write-Host "=== END ==="
            break
        }

        # =========================
        # NO VIDEO / PRIVATE / DEAD POST → placeholder
        # =========================
        if ($outText -match "(?i)isn't available|not available|private|login required|restricted|404|video unavailable|ERROR") {

            if (!(Test-Path $expectedMp4)) {
                "" | Out-File -Encoding ascii $expectedMp4
                Write-Host "[PLACEHOLDER] created : $instaID.mp4"
            } else {
                Write-Host "[PLACEHOLDER] already exists : $instaID.mp4"
            }

            Start-Sleep -Seconds $sleepBetween
            continue
        }

        # =========================
        # If yt-dlp did not produce a file → create placeholder
        # =========================
        if (!(Test-Path $expectedMp4)) {
            "" | Out-File -Encoding ascii $expectedMp4
            Write-Host "[PLACEHOLDER] fallback : $instaID.mp4"
        }

        # delay to avoid IG captcha/rate-limit
        Start-Sleep -Seconds $sleepBetween

    }
    catch {
        Write-Host "[ERROR] exception, creating placeholder: $instaID"
        "" | Out-File -Encoding ascii $expectedMp4
        Start-Sleep -Seconds $sleepBetween
        continue
    }
}

Write-Host "=== END ==="