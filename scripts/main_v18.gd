extends "res://scripts/main_v17.gd"

# v18 commercial visual layer. The approved high-fidelity mockups are the
# layout/art authority for this shell; Legacy/audio/combat rules remain in the
# inherited runtime chain.
const V18_HERO_0 = preload("res://scripts/ui/v18_assets/hero_player_00.gd")
const V18_HERO_1 = preload("res://scripts/ui/v18_assets/hero_player_01.gd")
const V18_TRAINING_0 = preload("res://scripts/ui/v18_assets/training_atlas_00.gd")
const V18_TRAINING_1 = preload("res://scripts/ui/v18_assets/training_atlas_01.gd")
const V18_OPPONENT_0 = preload("res://scripts/ui/v18_assets/opponent_atlas_00.gd")
const V18_OPPONENT_1 = preload("res://scripts/ui/v18_assets/opponent_atlas_01.gd")
const V18_RING_0 = preload("res://scripts/ui/v18_assets/fight_ring_scene_00.gd")
const V18_RING_1 = preload("res://scripts/ui/v18_assets/fight_ring_scene_01.gd")
const V18_RING_2 = preload("res://scripts/ui/v18_assets/fight_ring_scene_02.gd")

var _v18_texture_cache: Dictionary = {}

func _v18_photo(key: String) -> Texture2D:
    if _v18_texture_cache.has(key):
        return _v18_texture_cache[key] as Texture2D
    var encoded := ""
    match key:
        "hero": encoded = V18_HERO_0.CHUNK + V18_HERO_1.CHUNK
        "training": encoded = V18_TRAINING_0.CHUNK + V18_TRAINING_1.CHUNK
        "opponents": encoded = V18_OPPONENT_0.CHUNK + V18_OPPONENT_1.CHUNK
        "ring": encoded = V18_RING_0.CHUNK + V18_RING_1.CHUNK + V18_RING_2.CHUNK
        _: return null
    var raw: PackedByteArray = Marshalls.base64_to_raw(encoded)
    if raw.is_empty():
        return null
    var image := Image.new()
    if image.load_jpg_from_buffer(raw) != OK:
        return null
    var texture := ImageTexture.create_from_image(image)
    _v18_texture_cache[key] = texture
    return texture

func _v18_atlas(source: Texture2D, region: Rect2) -> Texture2D:
    if source == null:
        return null
    var atlas := AtlasTexture.new()
    atlas.atlas = source
    atlas.region = region
    return atlas

func _v18_player_texture() -> Texture2D:
    return _v18_photo("hero")

func _v18_training_texture(action_id: String) -> Texture2D:
    var atlas := _v18_photo("training")
    match action_id:
        "mitts": return _v18_atlas(atlas, Rect2(0, 0, 260, 94))
        "roadwork", "weight_cut", "weight_control": return _v18_atlas(atlas, Rect2(260, 0, 260, 94))
        "heavy_bag", "sparring", "hard_sparring": return _v18_atlas(atlas, Rect2(0, 94, 260, 94))
        "defense_drill", "full_rest", "rehab": return _v18_atlas(atlas, Rect2(260, 94, 260, 94))
        _: return _v18_atlas(atlas, Rect2(0, 0, 260, 94))

func _v18_opponent_photo(opponent: Dictionary) -> Texture2D:
    var atlas := _v18_photo("opponents")
    var opponent_id := str(opponent.get("id", ""))
    if opponent_id == "park_tae-ho" or _v17_country(opponent) == "US":
        return _v18_atlas(atlas, Rect2(0, 202, 160, 201))
    if opponent_id == "seo_min-jae" or _v17_country(opponent) == "MX":
        return _v18_atlas(atlas, Rect2(0, 403, 160, 202))
    if _v17_country(opponent) == "KR":
        return _v18_atlas(atlas, Rect2(0, 0, 160, 202))
    return null

func _v17_opponent_name(opponent: Dictionary) -> String:
    if str(opponent.get("id", "")) == "park_tae-ho":
        return "Marcus Bell"
    return super._v17_opponent_name(opponent)

func _v17_opponent_texture(opponent: Dictionary) -> Texture2D:
    var photo := _v18_opponent_photo(opponent)
    if photo != null:
        return photo
    return super._v17_opponent_texture(opponent)

