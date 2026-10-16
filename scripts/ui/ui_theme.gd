class_name UiTheme
extends RefCounted
## Base Wars design system (owner, 16.10.2026: HUD direction A "military clean", sketch
## H2WYiqcnCPrV8Wo1yEMSiE, and the UI plan sketch SQhYwaeWJpKTv5HjygjboU). One place for the colors,
## corners and text sizes every screen uses: dark olive plates with a thin sand line, almost
## square corners, a deep red-brown for attacking, olive for the main action, muted resource
## colors, light text. On while the military palette is on (MeshKit.palette == "mil").

const PLATE := Color(0.086, 0.1, 0.07, 0.86)
const SHEET := Color(0.086, 0.1, 0.07, 0.98)
const CARD := Color(0.13, 0.15, 0.11)
const CARD_2 := Color(0.18, 0.2, 0.15)
const SAND_LINE := Color(0.85, 0.77, 0.54, 0.45)
const SAND := Color(0.91, 0.85, 0.66)
const OLIVE := Color(0.24, 0.29, 0.17)
const ATTACK_RED := Color(0.43, 0.165, 0.12)
const TEXT := Color(0.94, 0.92, 0.86)
const TEXT_DIM := Color(0.73, 0.71, 0.62)
const OK := Color(0.5, 0.69, 0.41)
const COIN := Color(0.79, 0.64, 0.15)
const FUEL := Color(0.66, 0.28, 0.25)
const GEM := Color(0.25, 0.62, 0.48)
const RADIUS := 6
## Text sizes on the 720 px wide portrait screen.
const TITLE := 34
const SUBTITLE := 26
const BODY := 22
const NOTE := 16


static func on() -> bool:
	return MeshKit.palette == "mil"


static func box(color: Color, radius: int = RADIUS, border: Color = Color(0, 0, 0, 0), width: int = 1) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.border_color = border
	s.set_border_width_all(width if border.a > 0.0 else 0)
	s.set_content_margin_all(6)
	return s


static func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b


## The windows were drawn on light parchment with dark ink. In the military look they sit on a
## dark sheet, so this walks a finished window once and turns it dark: dark text becomes light,
## light cards and plates become dark olive ones with a sand line, corners get almost square.
## Colored accents (green buttons, resource colors, level colors) keep their hue.
static func darken_tree(root: Node) -> void:
	if not on():
		return
	for n in [root] + root.find_children("*", "Control", true, false):
		var c := n as Control
		if c == null:
			continue
		for key in ["font_color", "default_color"]:
			if c.has_theme_color_override(key):
				var col := c.get_theme_color(key)
				if _lum(col) < 0.45 and col.a > 0.3:
					c.add_theme_color_override(key, TEXT if _lum(col) < 0.3 else TEXT_DIM)
		if c is Label and not c.has_theme_color_override("font_color"):
			c.add_theme_color_override("font_color", TEXT)
		for name in ["panel", "normal", "hover", "pressed", "disabled", "background", "focus"]:
			if not c.has_theme_stylebox_override(name):
				continue
			var sb := c.get_theme_stylebox(name)
			if not (sb is StyleBoxFlat):
				continue
			var f := (sb as StyleBoxFlat).duplicate() as StyleBoxFlat
			var l := _lum(f.bg_color)
			if l > 0.72 and f.bg_color.s < 0.35:
				f.bg_color = Color(CARD, f.bg_color.a) if name != "hover" else Color(CARD_2, f.bg_color.a)
				if f.border_width_top > 0 or f.border_width_left > 0:
					f.border_color = SAND_LINE
			elif l > 0.55 and f.bg_color.s < 0.3:
				f.bg_color = Color(CARD_2, f.bg_color.a)
			elif f.bg_color.s > 0.4 and f.bg_color.h > 0.2 and f.bg_color.h < 0.42:
				# Bright game greens (buy buttons, the money strip, the picked tab) turn olive.
				f.bg_color = Color(OLIVE.lightened(0.12) if name == "hover" else OLIVE, f.bg_color.a)
			if f.border_color.a > 0.0 and _lum(f.border_color) < 0.35:
				f.border_color = SAND_LINE
			for corner in ["corner_radius_top_left", "corner_radius_top_right", "corner_radius_bottom_left", "corner_radius_bottom_right"]:
				f.set(corner, mini(int(f.get(corner)), RADIUS))
			c.add_theme_stylebox_override(name, f)
