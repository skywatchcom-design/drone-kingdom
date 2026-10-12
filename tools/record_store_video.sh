#!/bin/bash
# Records the raw 1080p footage for the store video into tmp/vid/<shot>/f.avi (dev build only).
# MJPEG .avi is about 8x faster to write than PNG frames. A temporary override.cfg makes the
# window 1920x1080 (the project's window override is smaller than a 1080p screen allows).
# Then: python tools/make_promo_music.py && python tools/make_store_video.py
cd "$(dirname "$0")/.."
G="$LOCALAPPDATA/Microsoft/WinGet/Packages/GodotEngine.GodotEngine_Microsoft.Winget.Source_8wekyb3d8bbwe/Godot_v4.7.2-stable_win64_console.exe"
printf '[display]\n\nwindow/size/window_width_override=1920\nwindow/size/window_height_override=1080\n\n[editor]\n\nmovie_writer/mjpeg_quality=0.95\n' > override.cfg
trap 'rm -f override.cfg' EXIT
rec() {  # rec NAME FRAMES SCENE -- args...
	local name=$1 frames=$2 scene=$3; shift 3
	rm -rf "tmp/vid/$name"; mkdir -p "tmp/vid/$name"
	"$G" --path . --write-movie "tmp/vid/$name/f.avi" --fixed-fps 30 --quit-after "$frames" "$scene" "$@" > "tmp/vid/$name.log" 2>&1
	echo "$name done"
}
ARMY="--army infantry:4,engineers:1,armor:2,courier:3,scout:2,heavy:2"
A="--fresh --showcase 4 --lang en --autoplay --enemy 20 --enemy-hq 5 $ARMY"
rec f_follow 840 res://scenes/raid/raid.tscn -- $A --no-hud --follow 30
rec f_raidhud 540 res://scenes/raid/raid.tscn -- $A
rec f_home 150 res://scenes/home/home.tscn -- --fresh --showcase 4 --lang en --screenshot-base --cinema 1.1,0.95,5
rec f_upgrade 90 res://scenes/home/home.tscn -- --fresh --showcase 4 --lang en --screenshot-upgrade
rec f_fang 450 res://scenes/raid/raid.tscn -- --fresh --showcase 4 --lang en --autoplay --syndicate 9 $ARMY --no-hud --follow 32
