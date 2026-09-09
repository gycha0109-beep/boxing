extends "res://scripts/main_v18.gd"

# Final release authority for the approved v18 commercial shell. Keep visual
# composition in main_v18.gd; this wrapper only enforces release ergonomics,
# pins the shell to validated binary image resources, and restores the compact
# five-stat/career context that must remain visible in camp.
const V18_HERO_TEXTURE: Texture2D = preload("res://assets/visual/v18/hero_player.webp")
const V18_TRAINING_TEXTURE: Texture2D = preload("res://assets/visual/v18/training_atlas.webp")
const V18_OPPONENT_TEXTURE: Texture2D = preload("res://assets/visual/v18/opponent_atlas.webp")
const V18_RING_TEXTURE: Texture2D = preload("res://assets/visual/v18/fight_ring_scene.webp")

func _v18_photo(key: String) -> Texture2D:
    match key:
        "hero": return V18_HERO_TEXTURE
        "training": return V18_TRAINING_TEXTURE
        "opponents": return V18_OPPONENT_TEXTURE
        "ring": return V18_RING_TEXTURE
        _: return null

func _render_camp() -> void:
    _v17_player_hero("훈련 캠프 선택", "땀은 배신하지 않는다.")

    var stats_panel := _v17_panel(body, false)
    _v17_eyebrow(stats_panel, "FIGHTER STATS")
    _v17_title(stats_panel, "현재 능력치", 18)
    var boxer: Dictionary = GameState.state.get("boxer", {})
    for stat_id in ["power", "speed", "technique", "defense", "conditioning"]:
        _v16_stat_row(stats_panel, stat_id, int(boxer.get(stat_id, 0)))

    _v17_career_progress_strip()
    _v17_section_heading("훈련 캠프 선택", "이번 캠프에서는 한 가지 성장에 집중합니다.")
    var core_ids := ["mitts", "roadwork", "heavy_bag", "defense_drill"]
    var grid := _v17_grid(2)
    for action_value in camp_actions:
        var action: Dictionary = action_value
        if str(action.get("id", "")) in core_ids:
            _v17_training_card(grid, action)

    var manage := _v17_secondary_button("회복 · 체중 · 스파링 관리 %s" % ("접기 ▲" if v17_manage_expanded else "보기 ▼"))
    manage.pressed.connect(func():
        v17_manage_expanded = not v17_manage_expanded
        _render_phase()
    )
    body.add_child(manage)
    if v17_manage_expanded:
        _v17_section_heading("컨디션 관리", "필요할 때만 펼쳐보는 보조 선택지입니다.")
        var management := _v17_grid(2)
        for action_value in camp_actions:
            var action: Dictionary = action_value
            if str(action.get("id", "")) not in core_ids:
                _v17_training_card(management, action)

    var shop := _v17_secondary_button("장비 · 체육관 투자  ›")
    shop.pressed.connect(Callable(self, "_open_equipment_shop"))
    body.add_child(shop)

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
