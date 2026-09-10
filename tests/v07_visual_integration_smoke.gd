extends SceneTree

var failures: Array[String] = []
var main_view: Control
var game_state: Node

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    _check(VisualAssetCatalog.fighter_path(true, "", "jab").ends_with("fighters/player/player_base_jab.png"), "player jab mapping mismatch")
    _check(VisualAssetCatalog.fighter_path(false, "out_boxer", "counter").ends_with("fighters/opponents/outboxer/op_outboxer_a_counter.png"), "out-boxer counter mapping mismatch")
    _check(VisualAssetCatalog.fighter_path(false, "counter_puncher", "down").ends_with("fighters/opponents/counter/op_counter_a_knockdown.png"), "counter knockdown mapping mismatch")
    _check(VisualAssetCatalog.portrait_path(false, "slugger").ends_with("portraits/portrait_slugger_a.png"), "legacy slugger portrait mapping mismatch")
    _check(VisualAssetCatalog.arena_path(true).ends_with("arena/arena_title_night.png"), "title arena mapping mismatch")

    _check(VisualAssetCatalog.opponent_visual_profile_for_name("박태호") == "korean", "Park Tae-ho visual identity must be Korean")
    _check(VisualAssetCatalog.opponent_portrait_path_for_name("박태호").ends_with("fighters/opponents/slugger/op_slugger_a_idle.png"), "Korean opponent portrait must match the East-Asian fight visual rather than the player portrait")
    _check(VisualAssetCatalog.opponent_portrait_path_for_name("박태호") != VisualAssetCatalog.portrait_path(true), "Korean opponent portrait must remain distinct from the player portrait")
    _check(VisualAssetCatalog.opponent_visual_style_for_name("박태호") == "slugger", "Korean opponent fight set must use the stable East-Asian pose set")
    _check(VisualAssetCatalog.opponent_visual_profile_for_name("에번 브룩스") == "black", "Evan Brooks visual identity must be Black")
    _check(VisualAssetCatalog.opponent_portrait_path_for_name("에번 브룩스").ends_with("portraits/portrait_swarmer_a.png"), "Black opponent portrait mapping mismatch")
    _check(VisualAssetCatalog.opponent_visual_style_for_name("에번 브룩스") == "swarmer", "Black opponent fight set mapping mismatch")

    var identity_regions: Array[Rect2] = []
    for style in ["", "slugger", "swarmer", "outboxer", "counter"]:
        var is_player: bool = style.is_empty()
        var fighter := VisualAssetCatalog.identity_fighter_texture(is_player, style) as AtlasTexture
        var portrait := VisualAssetCatalog.identity_portrait_texture(is_player, style) as AtlasTexture
        _check(fighter != null and portrait != null, "identity atlas unavailable for " + style)
        if fighter == null or portrait == null: continue
        _check(fighter.atlas == portrait.atlas, "portrait and ring use different identity sources: " + style)
        _check(fighter.region.encloses(portrait.region), "portrait is outside its fighter cell: " + style)
        _check(fighter.region.size.y > fighter.region.size.x * 1.7, "full-body identity has lost its legs: " + style)
        for previous in identity_regions:
            _check(not previous.intersects(fighter.region), "identity families overlap: " + style)
        identity_regions.append(fighter.region)

    var counter_fx := VisualAssetCatalog.fx_path({
        "counter_success": true,
        "player_action": "counter",
        "opponent_action": "power",
        "player_event": {"hit": true, "knockout": false},
        "opponent_event": {}
    })
    _check(counter_fx.ends_with("fx/fx_counter_flash_01.png"), "counter FX mapping mismatch")

    game_state = get_root().get_node_or_null("GameState")
    _check(is_instance_valid(game_state), "GameState autoload unavailable")
    if not is_instance_valid(game_state):
        _finish()
        return

    var opponents: Array = _load_array("res://data/opponents.json")
    _check(not opponents.is_empty(), "v0.7 fixture has no opponents")
    if opponents.is_empty():
        _finish()
        return

    game_state.new_career("Visual Boxer", "technician")
    game_state.state.boxer.weight_kg = 61.0
    game_state.state.phase = "fight_offer"
    game_state.select_opponent(opponents[0])
    _check(bool(game_state.select_tactical_preparation("counter_timing").get("ok", false)), "v1.1 fixture could not select tactical preparation")
    _check(bool(game_state.select_condition_preparation("sharpness").get("ok", false)), "v1.1 fixture could not select condition preparation")
    var selected: Dictionary = game_state.select_game_plan("counter_trap")
    _check(bool(selected.get("ok", false)), "v1.1 fixture could not select game plan")

    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _check(str(main_view.get_script().resource_path) == "res://scripts/main_v18_release.gd", "Main scene is not using the commercial v18 release shell")
    _check(load("res://assets/visual/v18/hero_player.webp") != null, "v18 hero WebP failed to load")
    _check(load("res://assets/visual/v18/training_atlas.webp") != null, "v18 training atlas WebP failed to load")
    _check(load("res://assets/visual/v18/opponent_atlas.webp") != null, "v18 opponent atlas WebP failed to load")
    _check(load("res://assets/visual/v18/fight_ring_scene.webp") != null, "v18 fight ring WebP failed to load")

    var stage: FightStage = _find_stage(main_view)
    _check(is_instance_valid(stage), "v1.1 actual fight screen rendered no FightStage")
    if is_instance_valid(stage):
        _check(stage.opponent_style == VisualAssetCatalog.opponent_visual_style_for_name(str(opponents[0].name)), "FightStage visual identity lookup mismatch")
        _check(stage.commercial_assets_active == VisualAssetCatalog.asset_pack_available(), "FightStage asset availability state mismatch")

    if VisualAssetCatalog.asset_pack_available():
        _check(VisualAssetCatalog.missing_required_paths().is_empty(), "installed visual pack is incomplete")
        _check(VisualAssetCatalog.portrait_texture(true) != null, "installed player portrait failed to load")
        _check(VisualAssetCatalog.opponent_portrait_texture_for_name(str(opponents[0].name)) != null, "identity-routed opponent portrait failed to load")
        _check(VisualAssetCatalog.fighter_texture(false, VisualAssetCatalog.opponent_visual_style_for_name(str(opponents[0].name)), "guard") != null, "identity-routed opponent guard failed to load")
        _check(VisualAssetCatalog.arena_texture(false) != null, "installed arena failed to load")
    else:
        _check(not VisualAssetCatalog.missing_required_paths().is_empty(), "fallback mode expected missing assets")

    main_view._choose_fight_action("jab")
    await process_frame
    stage = _find_stage(main_view)
    _check(is_instance_valid(stage), "FightStage disappeared after v1.1 exchange")
    if is_instance_valid(stage):
        _check(stage.presentation_event_id == 1, "v1.1 exchange did not reach FightStage presentation")

    _finish()

func _find_stage(node: Node) -> FightStage:
    for child in node.get_children():
        if child is FightStage:
            return child as FightStage
        var nested := _find_stage(child)
        if nested != null:
            return nested
    return null

func _load_array(path: String) -> Array:
    var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
    return parsed if typeof(parsed) == TYPE_ARRAY else []

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    if failures.is_empty():
        print("v18-visual-identity-and-ui-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)
