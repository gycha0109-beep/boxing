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

func _v18_decode_chunks(chunks: Array) -> PackedByteArray:
    var raw := PackedByteArray()
    for encoded_value in chunks:
        var decoded: PackedByteArray = Marshalls.base64_to_raw(str(encoded_value))
        if decoded.is_empty():
            return PackedByteArray()
        raw.append_array(decoded)
    return raw

func _v18_photo(key: String) -> Texture2D:
    if _v18_texture_cache.has(key):
        return _v18_texture_cache[key] as Texture2D
    var raw := PackedByteArray()
    match key:
        "hero": raw = _v18_decode_chunks([V18_HERO_0.CHUNK, V18_HERO_1.CHUNK])
        "training": raw = _v18_decode_chunks([V18_TRAINING_0.CHUNK, V18_TRAINING_1.CHUNK])
        "opponents": raw = _v18_decode_chunks([V18_OPPONENT_0.CHUNK, V18_OPPONENT_1.CHUNK])
        "ring": raw = _v18_decode_chunks([V18_RING_0.CHUNK, V18_RING_1.CHUNK, V18_RING_2.CHUNK])
        _: return null
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
    portrait.custom_minimum_size = Vector2(150, 205)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)
    var right := VBoxContainer.new()
    right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    right.add_theme_constant_override("separation", 4)
    row.add_child(right)
    _v17_eyebrow(right, "TWELVE COUNT · BOXING CAREER")
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var career: Dictionary = GameState.state.get("career", {})
    _v17_title(right, str(boxer.get("name", "BOXER")), 26)
    _v17_copy(right, "%s #%d  |  %d승 %d패 %d무  |  %s" % [GameState.tier_label(), int(career.get("rank", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)), GameState.age_text()], false)
    _v17_copy(right, quote, true)
    _v17_copy(right, section_title, false)
    _v17_metrics(right)

func _v17_offer_hero() -> void:
    var hero := _v17_panel(body, false)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    hero.add_child(row)
    var left := VBoxContainer.new()
    left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    row.add_child(left)
    _v17_eyebrow(left, "경기")
    _v17_title(left, "다음 상대를 선택하세요", 28)
    _v17_copy(left, "더 강한 상대와 싸울수록, 전설에 가까워집니다.", true)
    var portrait := TextureRect.new()
    portrait.texture = _v18_player_texture()
    portrait.custom_minimum_size = Vector2(124, 145)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)

func _v17_training_art(parent: VBoxContainer, action_id: String) -> void:
    var art := TextureRect.new()
    art.texture = _v18_training_texture(action_id)
    art.custom_minimum_size = Vector2(0, 104)
    art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    art.clip_contents = true
    art.mouse_filter = Control.MOUSE_FILTER_IGNORE
    parent.add_child(art)

func _v17_opponent_contract(opponent: Dictionary, highlighted: bool) -> void:
    var card := _v17_panel(body, highlighted)
    var row := HBoxContainer.new()
    row.add_theme_constant_override("separation", 10)
    card.add_child(row)
    var portrait := TextureRect.new()
    portrait.texture = _v17_opponent_texture(opponent)
    portrait.custom_minimum_size = Vector2(122, 160)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    row.add_child(portrait)
    var info := VBoxContainer.new()
    info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    info.add_theme_constant_override("separation", 4)
    row.add_child(info)
    _v17_title(info, "%s  %s" % [_v17_opponent_name(opponent), _v17_flag(_v17_country(opponent))], 21)
    _v17_copy(info, "%s · %s" % [_tier_label(str(opponent.get("tier", ""))), _style_label(str(opponent.get("style", "")))], false)
    _v17_copy(info, _v17_opponent_quote(opponent), true)
    var stats: Dictionary = opponent.get("stats", {})
    _v17_copy(info, "파워 %d   스피드 %d   테크닉 %d" % [int(stats.get("power", 0)), int(stats.get("speed", 0)), int(stats.get("technique", 0))], false)
    _v17_copy(info, "수비 %d   체력 %d" % [int(stats.get("defense", 0)), int(stats.get("conditioning", 0))], true)
    var purse := Label.new()
    purse.text = "파이트머니  %s원" % _v17_money(int(opponent.get("purse", 0)))
    purse.add_theme_font_size_override("font_size", 19)
    purse.add_theme_color_override("font_color", V17_GOLD)
    info.add_child(purse)
    _v17_copy(info, "승리 +%dpt  |  패배 -%dpt" % [int(opponent.get("career_points_win", 0)), abs(int(opponent.get("career_points_loss", 0)))], true)
    var actions := HBoxContainer.new()
    actions.add_theme_constant_override("separation", 6)
    info.add_child(actions)
    var analyze := _v17_dark_button("상대 분석")
    analyze.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    analyze.pressed.connect(Callable(self, "_choose_opponent").bind(opponent))
    actions.add_child(analyze)
    var accept := _v17_gold_button("도전 수락  ›")
    accept.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    accept.pressed.connect(Callable(self, "_choose_opponent").bind(opponent))
    actions.add_child(accept)

