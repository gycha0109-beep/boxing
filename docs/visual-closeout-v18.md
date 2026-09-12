# v18 visual continuation — PR #13 (Draft / HOLD)

Baseline: `a435ab8dfca56c8725d58dec69fcbb680e45bde5`, branch
`feat/legacy-state-foundation-v1.2`. Continue the committed identity atlas and
release shell. No merge, deployment, audio asset, combat rule or save change.

## Changes

- Compact two-column opponent cards expose all three starting offer CTAs at
  430x932. Camp buttons align across each row; gold buttons have rounded edges.
- Keep the existing separate arena and transparent full-body fighter layers.
  Align sole shadows, constrain transformed hurt/down bodies to the viewport,
  crop the title arena above its apron, and derive read/impact positions from
  actual rendered fighter height.
- Add action cues from the existing icon pack and restore the result heading
  and condition preparation's no-permanent-growth explanation.
- Preserve profile access to all five stat help buttons. Update the first-flow
  smoke to click each real profile help control, rather than expecting the
  obsolete camp stat panel. Add atlas identity and 18-image capture coverage.

## Verification (2026-09-10)

Runtime: official Godot 4.7.2 Windows, release ZIP verified against upstream
SHA512-SUMS. OpenGL compatibility renderer, NVIDIA GTX 1060, actual 430x932
viewport. Test APPDATA isolated under ignored `build/test-appdata`.

Downloaded and opened the baseline capture artifact from run `34335456067`.
Opened the newly rendered camp, offers, tactical preparation, condition,
profile/help, fight opening, Korean/US/Mexican/Russian matchups, hurt/down and
result images. Re-rendered after fixing offer height and title-arena framing.

- Camp: four primary CTAs visible, two columns.
- Offers: three starting CTAs visible, two columns; names/countries retained.
- Tactical and condition preparation: two columns, primary choices visible.
- Fight: no scroll; all five existing actions visible. Head, gloves, torso,
  knees and both boots visible. Soles remain on the canvas in both arena types.
  HUD portraits use the same identity source as their ring fighters.
- Profile: all five help buttons open the correct text. Result: result and
  career continuation CTA visible.
- 18 capture images produced; viewport, content overflow and CTA checks pass.
- All 17 Godot smoke scripts pass, including commercial audio, save/resume,
  preparation, economy, legacy, identity and fixed fight HUD.
- All 11 Python QA commands pass, including 10,000 career simulation. Windows
  default CP949 caused initial decode failures; failed commands were rerun with
  `PYTHONUTF8=1`. The pinned font license hash was verified using the exact Git
  LF blob after confirming the checkout differed only by CRLF, then the original
  checkout bytes were restored. No font/license changes are committed.
- Godot emitted the existing exit resource-leak warnings; the local sandbox
  also denies the system certificate store. No GDScript errors in the smokes.

Reproduction: run `.github/workflows/qa.yml` commands with Godot 4.7.2;
render with `--path . --script res://tests/visual_capture_v10.gd` using a real
display or the workflow's Xvfb setup. Local evidence is in ignored `build/qa`
and uncommitted `visual-captures/v1.2-v18`; CI uploads the 18 PNGs. No `.import`,
`.uid` or temporary captures are included in the commit.

## Remaining visual differences

The mockups have sharper arena photography, larger portraits and richer
typography. Existing visual families are shared by multiple named opponents;
there is no unique face for each roster entry. Knockdown remains a rigid
rotation of the intact fighter rather than an authored falling pose. Gameplay
continues to expose five actions, rather than inventing the mockup's sixth.
PR #13 remains Draft/HOLD pending further art direction.
