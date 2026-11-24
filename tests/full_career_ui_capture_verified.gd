extends SceneTree

const SAVE := preload("res://scripts/core/save_service.gd")
const OUT := "res://docs/ui-audit/full-career-ui-reworked-verified"

var game: Node
var ui: Control
var opponents: Array
var screenshots: Array[Dictionary] = []
var index := 0
var failures: Array[String] = []
var simulated_fights := 0

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: isolated save directory required")
        quit(2)
        return
    DisplayServer.window_set_size(Vector2i(430, 932))
    root.gui_embed_subwindows = true
    DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
    game = root.get_node("GameState")
    var content: Variant = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    opponents = content if content is Array else []
    game.new_career("감사 테스트 복서", "technician")
    game.state.erase("first_launch_acknowledged")
    game.state.erase("first_cycle_tutorial")
    SAVE.save_game(game.state)
    ui = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await _settle()
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui._return_to_reference_title()
    await _snap("타이틀", "실제 타이틀 첫 실행", "real")

    ui._start_new_career_from_title()
    await _settle()
    await _snap("첫 실행 안내", "튜토리얼 첫 화면", "real")
    ui._tutorial_story_next()
    await _snap("튜토리얼 개요", "첫 이용 설명", "real")
    ui._tutorial_story_next()
    await _snap("복싱 스타일 선택", "선수 생성 스타일 선택", "real")

    if not bool(game.select_boxing_style("balanced").get("ok",false)):
        _error("style selection rejected")
    ui._render_phase()
    await _snap("재능 추첨", "첫 재능 추첨 진행", "real")
    await create_timer(5.0).timeout
    await _snap("재능 추첨 결과", "추첨 종료", "real")
    ui._complete_random_talent_roll()
    await _snap("선수 생성 확인", "재능 확인", "real")
    ui._confirm_talent()
    await _settle()
    await _snap("훈련 캠프", "첫 캠프 훈련", "real")
    await _snap_scroll("훈련 캠프 하단")
    ui._v17_open_overlay("profile")
    await _snap("선수 프로필", "선수 상태와 능력치", "real")
    await _snap_scroll("선수 프로필 하단")
    ui._v17_open_overlay("career")
    await _snap("커리어 기록", "커리어 관리", "real")
    ui._v17_open_training()
    await _settle()
    ui._open_equipment_shop()
    await _snap("장비 상점", "장비와 투자", "real")
    await _snap_scroll("장비 상점 하단")
    ui._return_from_equipment_shop()
    await _settle()

    if ui.camp_actions.is_empty():
        _error("missing camp actions")
    else:
        ui._choose_camp_action(ui.camp_actions[0])
        await _settle()
        await _snap("첫 훈련 결과", "첫 튜토리얼 훈련 결과", "real")
        if game.state.get("first_cycle_tutorial",{}).get("training_result_pending",false):
            ui._tutorial_story_next()
    await _settle()
    await _snap("상대 선택", "경기 계약 제안", "real")
    await _snap_scroll("상대 선택 하단")
    if opponents.is_empty():
        _error("no opponents loaded")
    else:
        var first: Dictionary = opponents[0]
        ui._choose_opponent(first)
        await _settle()
        await _snap("상대 분석", "스카우팅과 전술 준비", "real")
        await _snap_scroll("상대 분석 하단")
        ui._choose_game_plan("balanced")
        await _settle()
        await _snap("계체 확인", "경기 직전 계체", "real")
        ui._acknowledge_weigh_in()
        await _settle()
        await _snap("경기 시작", "실제 경기 HUD", "real")
        ui._choose_fight_action("jab")
        await create_timer(0.35).timeout
        await _snap("경기 중", "첫 타격 교환 후", "real")
        # A bounded scripted match settlement avoids hundreds of automated combat turns.
        game.apply_fight_result("WIN_DEC", first, {"player_hp":84.0,"opponent_hp":38.0})
        simulated_fights += 1
        ui._render_phase()
        await _snap("경기 결과", "첫 경기 판정승 재현", "simulated_result")
        ui._continue_from_reference_result()
        await _settle()
        if game.state.get("first_cycle_tutorial",{}).get("complete_pending",false):
            await _snap("튜토리얼 완료", "첫 경기 이후 안내", "real")
            ui._tutorial_story_next()
        await _settle()
        if str(game.state.get("phase","")) == "event":
            await _snap("커리어 이벤트", "경기 이후 이벤트", "real")
            game.resolve_pending_event()
            ui._render_phase()
        await _snap("첫 경기 이후", "커리어 진행 화면", "real")

    # The remaining bouts are progressed through the production game-state
    # methods with deterministic losses to exercise an actual retirement ending.
    for bout in range(2, 45):
        if bool(game.state.career.finished):
            break
        var phase := str(game.state.get("phase",""))
        if phase == "event":
            await _snap("이벤트 %d" % bout, "커리어 이벤트", "real")
            game.resolve_pending_event()
        phase = str(game.state.get("phase",""))
        if phase == "sponsor_offer":
            ui._render_phase()
            await _snap("스폰서 제안", "스폰서 계약", "real")
            game.decline_sponsorship()
        phase = str(game.state.get("phase",""))
        if phase == "gym_fund_intro":
            ui._render_phase()
            await _snap("체육관 투자 안내", "체육관 자산 도입", "real")
            # Use the game UI continuation when available.
            var btn := ui.find_child("GymFundContinue", true, false) as Button
            if btn != null:
                btn.pressed.emit()
            else:
                game.state.phase = "camp"
        phase = str(game.state.get("phase",""))
        if phase == "season_review":
            ui._render_phase()
            await _snap("시즌 검토", "시즌 종료 계약 결정", "real")
            if not game.sign_contract("balanced"):
                var ids: Array = game.League.CONTRACTS.keys()
                if not ids.is_empty(): game.sign_contract(str(ids[0]))
        if str(game.state.get("phase","")) == "champion_choice":
            ui._render_phase()
            await _snap("챔피언 선택", "방어전 또는 은퇴", "real")
            game.champion_decision(false)
        if bool(game.state.career.finished):
            break
        if str(game.state.get("phase","")) == "camp":
            game.management_visit()
        phase = str(game.state.get("phase",""))
        if phase != "fight_offer":
            _error("bout %d blocked in phase %s" % [bout,phase])
            break
        ui._render_phase()
        if bout == 2:
            await _snap("다음 경기 선택", "반복 커리어 진입", "real")
        var offer_list: Array = game.get_fight_offers(opponents)
        if offer_list.is_empty():
            _error("no offer in bout %d" % bout)
            break
        var rival: Dictionary = offer_list[0]
        game.select_opponent(rival)
        game.select_game_plan("balanced")
        ui.current_opponent = rival
        ui.combat = null
        ui._render_phase()
        if bout == 2:
            await _snap("다음 경기 준비", "두 번째 경기 전투 UI", "real")
        game.apply_fight_result("LOSS_DEC", rival, {"player_hp":25.0,"opponent_hp":75.0})
        simulated_fights += 1
        ui._render_phase()
        if bout <= 3 or bool(game.state.career.finished):
            await _snap("경기 %d 결과" % bout, "경기 결과 재현", "simulated_result")
        game.advance_after_result()
        ui.current_opponent = {}
        ui.combat = null
        ui._render_phase()
        if bout % 3 == 0:
            await _snap("커리어 진행 %d" % bout, "누적 %d경기" % bout, "real")

    var ended := bool(game.state.career.finished)
    if not ended:
        _error("career did not end naturally after %d scripted bouts" % simulated_fights)
    else:
        if str(game.state.get("phase","")) != "career_summary":
            game.state.phase = "career_summary"
        ui._render_phase()
        await _snap("커리어 종료", "은퇴 또는 종료 정산", "real")
        await _snap_scroll("커리어 종료 하단")
        var candidates: Array = game.retirement_legacy_candidates()
        if not candidates.is_empty():
            var chosen: Dictionary = candidates[0]
            var accepted: Dictionary = game.select_retirement_legacy(str(chosen.get("id","")))
            if bool(accepted.get("ok",false)):
                ui._render_phase()
                await _snap("유산 선택 후", "다음 세대를 위한 유산", "real")
        var next: Dictionary = game.start_next_generation()
        if bool(next.get("ok",false)):
            ui._render_phase()
            await _snap("다음 세대 시작", "한 커리어 종료 후 후계 시작", "real")

    await _write_report()
    if failures.is_empty():
        print("PASS: screenshots=",screenshots.size()," fights=",simulated_fights)
        quit(0)
    else:
        printerr("PARTIAL: screenshots=",screenshots.size()," issues=",failures)
        quit(1)

