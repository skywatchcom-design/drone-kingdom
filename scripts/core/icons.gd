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
	"star": '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24"><path d="M12 2l3 7 7 .6-5.4 4.7 1.7 7.2L12 17.8 5.7 21.5l1.7-7.2L2 9.6 9 9z" fill="#f2b41f" stroke="#7a4a00" stroke-width="1.2"/></svg>',
}

static var _cache := {}


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
