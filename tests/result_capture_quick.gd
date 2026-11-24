extends SceneTree

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    DisplayServer.window_set_size(Vector2i(430, 932))
    var game := root.get_node("GameState")
    game.new_career("김도현", "technician")
    game.state["first_launch_acknowledged"] = true
    game.state.erase("first_cycle_tutorial")
    var opponents: Array = JSON.parse_string(FileAccess.get_file_as_string("res://data/opponents.json"))
    var opponent: Dictionary = opponents[0]
    game.state["phase"] = "fight_offer"
    game.select_opponent(opponent)
    game.select_game_plan("outside_boxing")
    game.apply_fight_result("WIN_DEC", opponent, {"cards":[[10,9],[9,10],[10,9]],"round":3,"player_hp":71.0,"opponent_hp":63.0})
    var ui := (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await process_frame
    await process_frame
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui.launch_gate_active = false
    ui.v17_overlay = ""
    ui._render_phase()
    await process_frame
    await process_frame
    print("RESULT_NODE=", ui.find_child("ReferenceFightResult", true, false))
    var image := root.get_texture().get_image()
    print("CAPTURE_SIZE=", image.get_width(), "x", image.get_height())
    print("SAVE=", image.save_png("res://docs/ui-audit/result-screen-runtime.png"))
    quit(0)
