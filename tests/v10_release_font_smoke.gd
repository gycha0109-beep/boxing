extends SceneTree

const RELEASE_FONT_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"

var failures: Array[String] = []
var main_view: Control

func _init() -> void:
    call_deferred("_run")

func _run() -> void:
    var packed: PackedScene = load("res://scenes/Main.tscn")
    _check(is_instance_valid(packed), "Main scene could not load for v1.0 release-font smoke")
    if not is_instance_valid(packed):
        _finish()
        return

    main_view = packed.instantiate()
    get_root().add_child(main_view)
    await process_frame
    await process_frame

    _check(str(main_view.get_script().resource_path) == "res://scripts/main_v18_release.gd", "Main scene is not using the active v18 release shell that preserves the bundled-font runtime")
    _check(main_view.theme != null, "Main view has no release Theme")
    if main_view.theme == null:
        _finish()
        return

    var release_font := main_view.theme.default_font
    _check(release_font is FontFile, "release Theme default font is not a FontFile")
    if not (release_font is FontFile):
        _finish()
        return

    var font_file := release_font as FontFile
    _check(str(font_file.resource_path) == RELEASE_FONT_PATH, "release Theme is not using bundled Noto Sans KR")
    _check(not font_file.allow_system_fallback, "release font still allows OS/system fallback")
    _check(not font_file.data.is_empty(), "bundled release font contains no source data")

    for character in ["한", "글", "복", "싱", "계", "체", "챔", "피", "언", "A", "0", "★", "·"]:
        _check(font_file.has_char(character.unicode_at(0)), "bundled release font missing glyph: %s" % character)

    _finish()

func _finish() -> void:
    if is_instance_valid(main_view):
        main_view.queue_free()
    if failures.is_empty():
        print("v10-release-font-smoke: PASS")
        quit(0)
        return
    for failure in failures:
        push_error(failure)
    quit(1)

func _check(condition: bool, message: String) -> void:
    if not condition:
        failures.append(message)