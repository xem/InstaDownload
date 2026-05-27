# =========================
# CONFIG
# =========================
$baseDir = Join-Path $PSScriptRoot "downloads"
$jsonPath = Join-Path $PSScriptRoot "liked_posts.json"

# =========================
# LOAD JSON
# =========================
$raw = Get-Content $jsonPath -Raw | ConvertFrom-Json

if ($raw -is [System.Collections.IEnumerable]) {
    $posts = $raw
}
else {
    $keys = $raw.PSObject.Properties.Name | Where-Object { $_ -match '^\d+$' } | Sort-Object {[int]$_}
    $posts = foreach ($k in $keys) { $raw.$k }
}

Write-Host "Initial posts: $($posts.Count)"

# =========================
# FILTER
# =========================
$remaining = @()

foreach ($post in $posts) {

    $urlBlock = $post.label_values | Where-Object { $_.label -eq "URL" }
    if (-not $urlBlock) {
        $remaining += $post
        continue
    }

    $url = $urlBlock.value
    $match = [regex]::Match($url, "/(p|reel|tv)/([^/?]+)/?")
    if (-not $match.Success) {
        $remaining += $post
        continue
    }

    $instaID = $match.Groups[2].Value

    $timestamp = $post.timestamp
    if ($timestamp) {
        $year = [datetimeoffset]::FromUnixTimeSeconds($timestamp).Year
    } else {
        $year = "unknown"
    }

    $filePath = Join-Path $baseDir "$year\$instaID.mp4"

    if (Test-Path $filePath) {
        Write-Host "[REMOVE] already downloaded : $instaID"
        continue
    }

    $remaining += $post
}

# =========================
# SAVE BACK
# =========================
$remaining | ConvertTo-Json -Depth 20 | Set-Content $jsonPath -Encoding UTF8

Write-Host "Remaining posts: $($remaining.Count)"
Write-Host "=== CLEANUP DONE ==="