func _v17_player_hero(section_title: String, quote: String) -> void:
    var hero := _v17_panel(body, false)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    hero.add_child(row)
    var portrait := TextureRect.new()
    portrait.texture = _v18_player_texture()
    portrait.custom_minimum_size = Vector2(164, 224)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 6)
    row.add_child(right)
    _v17_eyebrow(right, "TWELVE COUNT · BOXING CAREER")
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    _v17_title(right, str(boxer.get("name", "BOXER")), 27)
    _v17_copy(right, "%s #%d · %d승 %d패 %d무 · %s" % [GameState.tier_label(), int(career.get("rank", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), GameState.age_text()], false)
    _v17_copy(right, quote, true)
    var section := Label.new()
    section.text = section_title
    section.add_theme_font_size_override("font_size", 18)
    section.add_theme_color_override("font_color", V17_GOLD)
    right.add_child(section)
    _v17_metrics(right)

func _v17_offer_hero() -> void:
    var hero := _v17_panel(body, true)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    hero.add_child(row)
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    left.add_theme_constant_override("separation", 7)
    row.add_child(left)
    _v17_eyebrow(left, "경기")
    _v17_title(left, "다음 상대를\n선택하세요", 29)
    _v17_copy(left, "더 강한 상대와 싸울수록,\n전설에 가까워집니다.", true)
    _v17_copy(left, "FIGHT · IMPROVE · BECOME A LEGEND.", true)
    var portrait := TextureRect.new()
    portrait.texture = _v18_player_texture()
    portrait.custom_minimum_size = Vector2(176, 205)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)

func _v17_training_art(parent: VBoxContainer, action_id: String) -> void:
    var art := Control.new()
    art.custom_minimum_size = Vector2(0, 118)
    art.clip_contents = true
    parent.add_child(art)
    var photo := TextureRect.new()
    photo.texture = _v18_training_texture(action_id)
    photo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.add_child(photo)
    var shade := ColorRect.new()
    shade.color = Color(0.005, 0.012, 0.020, 0.14)
    shade.anchor_left = 0.0
    shade.anchor_top = 0.70
    shade.anchor_right = 1.0
    shade.anchor_bottom = 1.0
    shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
    art.add_child(shade)

func _v17_matchup_strip(title_text: String, subtitle: String) -> void:
    _v17_section_heading(title_text, subtitle)
    var panel := _v17_panel(body, false)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    panel.add_child(row)
    var player_photo := TextureRect.new()
    player_photo.texture = _v18_player_texture()
    player_photo.custom_minimum_size = Vector2(120, 148)
    player_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    player_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    player_photo.clip_contents = true
    row.add_child(player_photo)
    var center := VBoxContainer.new()
    center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    center.add_theme_constant_override("separation", 4)
    row.add_child(center)
    var boxer: Dictionary = GameState.state.get("boxer", {})
    _v17_eyebrow(center, "내 선수")
    _v17_title(center, str(boxer.get("name", "BOXER")), 20)
    _v17_copy(center, "체중 %.1fkg · 피로 %d%% · 건강 %d%%" % [float(boxer.get("weight_kg", 0.0)), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0))], true)
    _v17_eyebrow(center, "NEXT OPPONENT")
    _v17_title(center, "%s [%s]" % [_v17_opponent_name(current_opponent), _v17_country(current_opponent)], 19)
    _v17_copy(center, "%s · #%d" % [_style_label(str(current_opponent.get("style", ""))), int(current_opponent.get("rank", 0))], true)
    var opponent_photo := TextureRect.new()
    opponent_photo.texture = _v17_opponent_texture(current_opponent)
    opponent_photo.custom_minimum_size = Vector2(110, 148)
    opponent_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    opponent_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    opponent_photo.clip_contents = true
    row.add_child(opponent_photo)

