InstaDownloader
==

- Step 1: go get your archive on instagram in JSON format
- Step 2: put your own liked_posts.json in this folder
- Step 3: run `.\dl.ps1` in powershell (Windows)

Notes:

- Videos are downloaded in separaed folders (grouped per year: /2026, /2025, /2024...)
- the script stops when a rate limit is exceeded (~100 videos), wait 24-48h to restart it
- the script skips videos already downloaded
- thanks to yt-dlp.exe (included in this repo)