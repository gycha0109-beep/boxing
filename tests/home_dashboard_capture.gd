extends SceneTree

func _init() -> void:
    call_deferred("_capture")

func _capture() -> void:
    await process_frame
    root.size = Vector2i(430, 932)
    var game_state: Node = root.get_node("GameState")
    game_state.call("new_career", "김도현")
    var state: Dictionary = game_state.get("state")
    var boxer: Dictionary = state.get("boxer", {})
    boxer["power"] = 80
    boxer["speed"] = 76
    boxer["technique"] = 74
    boxer["defense"] = 76
    boxer["conditioning"] = 82
    state["boxer"] = boxer
    var career: Dictionary = state.get("career", {})
    career["money"] = 120000
    career["wins"] = 8
    career["losses"] = 1
    career["draws"] = 0
    career["rank"] = 5
    career["fights"] = 9
    state["career"] = career
    state.erase("first_cycle_tutorial")
    state["first_launch_acknowledged"] = true
    game_state.set("state", state)
    root.get_node("SaveService").call("save_game", state)

    var main: Control = load("res://scenes/Main.tscn").instantiate()
    root.add_child(main)
    main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    await process_frame
    main.set("v17_overlay", "home")
    main.call("_render_phase")
    await process_frame
    await process_frame
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null:
        printerr("HOME_CAPTURE_FAIL")
        quit(1)
        return
    var error := image.save_png("res://docs/ui-audit/home-dashboard-v1.png")
    print("HOME_CAPTURE: ", error, " ", image.get_width(), "x", image.get_height())
    quit(0)
