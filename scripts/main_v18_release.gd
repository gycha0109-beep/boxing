extends "res://scripts/main_v18.gd"

# Final release authority for the approved v18 commercial shell. Keep visual
# composition in main_v18.gd; this wrapper only enforces release ergonomics.
func _v17_top_bar() -> Control:
    var bar := super._v17_top_bar()
    _v18_release_touch_targets(bar)
    return bar

func _v18_release_touch_targets(node: Node) -> void:
    if node is Button:
        var button := node as Button
        button.custom_minimum_size = Vector2(
            maxf(button.custom_minimum_size.x, 56.0),
            maxf(button.custom_minimum_size.y, 56.0)
        )
    for child in node.get_children():
        _v18_release_touch_targets(child)
