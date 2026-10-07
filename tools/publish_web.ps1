# Builds the web version and publishes it to GitHub Pages
# (https://skywatchcom-design.github.io/drone-kingdom/). Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
Set-Location $root
New-Item -ItemType Directory -Force build\web | Out-Null
# Keep Godot from importing its own output.
if (-not (Test-Path build\.gdignore)) { New-Item -ItemType File build\.gdignore | Out-Null }
& $godot --headless --path . --export-release "Web" build\web\index.html
$pages = "$env:TEMP\skywatch-pages"
if (Test-Path $pages) { Remove-Item -Recurse -Force $pages }
New-Item -ItemType Directory -Force $pages | Out-Null
Copy-Item build\web\* $pages
# The terms of use and privacy policy the sign-up window links to.
Copy-Item -Recurse web\legal "$pages\legal"
New-Item -ItemType File "$pages\.nojekyll" | Out-Null
Set-Location $pages
git init -q -b gh-pages
git add -A
git commit -q -m "Web build"
git remote add origin https://github.com/skywatchcom-design/drone-kingdom.git
git push -f origin gh-pages
Set-Location $root
Write-Host "Published. Open https://skywatchcom-design.github.io/drone-kingdom/ in a minute or two."
