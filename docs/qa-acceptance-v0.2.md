# QA / Acceptance v0.2

Date: 2026-09-07

## Automated gates

- All JSON data parses and required IDs/stats are valid.
- Every career tier has opponent coverage.
- Fight offers never expose title fights before the configured threshold.
- Camp actions cover training, recovery, and weight management.
- Save schema v2 and v1 migration paths exist.
- Combat supports export/restore of active fight state.
- Opponent ladder simulation completes deterministically.
- 10,000 full-career simulations complete without a stalled state.
- CI downloads the official Godot 4.7.2 stable Linux editor and verifies the release SHA-256 before execution.
- Godot 4.7.2 headless project parse/import completes successfully.
- The configured main scene boots successfully in Godot headless mode.

## Rejected baseline

First full-career simulation:

- Champion rate: **1.6%**
- Average fights: 18.9
- Health retirement: 55.4%
- Loss retirement: 43.0%

Verdict: **FAIL**. Progression was effectively locked and late-career content would rarely be seen.

## Accepted v0.2 simulation baseline

10,000 balanced-policy careers after progression, health, retirement, and economy tuning:

| Metric | Result |
|---|---:|
| Champion rate | 14.7% |
| Average fights | 29.0 |
| Average wins | 10.75 |
| Average final money | ₩3.17M |
| Loss retirement | 80.3% |
| Health retirement | 4.8% |
| Fight-limit retirement | 0.1% |
| Fights entered while injured | 9.0% |

Interpretation: the career is now winnable without making a first title trivial. Loss-retirement remains too dominant for final release balance; v0.2 accepts it as a system baseline, not as final tuning.

## Runtime gates still open

Godot syntax/import and a main-scene headless boot are now proven by CI. The following remain blockers before product-level QA:

- Complete button-flow interaction testing in a graphical runtime
- Active fight resume after an actual force-close
- Primary-save corruption falling back to the previous known-good backup with fixture files
- Legacy v1 save migration fixture
- iOS suspend/resume behavior
- Actual iPhone/iPad portrait layout and safe areas
- Touch target ergonomics
- Audio/haptics/impact feedback
- Xcode/iOS export and physical-device smoke

## Commercial acceptance

v0.2 is allowed to merge as a development baseline if deterministic and Godot headless CI checks pass. It is **not release-ready** and must not be described as a paid-product candidate until device/runtime interaction and first-five-minute fun gates are closed.
