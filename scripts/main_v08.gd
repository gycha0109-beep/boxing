extends "res://scripts/main_v07.gd"

const V08_MUTED := Color(0.68, 0.70, 0.75, 1.0)
const V08_ACCENT := Color(0.92, 0.70, 0.34, 1.0)
const V08_SUCCESS := Color(0.42, 0.82, 0.56, 1.0)
const V08_DANGER := Color(0.95, 0.38, 0.34, 1.0)

var launch_gate_active: bool = false

func _ready() -> void:
    launch_gate_active = _should_show_launch_title()
    super._ready()

func _render_phase() -> void:
    if launch_gate_active:
        _render_launch_title()
        return
    if _needs_weigh_in_interstitial():
        _render_weigh_in()
        return
    super._render_phase()

func _render_status() -> void:
    if launch_gate_active:
        status.text = "BOXING REBIRTH · ONE FIGHTER. ONE CAREER."
        return

    var s: Dictionary = GameState.state
    if s.is_empty():
        status.text = ""
        return
    var boxer: Dictionary = s.get("boxer", {})
    var career: Dictionary = s.get("career", {})
    var record := "%d-%d-%d" % [int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0))]
    var injury_text := ""
    var injury: Dictionary = boxer.get("injury", {})
    if not injury.is_empty():
        injury_text = " · 부상 %s" % str(injury.get("name", ""))

    if str(s.get("phase", "")) == "fight":
        var plan: Dictionary = GameState.get_selected_game_plan()
        status.text = "%s · %s #%d · %s\n게임플랜 %s%s" % [
            str(boxer.get("name", "BOXER")), GameState.tier_label(), int(career.get("rank", 0)), record,
            str(plan.get("name", "균형 운영")), injury_text
        ]
        return

    status.text = "%s · %s #%d · %s · %s\n체중 %.1fkg · 피로 %d%% · 건강 %d%% · 보유금 %,d원%s" % [
        str(boxer.get("name", "BOXER")), GameState.tier_label(), int(career.get("rank", 0)), record, GameState.age_text(),
        float(boxer.get("weight_kg", 0.0)), int(boxer.get("fatigue", 0)), int(boxer.get("health", 0)), int(career.get("money", 0)), injury_text
    ]

func _render_launch_title() -> void:
    _clear_body()
    header.text = "TWELVE COUNT"
    status.text = "BOXING REBIRTH · ONE FIGHTER. ONE CAREER."

    var hero := _card_box("")
    var kicker := Label.new()
    kicker.text = "PRO BOXING CAREER"
    kicker.add_theme_font_size_override("font_size", 13)
    kicker.add_theme_color_override("font_color", V08_ACCENT)
    hero.add_child(kicker)

    var title := Label.new()
    title.text = "끝까지 버티는 한 명의 복서"
    title.add_theme_font_size_override("font_size", 28)
    title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    hero.add_child(title)

    var portrait := VisualAssetCatalog.portrait_texture(true)
    if portrait != null:
        var hero_portrait := _portrait_view(portrait, 248.0)
        hero_portrait.custom_minimum_size.y = 260.0
        hero.add_child(hero_portrait)

    var copy := Label.new()
    copy.text = "19세 무명 복서로 시작해 캠프, 계약, 스카우팅, 게임플랜, 3라운드 승부를 반복하며 챔피언 또는 은퇴까지 갑니다."
    copy.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    copy.add_theme_color_override("font_color", V08_MUTED)
    hero.add_child(copy)

    var rules := Label.new()
    rules.text = "SINGLE PLAYER · OFFLINE · PREMIUM · NO ADS"
    rules.add_theme_font_size_override("font_size", 12)
    rules.add_theme_color_override("font_color", V08_ACCENT)
    hero.add_child(rules)

    var start := Button.new()
    start.text = "프로 커리어 시작"
    start.custom_minimum_size = Vector2(0, 68)
    start.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    start.add_theme_font_size_override("font_size", 18)
    start.pressed.connect(Callable(self, "_start_new_career_from_title"))
    hero.add_child(start)

func _start_new_career_from_title() -> void:
    GameState.new_career("무명 복서")
    GameState.state["first_launch_acknowledged"] = true
    GameState.state["weigh_in_acknowledged"] = true
    SaveService.save_game(GameState.state)
    launch_gate_active = false
    _render_phase()