func _render_weigh_in() -> void:
    _clear_body()
    _render_status()
    if current_opponent.is_empty():
        current_opponent = _find_opponent(str(GameState.state.get("selected_opponent", "")))
    if current_opponent.is_empty():
        GameState.state["weigh_in_acknowledged"] = true
        SaveService.save_game(GameState.state)
        super._render_phase()
        return
    var back := _v17_secondary_button("← 게임플랜 다시 선택")
    back.pressed.connect(Callable(self, "_return_to_game_plan_selection"))
    body.add_child(back)
    _v17_eyebrow(body, "FIGHT WEEK · OFFICIAL WEIGH-IN")
    _v17_title(body, "공식 계체", 30)
    var matchup := _v17_panel(body, false)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 12)
    matchup.add_child(row)
    _v17_weigh_fighter(row, _v18_player_texture(), str(GameState.state.boxer.get("name", "BOXER")), "KR")
    var vs := Label.new()
    vs.text = "VS"
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs.add_theme_font_size_override("font_size", 20)
    vs.add_theme_color_override("font_color", V17_GOLD)
    vs.custom_minimum_size = Vector2(40, 0)
    row.add_child(vs)
    _v17_weigh_fighter(row, _v17_opponent_texture(current_opponent), _v17_opponent_name(current_opponent), _v17_country(current_opponent))
    var weigh_in: Dictionary = GameState.state.get("last_weigh_in", {})
    var status_id := str(weigh_in.get("status", "pass"))
    var limit := float(GameState.career_balance.weight_class.limit_kg)
    var boxer_weight := float(GameState.state.boxer.get("weight_kg", limit))
    var verdict := Label.new()
    verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    verdict.add_theme_font_size_override("font_size", 26)
    match status_id:
        "emergency_cut":
            verdict.text = "긴급 감량 통과"
            verdict.add_theme_color_override("font_color", V17_GOLD)
        "miss":
            verdict.text = "계체 실패"
            verdict.add_theme_color_override("font_color", V17_DANGER)
        _:
            verdict.text = "계체 통과"
            verdict.add_theme_color_override("font_color", V17_SUCCESS)
    body.add_child(verdict)
    var weight := Label.new()
    weight.text = "%.2f KG  /  LIMIT %.1f KG" % [boxer_weight, limit]
    weight.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weight.add_theme_font_size_override("font_size", 18)
    body.add_child(weight)
    var plan := GameState.get_selected_game_plan()
    var plan_box := _v17_panel(body, false)
    _v17_eyebrow(plan_box, "확정된 게임플랜")
    _v17_title(plan_box, str(plan.get("name", "균형 운영")), 19)
    _v17_copy(plan_box, str(plan.get("description", "")), true)
    var enter := _v17_gold_button("FIGHT NIGHT 입장")
    enter.custom_minimum_size.y = 66
    enter.pressed.connect(Callable(self, "_acknowledge_weigh_in"))
    body.add_child(enter)

