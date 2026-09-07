extends "res://scripts/main_v08.gd"

const RELEASE_FONT_PATH := "res://assets/fonts/NotoSansKR-VF.ttf"
const RELEASE_FONT_LICENSE_PATH := "res://assets/fonts/OFL-NotoSansKR.txt"

func _apply_v07_system_font() -> void:
    var bundled_font := load(RELEASE_FONT_PATH) as FontFile
    if bundled_font == null:
        push_error("Bundled Korean release font failed to load: %s" % RELEASE_FONT_PATH)
        return

    # Release typography must be deterministic across iPhone devices and CI.
    # Noto Sans KR contains the Korean/Latin glyphs used by the product, so do
    # not silently substitute an OS font if a glyph is missing.
    bundled_font.allow_system_fallback = false

    var ui_theme := Theme.new()
    ui_theme.default_font = bundled_font
    theme = ui_theme
