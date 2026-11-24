# Twelve Count — UI polish application (2026-11-23)

## Policy
Retain the exact flow and existing screen hierarchy from the 37-screen audit. All source images, card order, save logic, and action semantics remain unchanged.

## Implemented
- Shared near-black / dark slate and restrained gold palette in main_v17.gd.
- Raised-card background / muted border / hover and focus states from twelve_design_system.gd.
- Better Korean body copy sizing and contrast; font fallback across gameplay.
- Shared bevel geometry and gold metallic primary buttons via reference_ui.gd.
- Inherited screen finishing hooks in main_v18_release.gd; retain title-specific art and layouts.
- Primary gold-button style harmonized in main_v18_release_base.gd.

## Verification
- Original audit 37 captures and upgraded run 40 captures, at 430x932.
- 7 scripted bout outcomes produce an actual retirement and next-generation transition.
- Seven targeted regression suites PASS, after aligning two old tests with title-first launch behavior.
- One Godot resource-in-use warning observed in preparation test despite exit 0.
- User save remains untouched (isolated test user-data directory).

## Limitations
- This is a full-screen shared-style pass, not reillustration or hand-made bespoke art for every screen.
- Event draws differ between audit runs; comparisons are stage-matched rather than frame-perfect.
- Tutorial spotlights intentionally dim non-target UI and remain unchanged.
- Championship and other optional endings were not captured in this route.
