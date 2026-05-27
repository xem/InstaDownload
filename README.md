InstaDownloader
==

- Step 1: go get your archive on instagram in JSON format
- Step 2: put your own liked_posts.json in this folder
- Step 3: put your own Instagram cookies.txt in this folder (dowloadable via the "cookie txt" browser extension)
- Step 4: run `.\dl.ps1` in powershell (Windows)

Notes:

- Videos are downloaded in separaed folders (grouped per year: /2026, /2025, /2024...)
- the script stops when a rate limit is exceeded (~100 videos), wait 24-48h to restart it
- the script skips videos already downloaded (0kb placeholder file)
- thanks to yt-dlp.exe (included in this repo)
- run `.\cleanup.ps1` to remove all the videos already downloaded from your json file