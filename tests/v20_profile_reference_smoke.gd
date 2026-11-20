extends SceneTree

var failures: Array[String] = []

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var state_node: Node = get_root().get_node("GameState")
    state_node.new_career("레퍼런스 테스트", "technician")
    state_node.state["first_launch_acknowledged"] = true
    state_node.state["phase"] = "camp"
    state_node.state["boxer"]["health"] = 72
    state_node.state["boxer"]["fatigue"] = 31
    state_node.state["boxer"]["weight_kg"] = 61.4
    state_node.state["boxer"]["power"] = 67
    state_node.state["career"]["rank"] = 17
    state_node.state["career"]["career_points"] = 36
    var stage := load("res://scenes/Main.tscn") as PackedScene
    var view: Control = stage.instantiate()
    get_root().add_child(view)
    await process_frame
    await process_frame
    view._v17_open_overlay("profile")
    await process_frame
    await process_frame
    var screen: Control = view.find_child("ReferenceProfile", true, false)
    _require(screen != null, "reference profile not rendered")
    if screen != null:
        _require(screen.find_child("ReferenceBoxerPortrait", true, false) != null, "reference portrait missing")
        var texts: Array[String] = []
        var bars: Array[int] = []
        _collect(screen, texts, bars)
        for required in ["레퍼런스 테스트", "72 / 100", "31%", "61.4 kg", "#17", "36 CP", "67"]:
            _require(required in texts, "missing dynamic game data: %s" % required)
        _require(bars.size() == 5, "expected 5 stat bars, found %d" % bars.size())
        _require(67 in bars, "power meter does not track boxer state")
        _require(screen.size.x <= 450, "reference UI exceeds viewport by more than expected")
    view._v17_open_overlay("career")
    await process_frame
    _require(view.find_child("ReferenceProfile", true, false) == null, "profile remains after tab switch")
    view._v17_open_overlay("profile")
    await process_frame
    _require(view.find_child("ReferenceProfile", true, false) != null, "profile cannot reopen")
    if failures.is_empty():
        print("PASS: reference profile, data binding, and tab navigation")
        quit(0)
    else:
        printerr("FAIL: ", failures)
        quit(1)

func _collect(node: Node, texts: Array[String], bars: Array[int]) -> void:
    if node is Label:
        texts.append((node as Label).text)
    if node is ProgressBar:
        bars.append(int((node as ProgressBar).value))
    for child in node.get_children():
        _collect(child, texts, bars)

func _require(ok: bool, reason: String) -> void:
    if not ok:
        failures.append(reason)
        push_error(reason)
