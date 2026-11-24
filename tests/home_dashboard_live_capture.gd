extends SceneTree

const SAVE := preload("res://scripts/core/save_service.gd")
const OUT := "res://docs/ui-audit/home-dashboard-v1.png"

var game: Node
var ui: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    if not OS.get_user_data_dir().contains("_sandbox_user_data"):
        printerr("ABORT: isolated save directory required")
        quit(2)
        return
    DisplayServer.window_set_size(Vector2i(430, 932))
    game = root.get_node("GameState")
    game.new_career("김도현", "technician")
    game.state.erase("first_cycle_tutorial")
    game.state["first_launch_acknowledged"] = true
    game.state.boxer.power = 80
    game.state.boxer.speed = 76
    game.state.boxer.technique = 74
    game.state.boxer.defense = 76
    game.state.boxer.conditioning = 82
    game.state.career.money = 120000
    game.state.career.wins = 8
    game.state.career.losses = 1
    game.state.career.draws = 0
    game.state.career.rank = 5
    game.state.career.fights = 9
    SAVE.save_game(game.state)
    ui = (load("res://scenes/Main.tscn") as PackedScene).instantiate()
    root.add_child(ui)
    await _settle()
    ui._onboarding_install.clear()
    ui._guide_settings.clear()
    ui._continue_from_reference_title()
    ui._v19_open_home()
    await _settle()
    await RenderingServer.frame_post_draw
    var image := root.get_texture().get_image()
    if image == null:
        printerr("HOME_CAPTURE_FAIL")
        quit(1)
        return
    var error := image.save_png(ProjectSettings.globalize_path(OUT))
    print("HOME_CAPTURE: ", error, " ", image.get_width(), "x", image.get_height())
    quit(0)

func _settle() -> void:
    for frame in range(4):
        await process_frame