func _should_show_launch_title() -> bool:
    var state: Dictionary = GameState.state
    if state.is_empty() or bool(state.get("first_launch_acknowledged", false)):
        return false
    var career: Dictionary = state.get("career", {})
    return (
        str(state.get("phase", "")) == "camp"
        and int(career.get("fights", 0)) == 0
        and str(state.get("last_camp_action", "")).is_empty()
        and str(state.get("selected_opponent", "")).is_empty()
    )

func _render_camp() -> void:
    if int(GameState.state.get("career", {}).get("fights", 0)) == 0:
        _eyebrow("PRO DEBUT · CAMP 01")
        var intro := Label.new()
        intro.text = "첫 프로 경기 전 마지막 준비입니다. 한 번만 고르고 바로 계약 단계로 넘어갑니다."
        intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
        intro.add_theme_color_override("font_color", V08_MUTED)
        body.add_child(intro)
    super._render_camp()

func _render_offers() -> void:
    _eyebrow("FIGHT WEEK · CONTRACT BOARD")
    super._render_offers()

func _render_game_plan() -> void:
    _eyebrow("FIGHT WEEK · SCOUTING DOSSIER")
    super._render_game_plan()

func _choose_game_plan(plan_id: String) -> void:
    var plan_result: Dictionary = GameState.select_game_plan(plan_id)
    if bool(plan_result.get("ok", false)):
        GameState.state["weigh_in_acknowledged"] = false
        SaveService.save_game(GameState.state)
        _render_phase()

func _needs_weigh_in_interstitial() -> bool:
    var state: Dictionary = GameState.state
    if str(state.get("phase", "")) != "fight":
        return false
    if bool(state.get("weigh_in_acknowledged", true)):
        return false
    if not state.get("active_fight", {}).is_empty():
        return false
    return not state.get("last_weigh_in", {}).is_empty()

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

    _eyebrow("FIGHT WEEK · OFFICIAL WEIGH-IN")
    var title := Label.new()
    title.text = "공식 계체"
    title.add_theme_font_size_override("font_size", 28)
    body.add_child(title)

    var matchup := _card_box("")
    var portraits := HBoxContainer.new()
    portraits.add_theme_constant_override("separation", 12)
    matchup.add_child(portraits)

    var player_col := VBoxContainer.new()
    player_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portraits.add_child(player_col)
    var player_texture := VisualAssetCatalog.portrait_texture(true)
    if player_texture != null:
        player_col.add_child(_portrait_view(player_texture, 116.0))
    var player_name := Label.new()
    player_name.text = str(GameState.state.boxer.get("name", "BOXER"))
    player_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    player_col.add_child(player_name)

    var vs := Label.new()
    vs.text = "VS"
    vs.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
    vs.add_theme_font_size_override("font_size", 18)
    vs.add_theme_color_override("font_color", V08_ACCENT)
    portraits.add_child(vs)

    var opponent_col := VBoxContainer.new()
    opponent_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    portraits.add_child(opponent_col)
    var opponent_texture := VisualAssetCatalog.portrait_texture(false, str(current_opponent.get("style", "swarmer")))
    if opponent_texture != null:
        opponent_col.add_child(_portrait_view(opponent_texture, 116.0))
    var opponent_name := Label.new()
    opponent_name.text = str(current_opponent.get("name", "OPPONENT"))
    opponent_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent_col.add_child(opponent_name)

    var weigh_in: Dictionary = GameState.state.get("last_weigh_in", {})
    var status_id := str(weigh_in.get("status", "pass"))
    var limit := float(GameState.career_balance.weight_class.limit_kg)
    var boxer_weight := float(GameState.state.boxer.get("weight_kg", limit))
    var verdict := Label.new()
    verdict.add_theme_font_size_override("font_size", 25)
    verdict.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    match status_id:
        "emergency_cut":
            verdict.text = "긴급 감량 통과"
            verdict.add_theme_color_override("font_color", V08_ACCENT)
        "miss":
            verdict.text = "계체 실패"
            verdict.add_theme_color_override("font_color", V08_DANGER)
        _:
            verdict.text = "계체 통과"
            verdict.add_theme_color_override("font_color", V08_SUCCESS)
    body.add_child(verdict)

    var weight_line := Label.new()
    weight_line.text = "%.2f KG  /  LIMIT %.1f KG" % [boxer_weight, limit]
    weight_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    weight_line.add_theme_font_size_override("font_size", 18)
    body.add_child(weight_line)

    var detail := Label.new()
    detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
    detail.add_theme_color_override("font_color", V08_MUTED)
    match status_id:
        "emergency_cut":
            detail.text = "리밋을 %.2fkg 초과했지만 긴급 감량에 성공했습니다. 이번 경기에는 피로/건강 페널티가 반영됩니다." % max(0.0, float(weigh_in.get("over_kg", 0.0)))
        "miss":
            detail.text = "리밋을 %.2fkg 초과했습니다. 경기 수입은 %d%%로 조정되고 평판 페널티가 적용됩니다." % [max(0.0, float(weigh_in.get("over_kg", 0.0))), int(round(float(weigh_in.get("purse_multiplier", 1.0)) * 100.0))]
        _:
            detail.text = "공식 리밋 이내입니다. 감량 페널티 없이 예정대로 출전합니다."
    body.add_child(detail)

    var plan := GameState.get_selected_game_plan()
    var plan_box := _card_box("LOCKED GAME PLAN")
    _add_wrapped_label(plan_box, str(plan.get("name", "균형 운영")), false)
    _add_wrapped_label(plan_box, str(plan.get("description", "")), true)

    var enter := Button.new()
    enter.text = "FIGHT NIGHT 입장"
    enter.custom_minimum_size = Vector2(0, 68)
    enter.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    enter.add_theme_font_size_override("font_size", 18)
    enter.pressed.connect(Callable(self, "_acknowledge_weigh_in"))
    body.add_child(enter)

