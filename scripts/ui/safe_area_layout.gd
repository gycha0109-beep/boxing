class_name SafeAreaLayout
extends RefCounted

static func zero_insets() -> Dictionary:
    return {"left": 0.0, "top": 0.0, "right": 0.0, "bottom": 0.0}

static func compute_insets(viewport_size: Vector2, display_size: Vector2, safe_rect: Rect2i) -> Dictionary:
    if viewport_size.x <= 0.0 or viewport_size.y <= 0.0 or display_size.x <= 0.0 or display_size.y <= 0.0:
        return zero_insets()
    var scale_x: float = viewport_size.x / display_size.x
    var scale_y: float = viewport_size.y / display_size.y
    var left_px: float = max(0.0, float(safe_rect.position.x))
    var top_px: float = max(0.0, float(safe_rect.position.y))
    var right_px: float = max(0.0, display_size.x - float(safe_rect.position.x + safe_rect.size.x))
    var bottom_px: float = max(0.0, display_size.y - float(safe_rect.position.y + safe_rect.size.y))
    return {
        "left": left_px * scale_x,
        "top": top_px * scale_y,
        "right": right_px * scale_x,
        "bottom": bottom_px * scale_y,
    }

static func current_insets(viewport_size: Vector2) -> Dictionary:
    if not OS.has_feature("mobile"):
        return zero_insets()
    var display_size_i: Vector2i = DisplayServer.screen_get_size()
    var safe_rect: Rect2i = DisplayServer.get_display_safe_area()
    return compute_insets(viewport_size, Vector2(display_size_i), safe_rect)
