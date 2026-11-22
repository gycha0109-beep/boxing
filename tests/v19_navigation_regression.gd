extends SceneTree

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState missing")
    if not is_instance_valid(game_state):
        _finish()
        return
    game_state.new_career("Navigation QA", "technician")
    game_state.state["first_launch_acknowledged"] = true
    game_state.state["phase"] = "camp"
    var scene := load("res://scenes/Main.tscn") as PackedScene
    _check(scene != null, "Main scene missing")
    if scene == null:
        _finish()
        return
    main_view = scene.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _nonempty("camp initial")
    main_view._v17_open_shop()
    await process_frame
    _check(_phase() == "equipment_shop", "shop button did not open equipment phase")
    _nonempty("shop")

    main_view._v17_open_training()
    await process_frame
    _check(_phase() == "camp", "training did not return from equipment to camp")
    _check(str(main_view.v17_overlay).is_empty(), "training left overlay")
    _nonempty("training")

    main_view._v17_open_match()
    await process_frame
    _check(_phase() == "camp", "match mutated career phase from camp")
    _check(str(main_view.v17_overlay) == "match_blocked", "match did not explain training prerequisite")
    _nonempty("match prerequisite")
    main_view._v19_return_to_phase()

    main_view._v17_open_shop()
    await process_frame
    _check(_phase() == "equipment_shop", "shop failed after match tab")
    main_view._v17_open_match()
    await process_frame
    _check(_phase() == "equipment_shop", "match tab overwrote equipment phase")
    _check(str(main_view.v17_overlay) == "match_blocked", "match tab did not explain equipment prerequisite")
    _nonempty("match from shop")

    main_view._v17_open_training()
    await process_frame
    _check(_phase() == "camp", "training cannot recover from blocked match tab")
    _nonempty("recovered camp")

    main_view._v17_open_shop()
    await process_frame
    game_state.state.career.money = 999999
    main_view._purchase_reference_equipment("personal", "club_gloves")
    await process_frame
    _check(_phase() == "equipment_shop", "equipment purchase skipped the result screen")
    _check(main_view.find_child("EquipmentReceipt", true, false) != null, "equipment purchase result was not displayed")
    var equipment_back := main_view.find_child("EquipmentShopBack", true, false) as Button
    _check(equipment_back != null and equipment_back.text == "경기 제안으로 이동", "completed purchase did not show the fight-offer action")
    var extra_purchase: Dictionary = game_state.can_purchase_equipment("gym", "club_mitts")
    _check(not bool(extra_purchase.get("ok", false)) and str(extra_purchase.get("reason", "")) == "activity_used", "shop allowed another purchase after the camp activity was used")
    if equipment_back != null:
        equipment_back.emit_signal("pressed")
        await process_frame
    _check(_phase() == "fight_offer", "equipment result action did not open fight offers")
    _nonempty("fight offers after equipment purchase")

    main_view._v17_open_overlay("profile")
    await process_frame
    _nonempty("profile")
    main_view._v17_open_overlay("career")
    await process_frame
    _nonempty("career")
    main_view._v19_open_menu()
    await process_frame
    _nonempty("header menu")
    main_view._v19_close_secondary()
    await process_frame
    _check(str(main_view.v17_overlay) == "career", "closing menu did not restore career tab")
    main_view._v19_open_settings()
    await process_frame
    _nonempty("settings")
    main_view._v19_close_secondary()
    await process_frame
    _check(str(main_view.v17_overlay) == "career", "closing settings did not restore career tab")
    _check(not main_view.v19_settings_button.disabled, "visible settings button is disabled")
    _finish()

func _nonempty(where: String) -> void:
    var body: VBoxContainer = main_view.body
    _check(is_instance_valid(body) and body.get_child_count() > 0, "%s showed an empty content area" % where)

func _phase() -> String:
    return str(game_state.state.get("phase", ""))

func _check(condition: bool, issue: String) -> void:
    if not condition:
        failures.append(issue)
        push_error(issue)

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
        await process_frame
        main_view = null
    await create_timer(0.15).timeout
    if failures.is_empty():
        print("PASS: v19 navigation never dead-ends in tested career phases")
        quit(0)
    else:
        printerr("FAIL: v19 navigation; ", failures)
        quit(1)
