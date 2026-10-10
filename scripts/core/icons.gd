class_name Icons
extends RefCounted
## Small UI icons drawn from SVG at runtime (the same shapes as the approved base-screen
## sketch 4WKjsEP2MoNrBQh5iGnwTF), cached per name and size.

const SVG := {
	"coin": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#f5c542" stroke="#8a5d00" stroke-width="2"/><circle cx="12" cy="12" r="5.5" fill="none" stroke="#c8901a" stroke-width="2"/></svg>',
	"fuel": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2C9 7 5 10 5 15a7 7 0 0014 0c0-5-4-8-7-13z" fill="#ec5a8c" stroke="#7a1f42" stroke-width="2"/></svg>',
	"gem": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M6 3h12l4 6-10 13L2 9z" fill="#4fdc93" stroke="#0d5c35" stroke-width="2"/><path d="M2 9h20M8 3l4 19M16 3l-4 19" stroke="#0d5c35" stroke-width="1"/></svg>',
	"swords": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M3 3l10 10M21 3L11 13M6 15l-3 3 3 3 3-3M18 15l3 3-3 3-3-3" stroke="#ffffff" stroke-width="2.4" stroke-linecap="round" fill="none"/></svg>',
	"cart": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M3 4h3l3 11h10l2-8H8" fill="none" stroke="#ffffff" stroke-width="2.4" stroke-linejoin="round"/><circle cx="10" cy="19" r="2" fill="#ffffff"/><circle cx="17" cy="19" r="2" fill="#ffffff"/></svg>',
	"gear": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="3.5" fill="none" stroke="#ffffff" stroke-width="2.2"/><path d="M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9l2.1 2.1M17 17l2.1 2.1M4.9 19.1L7 17M17 7l2.1-2.1" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round"/></svg>',
	"army": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="7" r="4" fill="#ffffff"/><path d="M4 21c0-5 4-8 8-8s8 3 8 8z" fill="#ffffff"/></svg>',
	"info": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#2f6fe0" stroke="#ffffff" stroke-width="1.5"/><path d="M12 10v7" stroke="#ffffff" stroke-width="2.6" stroke-linecap="round"/><circle cx="12" cy="7" r="1.6" fill="#ffffff"/></svg>',
	"up": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 3l8 9h-5v9H9v-9H4z" fill="#5fae3b" stroke="#24521a" stroke-width="1.6" stroke-linejoin="round"/></svg>',
	"train": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="8" cy="8" r="3" fill="#5d6640"/><circle cx="16" cy="8" r="3" fill="#5d6640"/><path d="M2 20c0-4 3-6 6-6s6 2 6 6zM10 20c0-4 3-6 6-6s6 2 6 6z" fill="#5d6640"/></svg>',
	"heart": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 21C5 15 2 12 2 8a5 5 0 0110-1 5 5 0 0110 1c0 4-3 7-10 13z" fill="#e8483c" stroke="#7a1a12" stroke-width="1.6"/></svg>',
	"boom": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2l2 6 6-3-3 6 6 2-6 2 3 6-6-3-2 6-2-6-6 3 3-6-6-2 6-2-3-6 6 3z" fill="#f2b41f" stroke="#7a4a00" stroke-width="1.2"/></svg>',
	"range": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="9" fill="none" stroke="#2f6fe0" stroke-width="2.2" stroke-dasharray="3 2"/><circle cx="12" cy="12" r="2.5" fill="#2f6fe0"/></svg>',
	"clock": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="10" fill="#ffffff" stroke="#555555" stroke-width="2"/><path d="M12 6v6l4 3" stroke="#333333" stroke-width="2.2" stroke-linecap="round" fill="none"/></svg>',
	"worker": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M5 11a7 7 0 0114 0z" fill="#f2b41f" stroke="#7a4a00" stroke-width="1.5"/><rect x="4" y="11" width="16" height="2" fill="#7a4a00"/><circle cx="12" cy="16" r="4" fill="#c99a74"/></svg>',
	"box": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M3 8l9-5 9 5v8l-9 5-9-5z" fill="#c8a25a" stroke="#5a3a10" stroke-width="1.5"/><path d="M3 8l9 5 9-5M12 13v8" stroke="#5a3a10" stroke-width="1.5" fill="none"/></svg>',
	"plane": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2l2 7 8 4v2l-8-2-1 6 3 2v1l-4-1-4 1v-1l3-2-1-6-8 2v-2l8-4z" fill="#8d969e" stroke="#2a2e33" stroke-width="1.2"/></svg>',
	"drone": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="5" cy="5" r="3.5" fill="none" stroke="#2a2e33" stroke-width="1.6"/><circle cx="19" cy="5" r="3.5" fill="none" stroke="#2a2e33" stroke-width="1.6"/><circle cx="5" cy="19" r="3.5" fill="none" stroke="#2a2e33" stroke-width="1.6"/><circle cx="19" cy="19" r="3.5" fill="none" stroke="#2a2e33" stroke-width="1.6"/><path d="M7 7l10 10M17 7L7 17" stroke="#2a2e33" stroke-width="2"/><rect x="9" y="9" width="6" height="6" rx="1" fill="#eef0f2" stroke="#2a2e33" stroke-width="1.4"/></svg>',
	"bolt": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M13 2L4 14h7l-1 8 9-12h-7z" fill="#f2b41f" stroke="#7a4a00" stroke-width="1.2"/></svg>',
	"lock": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="5" y="10" width="14" height="11" rx="2" fill="#e8e2d0" stroke="#3a3830" stroke-width="1.5"/><path d="M8 10V7a4 4 0 018 0v3" stroke="#e8e2d0" stroke-width="2.6" fill="none"/></svg>',
	"syndicate": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 40 40"><path d="M20 2l16 9v18l-16 9-16-9V11z" fill="#2b2d33" stroke="#c08bff" stroke-width="2.5"/><path d="M12 13c4 0 6 3 6 6s-2 6-6 6M28 13c-4 0-6 3-6 6s2 6 6 6" fill="none" stroke="#f2c12e" stroke-width="3" stroke-linecap="round"/><circle cx="20" cy="19" r="2.5" fill="#8a3cff"/></svg>',
	"razor": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 200 200"><rect width="200" height="200" rx="18" fill="#2a2238"/><path d="M20 200l10-55 40-20h60l40 20 10 55z" fill="#2b2d33"/><path d="M30 150l-14-20 30 8zM170 150l14-20-30 8z" fill="#5a5c64"/><path d="M60 130l40 18 40-18" stroke="#8a3cff" stroke-width="5" fill="none"/><path d="M58 70c0-36 84-36 84 0v40c0 18-18 32-42 32s-42-14-42-32z" fill="#b98a6a"/><path d="M58 76c0-40 84-40 84 0-10-8-26-12-42-12s-32 4-42 12z" fill="#1d1e22"/><path d="M92 18l8-16 8 16v40h-16z" fill="#e5533c"/><path d="M70 92l18 4M112 96l18-4" stroke="#1d1e22" stroke-width="6" stroke-linecap="round"/><circle cx="80" cy="102" r="5" fill="#1d1e22"/><circle cx="121" cy="102" r="11" fill="#2b2d33" stroke="#5a5c64" stroke-width="3"/><circle cx="121" cy="102" r="6" fill="#ff2a2a"/><path d="M66 82l14 34" stroke="#7a3b2a" stroke-width="3"/><path d="M72 124h56v14c0 8-12 12-28 12s-28-4-28-12z" fill="#8d969e"/><path d="M80 128v12M90 128v14M100 128v14M110 128v14M120 128v12" stroke="#4a4d55" stroke-width="2.5"/></svg>',
	"tasks": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><rect x="4" y="3" width="16" height="19" rx="2.5" fill="none" stroke="#ffffff" stroke-width="2.2"/><rect x="8.5" y="1.5" width="7" height="4" rx="1.2" fill="#ffffff"/><path d="M8 11l2 2 4-4M8 17h8" stroke="#ffffff" stroke-width="2.2" stroke-linecap="round" stroke-linejoin="round" fill="none"/></svg>',
	"brush": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M14 3l7 7-8 8-7-7z" fill="#e9a21f" stroke="#7a4a00" stroke-width="1.5" stroke-linejoin="round"/><path d="M6 11l-3 3c-1 1-1 3 0 4l1 1c1 1 3 1 4 0l3-3" fill="#5fae3b" stroke="#24521a" stroke-width="1.5"/><path d="M9 7l8 8" stroke="#7a4a00" stroke-width="1.2"/></svg>',
	"star": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2l3 7 7 .6-5.4 4.7 1.7 7.2L12 17.8 5.7 21.5l1.7-7.2L2 9.6 9 9z" fill="#f2b41f" stroke="#7a4a00" stroke-width="1.2"/></svg>',
	"move": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2l3.5 4h-2.5v4h4V7.5L21 11l-4 3.5V12h-4v4h2.5L12 20l-3.5-4H11v-4H7v2.5L3 11l4-3.5V10h4V6H8.5z" fill="#2f6fe0" stroke="#ffffff" stroke-width="1.2" stroke-linejoin="round"/></svg>',
	# What a unit goes for first (approved sketch FXGoTcv7xRzZbR5GDqE6S3): a badge in the
	# target's color with a white sign.
	"t_any": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#5b6670" stroke="#ffffff" stroke-width="1.6"/><circle cx="12" cy="12" r="5" fill="none" stroke="#ffffff" stroke-width="2"/><path d="M12 4v4M12 16v4M4 12h4M16 12h4" stroke="#ffffff" stroke-width="2"/></svg>',
	"t_loot": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#c98a00" stroke="#ffffff" stroke-width="1.6"/><circle cx="12" cy="12" r="6" fill="#ffd34d" stroke="#ffffff" stroke-width="1.6"/><circle cx="12" cy="12" r="2.5" fill="none" stroke="#c98a00" stroke-width="1.4"/></svg>',
	"t_defense": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#c0392b" stroke="#ffffff" stroke-width="1.6"/><path d="M12 5l6 2.2v4.6c0 3.6-2.8 5.8-6 7.2-3.2-1.4-6-3.6-6-7.2V7.2z" fill="#ffffff"/></svg>',
	"t_hq": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#2f6fe0" stroke="#ffffff" stroke-width="1.6"/><path d="M12 4l2.4 5 5.4.6-4 3.7 1.1 5.4L12 16l-4.9 2.7 1.1-5.4-4-3.7 5.4-.6z" fill="#ffffff"/></svg>',
	"t_fence": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><circle cx="12" cy="12" r="11" fill="#a0642a" stroke="#ffffff" stroke-width="1.6"/><path d="M5 8h6v3.5H5zM13 8h6v3.5h-6zM8 13h8v3.5H8z" fill="#ffffff"/></svg>',
}

