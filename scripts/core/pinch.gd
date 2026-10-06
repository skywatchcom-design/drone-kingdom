class_name Pinch
extends RefCounted
## Two-finger pinch zoom for touch screens (and the trackpad magnify gesture). Feed it every
## input event; it returns the zoom factor for that event (above 1 means zoom in).
## While `gesture` is true (from the second finger until a new single touch starts) the caller
## should not pan or treat a release as a tap.

var gesture := false
var _points := {}


func handle(event: InputEvent) -> float:
	if event is InputEventMagnifyGesture:
		return (event as InputEventMagnifyGesture).factor
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _points.is_empty():
				gesture = false
			_points[t.index] = t.position
			if _points.size() >= 2:
				gesture = true
		else:
			_points.erase(t.index)
		return 1.0
	if event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if not _points.has(d.index):
			return 1.0
		if _points.size() < 2:
			_points[d.index] = d.position
			return 1.0
		var keys := _points.keys()
		var before := (_points[keys[0]] as Vector2).distance_to(_points[keys[1]])
		_points[d.index] = d.position
		var after := (_points[keys[0]] as Vector2).distance_to(_points[keys[1]])
		if before > 1.0:
			return after / before
	return 1.0