func _snap(label: String, explanation: String, kind: String) -> void:
    await _settle()
    await RenderingServer.frame_post_draw
    var img := root.get_texture().get_image()
    var safe := "%03d_%s.png" % [index,label]
    var err := img.save_png(ProjectSettings.globalize_path(OUT.path_join(safe)))
    if err != OK:
        _error("saving failed "+safe)
    else:
        screenshots.append({"file":safe,"title":label,"description":explanation,"kind":kind,
            "phase":str(game.state.get("phase","")),"fights":int(game.state.get("career",{}).get("fights",0)),
            "width":img.get_width(),"height":img.get_height()})
        print("CAPTURE ",safe," phase=",game.state.get("phase",""))
        index += 1

func _snap_scroll(label: String) -> void:
    var sc := ui.find_child("V17ContentScroll",true,false) as ScrollContainer
    if sc == null or sc.scroll_vertical <= 0 and sc.get_v_scroll_bar().max_value <= sc.size.y+5:
        return
    var original := sc.scroll_vertical
    sc.scroll_vertical = int(maxf(0,sc.get_v_scroll_bar().max_value-sc.size.y))
    await _snap(label,"같은 화면의 아래쪽 스크롤", "real")
    sc.scroll_vertical = original

func _settle() -> void:
    for k in range(3):
        await process_frame

func _error(message: String) -> void:
    failures.append(message)
    printerr("AUDIT ISSUE ",message)

func _write_report() -> void:
    var payload := {"screenshots":screenshots,"issues":failures,"simulated_fights":simulated_fights,
        "method":"Godot live renderer, authentic game UI with scripted battle results; isolated user:// save"}
    var manifest := FileAccess.open(OUT.path_join("manifest.json"),FileAccess.WRITE)
    if manifest != null:
        manifest.store_string(JSON.stringify(payload,"  "))
        manifest.close()