## Colors of the target badges, for lines and rings drawn in the world.
const TARGET_COLORS := {"any": Color(0.6, 0.66, 0.72), "loot": Color(1.0, 0.75, 0.15),
	"defense": Color(0.95, 0.3, 0.25), "fence": Color(0.85, 0.55, 0.25), "hq": Color(0.3, 0.6, 0.95)}

static var _cache := {}


## The badge icon for what unit `type` attacks first.
## An attack plan order other than "auto" replaces the unit's own habit.
static func target(type: String, order: String = "auto") -> String:
	var own := str(Catalog.unit_def(type).get("prefers", "any"))
	return "t_" + (own if order == "auto" or own == "fence" else order)


## The icon `name` as a texture `size` pixels square.
static func tex(name: String, size: int = 48) -> Texture2D:
	var key := "%s@%d" % [name, size]
	if _cache.has(key):
		return _cache[key]
	var image := Image.new()
	image.load_svg_from_string(SVG.get(name, SVG["info"]), size / 24.0)
	var t := ImageTexture.create_from_image(image)
	_cache[key] = t
	return t


## A TextureRect showing the icon, sized and centered, for use inside containers.
static func rect(name: String, size: int) -> TextureRect:
	var r := TextureRect.new()
	r.texture = tex(name, size * 2)
	r.custom_minimum_size = Vector2(size, size)
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r
