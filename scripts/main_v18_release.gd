extends "res://scripts/main_v18.gd"

# Final release authority for the approved v18 commercial shell. Keep visual
# composition in main_v18.gd; this wrapper only enforces release ergonomics
# and pins the shell to validated binary image resources.
const V18_HERO_TEXTURE: Texture2D = preload("res://assets/visual/v18/hero_player.jpg")
const V18_TRAINING_TEXTURE: Texture2D = preload("res://assets/visual/v18/training_atlas.jpg")
const V18_OPPONENT_TEXTURE: Texture2D = preload("res://assets/visual/v18/opponent_atlas.jpg")
const V18_RING_TEXTURE: Texture2D = preload("res://assets/visual/v18/fight_ring_scene.jpg")

func _v18_photo(key: String) -> Texture2D:
    match key:
        "hero": return V18_HERO_TEXTURE
        "training": return V18_TRAINING_TEXTURE
        "opponents": return V18_OPPONENT_TEXTURE
        "ring": return V18_RING_TEXTURE
        _: return null

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
