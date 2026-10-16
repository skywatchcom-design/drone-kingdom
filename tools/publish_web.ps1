# Builds the web version and publishes it to GitHub Pages
# (https://skywatchcom-design.github.io/drone-kingdom/). Run from the project folder:
#   powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1                    # the real site (main only)
#   powershell -ExecutionPolicy Bypass -File tools\publish_web.ps1 -Preview engineer  # a preview for the owner
# A preview lands at /preview/<name>/ next to the real site and leaves it untouched, so the owner
# can try a change on the iPad before approving it into main. Publishing the real site keeps the
# previews that are already there.
param([string]$Preview = "")
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
$repo = "https://github.com/skywatchcom-design/drone-kingdom.git"
$site = "https://skywatchcom-design.github.io/drone-kingdom/"
if ($Preview -ne "" -and $Preview -notmatch '^[a-z0-9-]+$') { throw "Preview name: lowercase letters, digits and dashes only." }
Set-Location $root
New-Item -ItemType Directory -Force build\web | Out-Null
# Keep Godot from importing its own output.
if (-not (Test-Path build\.gdignore)) { New-Item -ItemType File build\.gdignore | Out-Null }
& $godot --headless --path . --export-release "Web" build\web\index.html

# Every build gets its own file addresses, so browsers never run a cached older game.
function Stamp-Html($dir) {
    $stamp = Get-Date -Format "yyyyMMddHHmmss"
    $html = Get-Content "$dir\index.html" -Raw
    $html = $html.Replace('"executable":"index"', '"executable":"index","mainPack":"index.pck?v=' + $stamp + '"')
    $html = $html.Replace('<script src="index.js">', '<script src="index.js?v=' + $stamp + '">')
    Set-Content "$dir\index.html" $html -Encoding utf8 -NoNewline
    # The game compares this with its own stamp and offers a refresh when a newer build is up.
    Set-Content "$dir\version.json" ('{"v":"' + $stamp + '"}') -Encoding ascii -NoNewline
}

$pages = "$env:TEMP\skywatch-pages"
if (Test-Path $pages) { Remove-Item -Recurse -Force $pages }

if ($Preview -ne "") {
    # Add or replace one folder on the live gh-pages branch; everything else stays as it is.
    git clone -q --depth 1 --branch gh-pages $repo $pages
    $dest = "$pages\preview\$Preview"
    if (Test-Path $dest) { Remove-Item -Recurse -Force $dest }
    New-Item -ItemType Directory -Force $dest | Out-Null
    Copy-Item build\web\* $dest
    Stamp-Html $dest
    Set-Location $pages
    git add -A
    git commit -q -m "Preview $Preview"
    git push -q origin gh-pages
    Set-Location $root
    Write-Host "Preview published. Open ${site}preview/$Preview/ in a minute or two."
    return
}

New-Item -ItemType Directory -Force $pages | Out-Null
Copy-Item build\web\* $pages
Stamp-Html $pages
# The terms of use and privacy policy the sign-up window links to.
Copy-Item -Recurse web\legal "$pages\legal"
# The page the password-reset email links to (and the account deletion page).
Copy-Item -Recurse web\account "$pages\account"
# Pictures the account emails show.
Copy-Item -Recurse web\email "$pages\email"
# Keep the owner's open previews.
$old = "$env:TEMP\skywatch-pages-old"
if (Test-Path $old) { Remove-Item -Recurse -Force $old }
git clone -q --depth 1 --branch gh-pages $repo $old
if (Test-Path "$old\preview") { Copy-Item -Recurse "$old\preview" "$pages\preview" }
New-Item -ItemType File "$pages\.nojekyll" | Out-Null
Set-Location $pages
git init -q -b gh-pages
git add -A
git commit -q -m "Web build"
git remote add origin $repo
git push -f origin gh-pages
Set-Location $root
Write-Host "Published. Open $site in a minute or two."
