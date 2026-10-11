# Builds a signed Android App Bundle for Google Play and puts it where the owner uploads it.
# Run from the project folder (or any worktree of it):
#   powershell -ExecutionPolicy Bypass -File tools\build_android.ps1            # next version code
#   powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -Name 0.2.0 # also a new version name
#   powershell -ExecutionPolicy Bypass -File tools\build_android.ps1 -NoBump     # rebuild the same code
# Google Play refuses a bundle whose version code it has seen before, so every upload bumps it.
# Commit the changed export_presets.cfg afterwards.
param([string]$Name = "", [switch]$NoBump)
$ErrorActionPreference = "Stop"
$root = Split-Path $PSScriptRoot -Parent
$godot = "$env:LOCALAPPDATA\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe\Godot_v4.7.2-stable_win64_console.exe"
Set-Location $root

# Secrets and the upload folder live in the main checkout, also when this runs in a worktree.
$main = Split-Path (Resolve-Path (git rev-parse --git-common-dir)) -Parent
$keystore = Join-Path $main "tmp\skywatch-release.keystore"
$passFile = Join-Path $main "tmp\android_keystore_password.txt"
if (-not (Test-Path $keystore) -or -not (Test-Path $passFile)) { throw "Missing $keystore or $passFile (the upload key). Do not make a new one: Play only accepts this key." }

# The gradle build template is git-ignored; a fresh worktree borrows the main checkout's copy.
if (-not (Test-Path "$root\android\build")) {
    if (Test-Path "$main\android\build") { Copy-Item -Recurse "$main\android" "$root\android" }
    else { throw "No android\build template. In the editor: Project > Install Android Build Template." }
}

# Bump version/code (and optionally version/name) in the Android preset.
$cfg = Get-Content export_presets.cfg -Raw
$m = [regex]::Match($cfg, 'version/code=(\d+)')
$code = [int]$m.Groups[1].Value
if (-not $NoBump) { $code += 1 }
$cfg = $cfg.Remove($m.Index, $m.Length).Insert($m.Index, "version/code=$code")
if ($Name -ne "") { $cfg = [regex]::Replace($cfg, 'version/name="[^"]*"', "version/name=`"$Name`"") }
$versionName = [regex]::Match($cfg, 'version/name="([^"]*)"').Groups[1].Value
[IO.File]::WriteAllText("$root\export_presets.cfg", $cfg)

# Without a lingering gradle daemon, Godot exits as soon as the export is done.
$env:GRADLE_OPTS = "-Dorg.gradle.daemon=false"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = "skywatch"
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = (Get-Content $passFile -Raw).Trim()
New-Item -ItemType Directory -Force build\android | Out-Null
if (-not (Test-Path build\.gdignore)) { New-Item -ItemType File build\.gdignore | Out-Null }
Remove-Item -Force build\android\skywatch.aab -ErrorAction SilentlyContinue
& $godot --headless --path . --export-release "Android" build\android\skywatch.aab
if (-not (Test-Path build\android\skywatch.aab)) { throw "Export failed (see the Godot output above)." }

$out = Join-Path $main "build\android_upload"
New-Item -ItemType Directory -Force $out | Out-Null
$file = Join-Path $out "skywatch-$versionName-v$code.aab"
Copy-Item -Force build\android\skywatch.aab $file
$mb = [math]::Round((Get-Item $file).Length / 1MB, 1)
if ($mb -gt 150) { Write-Warning "Bundle is $mb MB, over the 150 MB budget." }
Write-Host "Built $file ($mb MB), version $versionName code $code. Commit export_presets.cfg."
