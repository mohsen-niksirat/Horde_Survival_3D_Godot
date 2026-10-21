extends RefCounted
class_name SafeArea
## Static helpers for Android safe-area (notch / punch-hole / rounded corner)
## insets. DisplayServer.get_display_safe_area() returns the usable area in
## *screen* pixels; the viewport may be scaled, so every value is converted
## back into viewport coordinates before it is applied to a Control.

## The safe-area rect in viewport coordinates.
##
## `screen_rect` is the full screen size in screen pixels and
## `safe_rect` the inset area reported by the platform. The conversion uses
## the viewport's own size so stretched/letterboxed views stay correct.
static func viewport_safe_rect(vp_size: Vector2, screen_size: Vector2, safe_rect: Rect2) -> Rect2:
	if screen_size.x <= 0.0 or screen_size.y <= 0.0 or vp_size.x <= 0.0 or vp_size.y <= 0.0:
		return Rect2(Vector2.ZERO, vp_size)
	if safe_rect.size.x <= 0.0 or safe_rect.size.y <= 0.0:
		return Rect2(Vector2.ZERO, vp_size)
	# The window may not cover the whole screen (letterboxed / scaled down),
	# so the screen rect is mapped onto the viewport by ratio, not 1:1.
	var scale := Vector2(vp_size.x / screen_size.x, vp_size.y / screen_size.y)
	var pos := Vector2(safe_rect.position.x * scale.x, safe_rect.position.y * scale.y)
	var size := Vector2(safe_rect.size.x * scale.x, safe_rect.size.y * scale.y)
	# Clamp: a platform quirk must never push content fully off-screen.
	pos = pos.clamp(Vector2.ZERO, vp_size)
	size = size.clamp(Vector2.ZERO, vp_size - pos)
	return Rect2(pos, size)

## Padding (left, top, right, bottom) that keeps a Control clear of the
## display cutout. Returns zeroes on platforms without a safe area.
static func insets_for(control: Control) -> Vector4:
	# Only mobile platforms have cutouts. Desktop and web report the whole
	# screen, but a browser window that is smaller than the screen would
	# produce bogus insets, so skip them entirely.
	if not is_mobile():
		return Vector4.ZERO
	if control == null or not control.is_inside_tree():
		return Vector4.ZERO
	var screen_size := Vector2(DisplayServer.screen_get_size())
	if screen_size.x <= 0.0 or screen_size.y <= 0.0:
		return Vector4.ZERO
	var safe := DisplayServer.get_display_safe_area()
	var vp_size := control.get_viewport_rect().size
	var rect := viewport_safe_rect(vp_size, screen_size, safe)
	var left := maxf(rect.position.x, 0.0)
	var top := maxf(rect.position.y, 0.0)
	var right := maxf(vp_size.x - (rect.position.x + rect.size.x), 0.0)
	var bottom := maxf(vp_size.y - (rect.position.y + rect.size.y), 0.0)
	return Vector4(left, top, right, bottom)

## True on platforms that can have a display cutout.
static func is_mobile() -> bool:
	return OS.get_name() == "Android" or OS.get_name() == "iOS" or OS.has_feature("mobile")

## Apply the current safe-area insets as content margins on a Control.
## Safe to call on every resize — it is idempotent.
static func apply_to(control: Control) -> void:
	if control == null or not control.is_inside_tree():
		return
	var pads := insets_for(control)
	control.offset_left = pads.x
	control.offset_top = pads.y
	control.offset_right = -pads.z
	control.offset_bottom = -pads.w
