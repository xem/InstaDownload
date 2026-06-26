# =========================
# CONFIG
# =========================
$baseDir = Join-Path $PSScriptRoot "downloads"
$jsonPath = Join-Path $PSScriptRoot "liked_posts.json"

# =========================
# DELETE PLACEHOLDERS
# =========================
Write-Host "Scanning for 0-byte placeholders..."

$deletedCount = 0

Get-ChildItem -Path $baseDir -Recurse -Filter "*.mp4" -File | ForEach-Object {

    if ($_.Length -eq 0) {
        Write-Host "[DELETE] placeholder : $($_.FullName)"
        Remove-Item $_.FullName -Force
        $deletedCount++
    }
}

Write-Host "Deleted placeholders : $deletedCount"
Write-Host ""

# =========================
# LOAD JSON
# =========================
$raw = Get-Content $jsonPath -Raw | ConvertFrom-Json

if ($raw -is [System.Collections.IEnumerable]) {
    $posts = $raw
}
elseif ($raw.PSObject.Properties.Name -contains "likes_media_likes") {
    $posts = $raw.likes_media_likes
}
else {
    $keys = $raw.PSObject.Properties.Name |
        Where-Object { $_ -match '^\d+$' } |
        Sort-Object { [int]$_ }

    $posts = foreach ($k in $keys) {
        $raw.$k
    }
}

Write-Host "Initial posts : $($posts.Count)"
Write-Host ""

# =========================
# KEEP ONLY NEW POSTS
# =========================
$remaining = @()
$foundExisting = $false

foreach ($post in $posts) {

    if ($foundExisting) {
        continue
    }

    $urlBlock = $post.label_values |
        Where-Object { $_.label -eq "URL" }

    if (-not $urlBlock) {
        $remaining += $post
        continue
    }

    $url = $urlBlock.value

    if (-not $url) {
        $remaining += $post
        continue
    }

    $match = [regex]::Match(
        $url,
        "/(p|reel|tv)/([^/?]+)/?"
    )

    if (-not $match.Success) {
        $remaining += $post
        continue
    }

    $instaID = $match.Groups[2].Value

    if ($post.timestamp) {
        $year = [datetimeoffset]::FromUnixTimeSeconds(
            [int64]$post.timestamp
        ).Year
    }
    else {
        $year = "unknown"
    }

    $expectedMp4 = Join-Path $baseDir "$year\$instaID.mp4"

    if (Test-Path $expectedMp4) {

        $fileInfo = Get-Item $expectedMp4

        # sécurité : ne considérer que les vrais téléchargements
        if ($fileInfo.Length -gt 0) {

            Write-Host "[FOUND EXISTING] $instaID"
            Write-Host "[TRUNCATE] removing this entry and all older entries"
            Write-Host ""

            $foundExisting = $true
            continue
        }
    }

    $remaining += $post
}

# =========================
# SAVE JSON
# =========================
$remaining |
    ConvertTo-Json -Depth 100 |
    Set-Content $jsonPath -Encoding UTF8

Write-Host "Remaining posts : $($remaining.Count)"
Write-Host "Removed posts   : $($posts.Count - $remaining.Count)"
Write-Host ""
Write-Host "=== CLEANUP DONE ==="