func _v17_weigh_fighter(parent: HBoxContainer, texture: Texture2D, name_text: String, country: String) -> void:
    var col := VBoxContainer.new()
    col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    parent.add_child(col)
    var portrait := TextureRect.new()
    if country == "KR":
        portrait.texture = _v18_player_texture()
    elif not current_opponent.is_empty():
        portrait.texture = _v18_opponent_photo(current_opponent)
    else:
        portrait.texture = texture
    portrait.custom_minimum_size = Vector2(0, 150)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    col.add_child(portrait)
    var name := Label.new()
    name.text = "%s %s" % [name_text, _v17_flag(country)]
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    name.add_theme_font_size_override("font_size", 16)
    col.add_child(name)

func _v18_photo_hud(parent: HBoxContainer, texture: Texture2D, name_text: String, country: String, hp: float, stamina: float, right_align: bool) -> void:
    var wrap := HBoxContainer.new()
    wrap.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrap.add_theme_constant_override("separation", 6)
    parent.add_child(wrap)
    var portrait := TextureRect.new()
    portrait.texture = texture
    portrait.custom_minimum_size = Vector2(48, 58)
    portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
    portrait.clip_contents = true
    portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
    if not right_align:
        wrap.add_child(portrait)
    var box := VBoxContainer.new()
    box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    wrap.add_child(box)
    var name := Label.new()
    name.text = "%s %s" % [name_text, _v17_flag(country)]
    name.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT if right_align else HORIZONTAL_ALIGNMENT_LEFT
    name.add_theme_font_size_override("font_size", 13)
    box.add_child(name)
    _v17_meter(box, "HP", hp, V17_HP)
    _v17_meter(box, "STA", stamina, V17_BLUE)
    if right_align:
        wrap.add_child(portrait)

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
    var clock := Label.new()
    clock.text = "2:48"
    clock.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    clock.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
    clock.add_theme_font_size_override("font_size", 17)
    round_row.add_child(clock)

    _v17_eyebrow(body, "RING")
    var use_photo_ring := _v17_country(current_opponent) == "US"
    if use_photo_ring:
        var stage_photo := TextureRect.new()
        stage_photo.texture = _v18_photo("ring")
        stage_photo.custom_minimum_size = Vector2(0, 318)
        stage_photo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
        stage_photo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
        stage_photo.clip_contents = true
        stage_photo.mouse_filter = Control.MOUSE_FILTER_IGNORE
        body.add_child(stage_photo)
    else:
        var stage := FightStage.new()
        stage.configure(str(GameState.state.boxer.get("name", "BOXER")), _v17_opponent_name(current_opponent), snap, telegraph)
        stage.opponent_style = _v17_visual_style(current_opponent)
        stage.title_fight = bool(current_opponent.get("title_fight", false))
        stage.custom_minimum_size = Vector2(0, 318)
        body.add_child(stage)
        if not animated_exchange.is_empty():
            stage.play_exchange(animated_exchange)

    var hud := _v17_panel(body, false)
    var hud_row := HBoxContainer.new()
    hud_row.add_theme_constant_override("separation", 8)
    hud.add_child(hud_row)
    _v18_photo_hud(hud_row, _v18_player_texture(), str(GameState.state.boxer.get("name", "BOXER")), "KR", float(snap.player_hp), float(snap.player_stamina), false)
    var vs_hud := Label.new()
    vs_hud.text = "VS"
    vs_hud.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs_hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    vs_hud.custom_minimum_size = Vector2(30, 0)
    vs_hud.add_theme_font_size_override("font_size", 17)
    vs_hud.add_theme_color_override("font_color", V17_GOLD)
    hud_row.add_child(vs_hud)
    var opponent_photo := _v18_opponent_photo(current_opponent)
    if opponent_photo == null:
        opponent_photo = super._v17_opponent_texture(current_opponent)
    _v18_photo_hud(hud_row, opponent_photo, _v17_opponent_name(current_opponent), _v17_country(current_opponent), float(snap.opponent_hp), float(snap.opponent_stamina), true)

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
    read_row.add_theme_constant_override("separation", 8)
    read.add_child(read_row)
    var read_mid := VBoxContainer.new()
    read_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    read_row.add_child(read_mid)
    _v17_title(read_mid, "OPPONENT READ · %d%%" % int(telegraph.get("confidence", 0)), 15)
    _v17_copy(read_mid, CombatPresentation.telegraph_title(telegraph), false)
    _v17_copy(read_mid, _compact_read_hint(str(telegraph.get("action_id", ""))), true)
    var rec := VBoxContainer.new()
    rec.custom_minimum_size = Vector2(130, 0)
    read_row.add_child(rec)
    _v17_copy(rec, "추천 공략", true)
    _v17_copy(rec, _v17_recommendation(str(telegraph.get("action_id", ""))), false)
    var next_heading := Label.new()
    next_heading.text = "다음 행동"
    next_heading.add_theme_font_size_override("font_size", 15)
    next_heading.add_theme_color_override("font_color", V17_MUTED)
    body.add_child(next_heading)
    var action_grid := _v17_grid(3)
    for action_id in V05_ACTION_IDS:
        _v17_fight_action(action_grid, action_id, selected_plan)
    var spacer := Control.new()
    spacer.custom_minimum_size = Vector2(0, 78)
    action_grid.add_child(spacer)
    _configure_mobile_scroll()