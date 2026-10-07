class_name Store
extends RefCounted
## The gem shop (approved sketch WqAsDumRoAXDrToDiHBMDn, layout A "everything in one scroll"):
## a one-time starter pack, five gem packs, cosmetics bought with gems, and free gems. No random
## boxes; players under 13 pass a parent gate before anything that costs real money. Real
## payments arrive with the App Store and Google Play accounts; until then the buttons say so.

## Gem packs: gems, the price shown in Hebrew (₪) and English ($), and a ribbon key.
const PACKS := [
	{"id": "gems_80", "name": "Handful", "gems": 80, "ils": "₪4.90", "usd": "$0.99", "ribbon": ""},
	{"id": "gems_500", "name": "Pouch", "gems": 500, "ils": "₪19.90", "usd": "$4.99", "ribbon": "Popular"},
	{"id": "gems_1200", "name": "Crate", "gems": 1200, "ils": "₪39.90", "usd": "$9.99", "ribbon": ""},
	{"id": "gems_2500", "name": "Vault", "gems": 2500, "ils": "₪79.90", "usd": "$19.99", "ribbon": "Best value"},
	{"id": "gems_6500", "name": "Treasure", "gems": 6500, "ils": "₪179.90", "usd": "$49.99", "ribbon": ""},
]

## Bought once: resources plus the gold flag, at a fraction of its worth.
const STARTER := {"id": "starter", "gems": 400, "coins": 2000, "fuel": 1000, "cosmetic": "flag_gold",
	"ils": "₪9.90", "usd": "$2.99", "was_ils": "₪69.90", "was_usd": "$14.99"}

## Cosmetics change only how something looks. "slot" is what they dress (one equipped per slot);
## gems 0 means it cannot be bought on its own (it comes in a pack).
const COSMETICS := {
	"hq_desert": {"slot": "hq", "name": "Desert Tower", "gems": 500},
	"hq_night": {"slot": "hq", "name": "Night Tower", "gems": 800},
	"hq_snow": {"slot": "hq", "name": "Snow Tower", "gems": 650},
	"flag_gold": {"slot": "flag", "name": "Gold Flag", "gems": 0},
}
const COSMETIC_ORDER := ["hq_desert", "hq_night", "hq_snow", "flag_gold"]

## Short videos for free gems (players 13 and up, once an ad network is in).
const VIDEO_GEMS := 10
const VIDEOS_PER_DAY := 3


static func price(item: Dictionary, was: bool = false) -> String:
	if was:
		return item["was_ils"] if I18n.rtl() else item["was_usd"]
	return item["ils"] if I18n.rtl() else item["usd"]


## Where the baked picture of a cosmetic lives (see bake_pictures.gd).
static func picture_path(id: String) -> String:
	return "res://assets/textures/pictures/skin_%s.webp" % id


## The parent gate question: a number written in words, typed back in digits.
const GATE := [
	["twenty-seven", "עשרים ושבע", 27], ["thirty-four", "שלושים וארבע", 34], ["forty-eight", "ארבעים ושמונה", 48],
	["fifty-six", "חמישים ושש", 56], ["sixty-nine", "שישים ותשע", 69], ["seventy-three", "שבעים ושלוש", 73],
]
