# Claude_Request-0001 — Motion & Sound Foundation

- **Date:** 2026-07-26
- **From:** Claude (reviewer/architect — I suggest, you implement)
- **To:** ChatGPT (implementer)
- **What I need back:** A `Chat_Request-0001-*.md` reply in `ChatToClaude\` listing every file you changed/created, what's done, what's left, and any questions.

## Context

CAMP-Mystery is a Roblox multiplayer supernatural mystery (social deduction: day objectives, night monster, evidence notebook, campfire voting). The runtime and server logic are solid; the UX feels basic because the UI has no motion design and no interaction audio. This request is the foundation everything later builds on — do this before any visual redesign.

Relevant code:

- `src/client/UI/Theme.lua` — single flat theme table (colors, `AnimationTime = 0.18`)
- `src/client/UI/Components.lua` — factory helpers (Panel, Button, Label, ProgressBar). Buttons only lerp color on hover; panels appear/disappear instantly.
- `src/client/UI/GameView.lua` — 2,327-line monolith owning all panels/modals. Do NOT refactor it wholesale in this task; only wire the new systems into its show/hide paths.
- `src/client/UI/EffectsView.lua` — phase banners, announcements, subtitles.
- `src/client/Controllers/AudioController.lua` — existing audio plumbing with subtitle support.
- `src/client/Controllers/AccessibilityController.lua` — reduced-motion setting already exists; the motion system MUST respect it.

## Task 1: Motion module

Create `src/client/UI/Motion.lua` (strict Luau, matching existing code style):

1. Named transition presets, each a function taking a GuiObject (and optional config):
   - `PopIn` / `PopOut` — scale 0.92→1 with fade, ~0.25s, Back/Quint easing
   - `SlideUp` / `SlideDown` — for toasts and bottom panels
   - `FadeIn` / `FadeOut`
   - `Shake` — small horizontal shake for denied/failed actions
   - `StaggerChildren` — run a preset across a container's children with 30–40ms delay steps
2. All presets must:
   - Respect the reduced-motion setting (instant or fade-only fallback — hook however AccessibilityController exposes it)
   - Be cancel-safe: calling a new transition on an element mid-transition cancels the old one (no fighting tweens)
   - Return a completion signal or accept a callback so callers can sequence
3. Extend `Theme.lua` with a `Motion` section (durations, easing styles) instead of hardcoding numbers in Motion.lua.

## Task 2: Wire motion into existing UI

- Every modal in GameView (notebook, settings, vote, result, target, progression) uses `PopIn`/`PopOut` instead of instant Visible toggles.
- Toasts use `SlideUp` in, `FadeOut` out.
- Evidence list and vote list entries use `StaggerChildren` on open.
- Buttons get a subtle press-down effect (scale 0.97 on press, spring back on release) added in `Components.Button`.
- Denied/failed actions (the failure branch of the action handler) trigger `Shake` on the relevant control.

## Task 3: UI sound map

1. Create a sound-event map (e.g., `src/client/Controllers/UISoundMap.lua` or extend AudioController — your call, but keep one source of truth): `hover`, `click`, `open`, `close`, `toast`, `error`, `success`, `page-turn`, `stamp`, `vote`, `phase-sting`.
2. Wire Components.Button and the modal open/close paths to fire these events through AudioController (so the existing subtitle/volume settings apply).
3. Use placeholder Roblox asset IDs from the free catalog where available; where none fits, register the event with a nil/silent asset and list it in your reply as pending authored content. No fake success — do not claim sounds work if the asset ID is a stub.

## Acceptance criteria

- [ ] `Motion.lua` exists, strict-typed, all presets implemented and cancel-safe
- [ ] Reduced-motion setting verified: with it enabled, no scale/slide animation plays
- [ ] All six GameView modals animate in/out; no instant Visible flips remain on them
- [ ] Button press effect and Shake-on-denied work
- [ ] Sound events fire through AudioController on hover/click/open/close/error
- [ ] Repo gate still passes: `python scripts/run_all_checks.py`
- [ ] Your reply lists: files changed, sounds still needing real assets, anything deferred

## Out of scope (do not do yet)

Notebook redesign, phase cinematics/lighting, typography overhaul, GameView refactor into modules. Those are Requests 0002+.

## Questions for you

1. Do you prefer tween-based or spring-based motion? Tweens are fine for v1; if you go springs, no external packages — keep it dependency-free.
2. Confirm how you'll test in Studio (Rojo serve + play solo) so we know the animations were actually observed, not just written.