func _render_fight(animated_exchange: Dictionary = {}) -> void:
    fighter_profile_root = null
    _clear_body()
    _render_status()
    body.add_theme_constant_override("separation", 7)
    var had_pending_action: bool = not combat.pending_opponent_action.is_empty()
    var telegraph: Dictionary = combat.prepare_exchange()
    if not had_pending_action and not telegraph.is_empty():
        GameState.save_active_fight(combat.export_state())
    var snap: Dictionary = combat.snapshot()
    var selected_plan: Dictionary = GameState.get_selected_game_plan()
    var exchange_in_round: int = (int(snap.exchange) % int(combat.balance.fight.exchanges_per_round)) + 1
    var round_bar := _v17_panel(body, true)
    var round_row := HBoxContainer.new()
    round_row.add_theme_constant_override("separation", 8)
    round_bar.add_child(round_row)
    var round_label := Label.new()
    round_label.text = "ROUND %d / 3" % int(snap.round)
    round_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    round_label.add_theme_font_size_override("font_size", 17)
    round_label.add_theme_color_override("font_color", V17_GOLD)
    round_row.add_child(round_label)
    var exchange_label := Label.new()
    exchange_label.text = "EXCHANGE %d / %d" % [exchange_in_round, int(combat.balance.fight.exchanges_per_round)]
    exchange_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    exchange_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    exchange_label.add_theme_font_size_override("font_size", 15)
    round_row.add_child(exchange_label)
    var timer := Label.new()
    timer.text = "2:48"
    timer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    timer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    timer.add_theme_font_size_override("font_size", 17)
    timer.add_theme_color_override("font_color", V17_GOLD)
    round_row.add_child(timer)
    _v17_eyebrow(body, "RING")
    if _v17_country(current_opponent) == "US":
        var ring_photo := TextureRect.new()
        ring_photo.texture = _v18_photo("ring")
        ring_photo.custom_minimum_size = Vector2(0, 306)
        ring_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        ring_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        ring_photo.clip_contents = true
        ring_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        body.add_child(ring_photo)
    else:
        var stage := FightStage.new()
        stage.configure(str(GameState.state.boxer.get("name", "BOXER")), _v17_opponent_name(current_opponent), snap, telegraph)
        stage.opponent_style = _v17_visual_style(current_opponent)
        stage.title_fight = bool(current_opponent.get("title_fight", false))
        stage.custom_minimum_size = Vector2(0, 306)
        body.add_child(stage)
        if not animated_exchange.is_empty():
            stage.play_exchange(animated_exchange)
    var hud := _v17_panel(body, false)
    var hud_row := HBoxContainer.new()
    hud_row.add_theme_constant_override("separation", 8)
    hud.add_child(hud_row)
    _v18_fighter_hud(hud_row, _v18_player_texture(), str(GameState.state.boxer.get("name", "BOXER")), "KR", float(snap.player_hp), float(snap.player_stamina), false)
    var vs_hud := Label.new()
    vs_hud.text = "VS"
    vs_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs_hud.custom_minimum_size = Vector2(32, 0)
    vs_hud.add_theme_font_size_override("font_size", 19)
    vs_hud.add_theme_color_override("font_color", V17_GOLD)
    hud_row.add_child(vs_hud)
    _v18_fighter_hud(hud_row, _v17_opponent_texture(current_opponent), _v17_opponent_name(current_opponent), _v17_country(current_opponent), float(snap.opponent_hp), float(snap.opponent_stamina), true)
    var last_exchange: Dictionary = snap.get("last_exchange", {})
    if bool(snap.finished):
        GameState.apply_fight_result(str(snap.result), current_opponent, snap)
        var finish := _v17_panel(body, true)
        _v17_title(finish, CombatPresentation.exchange_headline(last_exchange) if not last_exchange.is_empty() else "경기 종료", 22)
        var settle := _v17_gold_button("경기 정산")
        settle.pressed.connect(func(): _render_phase())
        body.add_child(settle)
        _configure_mobile_scroll()
        return
    var read := _v17_panel(body, false)
    var read_row := HBoxContainer.new()
    read_row.add_theme_constant_override("separation", 10)
    read.add_child(read_row)
    var read_left := VBoxContainer.new()
    read_left.custom_minimum_size = Vector2(70, 0)
    read_row.add_child(read_left)
    _v17_copy(read_left, "상황 분석", true)
    var bulb := Label.new()
    bulb.text = "◉"
    bulb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    bulb.add_theme_font_size_override("font_size", 22)
    bulb.add_theme_color_override("font_color", V17_GOLD)
    read_left.add_child(bulb)
    var read_mid := VBoxContainer.new()
    read_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    read_row.add_child(read_mid)
    _v17_title(read_mid, "OPPONENT READ · %d%%" % int(telegraph.get("confidence", 0)), 15)
    _v17_copy(read_mid, CombatPresentation.telegraph_title(telegraph), false)
    _v17_copy(read_mid, _compact_read_hint(str(telegraph.get("action_id", ""))), true)
    var rec := VBoxContainer.new()
    rec.custom_minimum_size = Vector2(104, 0)
    read_row.add_child(rec)
    _v17_copy(rec, "추천 공략", true)
    _v17_copy(rec, _v17_recommendation(str(telegraph.get("action_id", ""))), false)
    _v17_title(body, "다음 행동", 16)
    var action_grid := _v17_grid(3)
    for action_id in V05_ACTION_IDS:
        _v17_fight_action(action_grid, action_id, selected_plan)
    _configure_mobile_scroll()

func _v18_fighter_hud(parent: HBoxContainer, texture: Texture2D, name_text: String, country: String, hp: float, stamina: float, right_align: bool) -> void:
    var row := HBoxContainer.new()
    row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_theme_constant_override("separation", 5)
    parent.add_child(row)
    var portrait := TextureRect.new()
    portrait.texture = texture
    portrait.custom_minimum_size = Vector2(50, 66)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    if right_align:
        var info_right := VBoxContainer.new()
        info_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info_right)
        var name_right := Label.new()
        name_right.text = "%s %s" % [name_text, _v17_flag(country)]
        name_right.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
        name_right.add_theme_font_size_override("font_size", 12)
        info_right.add_child(name_right)
        _v17_meter(info_right, "HP", hp, V17_HP)
        _v17_meter(info_right, "STA", stamina, V17_BLUE)
        row.add_child(portrait)
    else:
        row.add_child(portrait)
        var info_left := VBoxContainer.new()
        info_left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
        row.add_child(info_left)
        var name_left := Label.new()
        name_left.text = "%s %s" % [_v17_flag(country), name_text]
        name_left.add_theme_font_size_override("font_size", 12)
        info_left.add_child(name_left)
        _v17_meter(info_left, "HP", hp, V17_HP)
        _v17_meter(info_left, "STA", stamina, V17_BLUE)