func _acknowledge_weigh_in() -> void:
    GameState.state["weigh_in_acknowledged"] = true
    SaveService.save_game(GameState.state)
    _render_phase()

func _render_result() -> void:
    var summary: Dictionary = GameState.state.get("last_fight_summary", {})
    var result_id := str(summary.get("result", GameState.state.get("last_result", "")))
    var result_text := _result_label(result_id)
    var win := result_id.begins_with("WIN")

    _eyebrow("FIGHT NIGHT · OFFICIAL RESULT")
    var hero := _card_box("")
    var result := Label.new()
    result.text = result_text
    result.add_theme_font_size_override("font_size", 38)
    result.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    result.add_theme_color_override("font_color", V08_SUCCESS if win else V08_DANGER)
    hero.add_child(result)

    var opponent := Label.new()
    opponent.text = "vs %s" % str(summary.get("opponent_name", "OPPONENT"))
    opponent.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    opponent.add_theme_font_size_override("font_size", 18)
    hero.add_child(opponent)

    var plan: Dictionary = GameState.get_game_plan(str(summary.get("game_plan", "balanced")))
    var meta := Label.new()
    meta.text = "%s · 수입 %,d원" % [str(plan.get("name", "균형 운영")), int(summary.get("purse", 0))]
    meta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
    meta.add_theme_color_override("font_color", V08_MUTED)
    hero.add_child(meta)

    var career: Dictionary = GameState.state.get("career", {})
    var boxer: Dictionary = GameState.state.get("boxer", {})
    var progression := _card_box("CAREER UPDATE")
    _add_wrapped_label(progression, "%d전 %d승 %d패 %d무 · 랭킹 #%d · 커리어 %dpt" % [
        int(career.get("fights", 0)), int(career.get("wins", 0)), int(career.get("losses", 0)), int(career.get("draws", 0)),
        int(career.get("rank", 0)), int(career.get("career_points", 0))
    ], false)
    _add_wrapped_label(progression, "건강 %d%% · 피로 %d%% · 체중 %.2fkg" % [
        int(boxer.get("health", 0)), int(boxer.get("fatigue", 0)), float(boxer.get("weight_kg", 0.0))
    ], true)

    var next := Button.new()
    next.text = "커리어 계속"
    next.custom_minimum_size = Vector2(0, 68)
    next.size_flags_horizontal = Control.SIZE_EXPAND_FILL
    next.pressed.connect(func():
        GameState.advance_after_result()
        current_opponent = {}
        _render_phase()
    )
    body.add_child(next)

func _eyebrow(text_value: String) -> void:
    var eyebrow := Label.new()
    eyebrow.text = text_value
    eyebrow.add_theme_font_size_override("font_size", 12)
    eyebrow.add_theme_color_override("font_color", V08_ACCENT)
    body.add_child(eyebrow)
