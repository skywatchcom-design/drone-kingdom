class_name TutorialSteps
extends RefCounted
## The steps of Noa's tutorial (see Tutorial), apart from the overlay so the save can use them
## without loading any UI. A step's targets are tried in order, most advanced first; "done" is
## the GameState.tutorial_event that ends it (none: a tap), and "free" leaves the screen open.

const STEPS := [
	{"key": "intro", "face": "smile"},
	{"key": "coins", "face": "smile", "done": "collect_coins", "targets": ["coin_generator"]},
	{"key": "fuel", "face": "wink", "done": "collect_fuel", "targets": ["coin_pump"]},
	{"key": "build", "face": "serious", "done": "place_mg", "targets": ["buy_mg", "shop_button"]},
	{"key": "place", "face": "smile", "done": "built_mg", "targets": ["free_pad"]},
	{"key": "speed", "face": "wink", "done": "speed_up", "targets": ["action_clock", "cell_mg"]},
	{"key": "train", "face": "smile", "done": "train", "targets": ["train_infantry", "action_train", "cell_camp"]},
	{"key": "attack", "face": "serious", "done": "raid_start", "targets": ["brief_attack", "mission_1", "attack_syndicate", "attack_button"]},
	{"key": "deploy", "face": "smile", "done": "deploy", "free": true, "targets": ["deploy_ground"]},
	# A lost first battle points at Retry instead, with its own line.
	{"key": "win", "face": "smile", "done": "home", "targets": ["result_retry", "result_home", "map_back"],
		"alt": {"result_retry": {"line": "retry", "face": "serious"}}},
	{"key": "upgrade", "face": "smile", "done": "upgrade_hq", "targets": ["upgrade_go", "action_up", "cell_hq"]},
	{"key": "bye", "face": "wink"},
]
## What Noa says in each step (English keys; Hebrew in I18n). Voice files are
## res://assets/audio/noa/<lang>_<key>.ogg.
const LINES := {
	"intro": "Hi, Commander! I'm Noa, your operations officer. Welcome to your new base!",
	"coins": "A base runs on coins. Tap the Solar Generator to collect them.",
	"fuel": "Now fuel. The pump has been busy. Tap it to collect.",
	"build": "Every base needs guards. Open the Shop and build an MG Nest.",
	"place": "Pick a free pad. The blinking one.",
	"speed": "Building takes time... but this one's on me! Tap to finish now.",
	"train": "An army doesn't train itself. Open the Training Camp and train an Infantry Squad.",
	"attack": "We've got trouble. Razor's Iron Fang gang is stealing coins around here. Time to take them back! Tap Attack.",
	"deploy": "Tap the ground to send in your troops. Just not right next to buildings.",
	"win": "Victory! The loot is on its way home. Razor won't like this.",
	"upgrade": "Now upgrade your Command Tower. A taller tower unlocks new buildings.",
	"bye": "The base is in good hands. I'm on the radio if you need me. Noa out!",
	"retry": "Almost! Razor got lucky this time. Tap Retry and send in all your troops.",
}
## Gems Noa hands out at the end (not when skipped or replayed).
const GIFT_GEMS := 100
