# ANTLER MAYHEM — Vertical Slice (Cabin World, Levels 1–3)

Grab. Swing. Smash. Regret nothing.

A tiny stag launches from an old spring pad, snags teal rings with its antlers,
swings through a rickety cabin of crates, barrels and jars, then lets go and
chain-reacts half the room into splinters. One button's worth of control, a lot
of physics, and an instant retry so you can immediately do it again, worse.

This is a **feel-first prototype moving into its first real shell**: a Stag
Lodge where you pick your idiot, a small Cabin World map with **three hand-built
levels**, star ratings, unlock progression, and a save file that remembers it
all. The core question is unchanged — *does launching, hooking, swinging and
smashing a big pile of junk actually feel good, enough that you immediately want
to go again?* — but now there is a reason to go again on purpose.

The antlers are the PRIMARY tool: they **hook** rings, **grab** loose props,
**pull and rip** a weak joint apart, snag a **second ring mid-flight**, and
convert a clean swing into a **Perfect Release**. On top of that:

- **Antler Grab** — while airborne, press near a grabbable prop (barrel, sack,
  plank, jar, weak bracket) to grip it. The grip is a momentum-preserving soft
  constraint: neither body teleports, so it reads as *carrying*, not snapping.
- **Throw** — release while holding to fling the prop harder than you were moving
  (`THROW_BOOST`). Grab a rolling barrel and throw it where you want it.
- **Pull & Rip** — grip a **rippable** prop and the antlers load it with tension;
  fill the meter and the joint **rips**, releasing whatever it was holding (the
  weak bracket dropping the shelf).
- **Weight classes** — light / medium / heavy props respond differently to a grab,
  so a heavy cabinet resists where a barrel follows.
- **Perfect Release** — let go near the bottom of a fast, flat swing for a bonus
  and a distinct flash.
- **Double Hook** — catch a second ring after releasing the first for a big
  trick-shot payout.
- **Contextual trick shots** — **Stag Assist** (your wrecked prop hits the next
  stag) and **Bounce Combo** (a prop you launched chains fast).

The long-term shape of the game lives in [`docs/GAME_VISION.md`](docs/GAME_VISION.md).

---

## The vertical slice

```
LODGE ──PLAY──▶ CABIN WORLD MAP ──pick──▶ LEVEL ──results──▶ MAP (next cabin)
  ▲                                            │
  └─────────────── dressing room / settings ◀──┘
```

- **Stag Lodge** — the home screen. Your selected stag idles by the fire and a
  trophy shelf fills in as you clear cabins. **PLAY** (to the map), **Dressing
  Room**, **Settings**.
- **Cabin World Map** — a short trail of three cabins. Each shows its **best
  score** and **antler stars** (0–3). Locked cabins are greyed with a hint:
  earn an antler in the previous cabin to open the next.
- **Levels** — pick a cabin and play it. Each is three stags, one main objective
  (a Mayhem target) and two optional objectives worth an extra antler each.
- **Results** — total mayhem, best, biggest combo, the objective checklist, your
  antler rating, and **NEW BEST** / **CABIN UNLOCKED** callouts. **RETRY** reloads
  instantly; **WORLD MAP** returns to the trail.
- **Dressing Room** — **Buck**, **Mochi**, **Bruno**. Cosmetic only: they change
  the art and nothing else, so there is no wrong choice and no stat grind.
- **Settings** — Music / SFX / Vibration toggles. Everything persists.

### The three cabins

| # | Code | Name | Theme | Target | Optional objectives |
| - | ---- | ---- | ----- | ------ | ------------------- |
| 1 | 1-1 | THE WORKSHOP | workshop | 5,000 | Land a Perfect Release · Antler Grab (or 5+ chain) |
| 2 | 1-2 | BARREL TROUBLE | cellar | 4,200 | Throw a grabbed object · Barrel chain reaction |
| 3 | 1-3 | RIP IT DOWN | attic | 6,000 | Rip a weak joint with antler tension · Perform a Double Hook |

The three levels teach the antler toolkit in order — swing/hook, then grab/throw,
then rip/double-hook — and each is authored with more than one viable route
(`HIGH SWING`, `LOW BOUNCE/SPRING`, `RIP`, `DOUBLE HOOK`). Level 1 is the original
four-route sandbox; Level 2 is built around the **barrel** and the **throw** verb;
Level 3 hangs a loaded shelf on a breakable rope and rewards a clean **rip**.

### Progression & save

- Antler rating per run: **0** if you missed the target, otherwise
  `1 + optional objectives completed` (max **3**).
- Earning an antler in a cabin unlocks the next one (1 antler required).
- The Lodge trophy shelf shows one decoration per cleared cabin (the "Lodge that
  grows" — a light, honest progression hook).
- Everything is saved to `user://antler_mayhem.cfg` (v2). Old single-level saves
  are migrated automatically, and corrupt/partial saves fall back safely to
  defaults instead of crashing.
- A **debug mode** (gated to debug builds, or unlocked in the save) lets you open
  all cabins, grant score, and wipe the save — see below.

---

## Run it

Requires **Godot 4.x**. Built and tested on **Godot 4.7.2.stable.official.ed1daf0bf**
(macOS, Apple Silicon, Metal). The project targets the lowest compatible
feature set (`config/features=PackedStringArray("4.3")`) so it loads on 4.3+.

### From the editor
1. Open Godot, choose **Import**, and select this folder's `project.godot`.
2. Press **F5**.

### From the terminal (macOS)
```sh
godot --path .            # run
godot --path . --editor   # open the editor
```
If `godot` isn't on your `PATH`:
```sh
/Applications/Godot.app/Contents/MacOS/Godot --path .
```

The main scene is `res://scenes/app/app.tscn` (the App shell). Any level can also
be launched directly for testing, e.g. `res://scenes/main/main.tscn`.

---

## Controls

| Action | Keyboard / Mouse | Touch |
| --- | --- | --- |
| Menu / select | Click a button | Tap a button |
| Launch | Drag from the stag **away** from the target and release (slingshot) | Same, with a finger |
| Hook | While airborne, **press** near a glowing teal ring | **Tap** near a ring |
| Grab | While airborne, **press** near a glowing loose prop (barrel, sack, plank, jar, bracket) | **Tap** the prop |
| Throw | **Release** the press while holding a prop | Lift finger |
| Pull & Rip | Keep **holding** a gripped **rippable** prop to load tension until it rips | Keep holding |
| Let go | **Release** the press while hooked | Lift finger |
| Retry | **R** or the on-screen **RETRY** button | RETRY button |
| Debug overlay | **F3** (debug builds) | — |

Pull farther to launch harder. A dotted arc previews the ballistic path; it does
**not** show the swing. A press resolves to **hook** or **grab** whichever is
closer (a ring anchors with a small bias), so there is still only one button.

---

## The loop

`AIM → LAUNCH → HOOK → SWING → RELEASE → SMASH → CHAIN → SCORE`
`        ↺ (next stag)                          → THREE STAGS → RESULTS → MAP`

- **Aim**: slingshot drag. Power scales from a gentle lob to a full-power fling.
- **Launch**: the stag leaves the spring pad; gravity takes it.
- **Hook**: press near a teal ring. The antlers catch it and you swing on a
  fixed-radius arc. Momentum is preserved, so **when** you hook and release is
  the whole skill: hook at the bottom and you keep your speed, hook at the apex
  and you stall. Release a fast, flat swing near the bottom for a **Perfect
  Release** bonus.
- **Grab**: press near a loose prop instead of a ring and the antlers **grip** it
  on a soft, momentum-preserving constraint. The prop follows you and can hit
  whatever is below. Hold a **rippable** prop long enough and the antlers **rip**
  its joint, dropping the thing it was holding.
- **Release / Throw**: let go mid-swing to convert arc speed into a straight-line
  projectile. Let go while gripping to **throw** the held prop, boosted past your
  own speed.
- **Smash / Chain**: hit props directly, knock them into each other, break glass
  and wood, snap a support out from under a shelf, fracture a rope so a hanging
  object drops, or rip a weak bracket and tip a whole shelf. Everything collides
  with everything. A prop you launched that hits the *next* stag is a **Stag
  Assist**; a fast prop-to-prop chain is a **Bounce Combo**.
- **Score**: direct hits, knocks, chain reactions, shatters, support/rope snaps,
  antler **grabs**, **Perfect Releases**, **Double Hooks**, **rips**, assists and
  the specials build a combo multiplier (up to **x10**) that decays if you dawdle.
- **Next stag**: when the stag settles, the level respawns on the pad after a
  short beat (`RESPAWN_DELAY` 0.55). The spent stag **stays in the room as a
  passive obstacle** — it can bump props around, but it cannot score or hook (so
  it never feeds the meter).
- **Results**: after three stags, a results panel shows total mayhem, best score,
  biggest combo, an **objective checklist**, your **antler rating** (0–3), and any
  unlock earned. **RETRY** reloads the room endlessly; **WORLD MAP** returns to
  the cabin trail.

Scoring is deliberately conservative: each object can only pay out a limited
number of times, so you can't farm points by bouncing on the same crate forever.
Scoring is also **armed only after launch**, so objects settling at level start
never award points or noise — and the spent stags from earlier in the level do
not feed the meter while the next stag sits idle on the pad.

---

## Project layout

```
project.godot                  # 1280x720, canvas_items stretch, landscape, 60 Hz physics
scenes/
  app/app.tscn                 # entry scene: the App shell (Lodge/Map/Closet/Settings/Level)
  main/main.tscn               # the level runner (any level, built from LevelData)
  meta/lodge.tscn              # Stag Lodge home screen
  meta/world_map.tscn          # Cabin World map
  meta/closet.tscn             # Dressing Room (characters)
  meta/settings.tscn           # Settings
  stag/stag.tscn
  environment/hook_anchor.tscn
  objects/physics_object.tscn
scripts/
  app/app.gd                   # screen stack, fade transition, music, debug tools
  audio/sfx.gd                 # procedural SFX + a generated lounge music loop
  core/
    progress.gd                # autoload: levels, antlers, settings, save v2 (+migration)
    level_data.gd              # autoload-free model: the 3 level definitions (class Levels)
  input/pointer_input.gd       # unified mouse + touch abstraction
  gameplay/
    main.gd                    # level runner: builds any level, state machine, scoring
    stag.gd                    # RigidBody2D + antler tether + grab constraint
    stag_visual.gd             # vector stag art + personality animation
    aim_controller.gd          # slingshot + trajectory preview
  meta/
    lodge.gd / world_map.gd / closet.gd / settings.gd
  environment/
    hook_anchor.gd             # teal ring visuals + tether line
    background.gd              # backdrop art (per-level palette themes)
    environment.gd             # floor / wall / ceiling colliders
  objects/physics_object.gd    # props: crates/barrels/jars/planks/signs/golden +
                               #   supports/ramps/bounce/spring/blast/sacks/
                               #   bracket/cabinet (weight classes, grab, rip, tension)
  scoring/score_manager.gd     # points, combo (x10), dedupe, mayhem meter
  ui/
    hud.gd                     # data-driven in-game HUD: score, mayhem, stags, objectives, results
    ui_kit.gd                  # shared palette + custom buttons/labels for the meta UI
  effects/fx.gd                # particles, popups, banners, shake, time punch
  debug/debug_overlay.gd       # F3 overlay + debug hotkeys
tools/
  drive_test.gd / .tscn        # headless mechanic + objective + 3-stag gameplay test
  flow_test.gd  / .tscn        # screen-flow + progression + settings test
  levels_test.gd / .tscn       # builds every level headless, checks prop/anchor counts
docs/
  GAME_VISION.md               # long-term design (document only, not built)
```

---

## Tech notes

- **App shell owns navigation.** Levels never know about each other; the level
  runner asks `/root/App` to retry or return to the map. The same level scene
  still runs **standalone** (the test tools do exactly that), and its
  `level_id` is set *before* it enters the tree so `_ready` can build it.
- **Data-driven levels.** `scripts/core/level_data.gd` (`class_name Levels`) is
  the single read-only description of WHAT a level is (props, anchors, hanging
  objects, objectives, theme). `main.gd` is the one engine that builds any of
  them. Adding a cabin is authoring a dictionary, not writing new gameplay.
- **Mobile-first landscape**, 1280x720 design resolution, `canvas_items` stretch
  with `keep` aspect and `gl_compatibility` renderer for broad device support.
- **No third-party assets.** All art is vector drawing via `draw_*` calls and
  all sound — including the music loop — is synthesized into `AudioStreamWAV` at
  startup in GDScript. Nothing to license, nothing to download.
- **Backdrop themes.** One backdrop script, several palettes (workshop / cellar /
  attic), so the three cabins read as different places at a fraction of the cost.
- **Custom tether constraint.** This engine build's native `PinJoint2D` /
  `DampedSpringJoint2D` are unstable under gravity (a pinned body sinks and the
  arm stretches without bound; `RopeJoint2D` is absent). The antler tether and
  the hanging ropes are therefore solved directly in `_integrate_forces` as a
  rigid distance constraint: hold the point on a fixed-radius circle and cancel
  only the radial velocity. This is stable, deterministic, and preserves the
  tangential swing, so releases feel crisp. See `scripts/gameplay/stag.gd`.
- **Debug mode.** On debug builds (or when unlocked in the save): **F3** toggles
  the overlay in a level, **F4** instantly completes the level, **F5** unlocks
  all cabins, **F6** adds 10,000 score. In the Lodge/Map/Settings screens **F3**
  shows a debug bar (unlock all, +score, reset save). None of this is reachable in
  a normal play session by default.

---

## Testing

There is no visual/GUI harness in this environment, so automated verification is
headless and physics-driven. From the repo root:

```sh
# Parse / import everything (catches syntax and scene errors)
godot --headless --path . --editor --quit

# Boot the real game for ~400 frames and exit (catches runtime errors)
godot --headless --fixed-fps 60 --path . --quit-after 400

# Drive the whole 3-stag level with synthetic input (mechanics + lifecycle)
godot --headless --fixed-fps 60 --path . res://tools/drive_test.tscn

# Drive the meta flow: Lodge -> Map -> Closet -> Settings -> Level -> results
godot --headless --fixed-fps 60 --path . res://tools/flow_test.tscn

# Build every level and check its props/anchors/objectives
godot --headless --fixed-fps 60 --path . res://tools/levels_test.tscn
```

The **drive test** runs in two layers. First, deterministic **mechanic + objective
unit checks** against the real scene at boot:

- bounce pad produces the exact deterministic arc (`tangential*0.82 + normal*1010`),
- a breakable support shatters under a strong hit,
- a breakable rope snaps and detaches,
- the Acorn Blast Crate fires its special burst,
- a **passive** spent stag emits no gameplay signals (cannot farm score),
- the **springboard** redirect is deterministic and differs from the mushroom,
- **antler grab** gates correctly (grabbable only, in-range only), preserves
  momentum under the soft constraint, and **throw** boosts the released prop,
- **rip** holds under partial tension and releases the held structure at full
  tension (non-rippable props ignore tension),
- **Perfect Release** fires for a fast, flat swing and not for a vertical one,
- **Double Hook** pays at least 500 for two rings in one launch,
- **contextual bonuses** pay for Stag Assist (≥250) and Bounce Combo (≥200),
- the level contains the required pieces and ≥4 grabbable props,
- the objective wiring and the antler-rating model (`antlers_for`).

Then it drives the **whole 3-stag level** with synthetic input: aim → launch →
hook → swing → release → smash → settle → next stag → results → retry. It asserts
the lifecycle: 3 stags consumed (`stags_left` 3→2→1→0), spent stags persist as
passive obstacles, score never decreases and props are never resurrected between
stags, level end fires, best score saves, and a clean Retry restores 3 stags /
score 0 / all props.

The **flow test** boots the real App scene and drives navigation between every
screen, checks that a level receives its id before `_ready` (so the right cabin
builds), verifies the unlock rule (1 antler in cabin 1 opens cabin 2, cabin 3
stays locked), and confirms a settings toggle survives a save/reload round-trip.

The **levels test** builds all three cabins headless and asserts each one
produces the expected props, anchors and objectives — so a typo in the level
data fails in CI instead of only when someone scrolls to cabin 3.

Headless verification confirms logic and physics run without errors; it cannot
confirm that the game *looks* or *sounds* right. That needs eyes and ears.

---

## Known limitations (honest list)

- The meta layer is a **slice, not a full game**: one world, three cabins, three
  characters, three settings toggles. There is no pause menu, no level select
  beyond the map, and no shop.
- **Progression is intentionally shallow**: earn antlers → unlock the next cabin.
  The Lodge trophy shelf and star ratings are the only long-term hooks.
- **Characters are cosmetic only** — Buck/Mochi/Bruno change the art, never the
  gameplay. This is a deliberate choice, not an unfinished system.
- **Only cabin 1 has been playtested for feel.** Cabins 2 and 3 are authored and
  verified to build and play, but their difficulty, targets (4,200 / 6,000) and
  prop layouts are first passes and expected to need tuning.
- Tuning is eyeballed, not playtested on real hardware. Mobile touch, small
  screens and real frame pacing have **not** been validated.
- The compact rooms are very chain-reaction-friendly: a full-power shot can trip
  most of a room in one go, so the main objectives may prove easy and the
  optional objectives the real differentiator.
- Headless verification confirms logic and physics run without errors; it cannot
  confirm that the game *looks* or *sounds* right.

## I want your feedback on

1. **Antler grab** — does pressing a glowing prop to grip it read as *using the
   antlers*, or does it feel like a second unrelated button?
2. **Grab vs hook** — is the single press resolving to nearest hook-or-grab
   (with a ring bias) intuitive, or do you occasionally grip when you meant to
   swing?
3. **The meta loop** — does Lodge → Map → three cabins → results feel like a real
   game wrapping the feel test, or is it friction between you and the next fling?
4. **Cabin progression** — is "earn an antler to open the next cabin" the right
   gate? Is the Lodge trophy shelf enough of a reason to replay a cabin?
5. **Level identity** — do BARREL TROUBLE and RIP IT DOWN feel like *different*
   cabins with different tools, or like the same room with the props moved?
6. **Characters** — is cosmetic-only Buck/Mochi/Bruno enough variety, or do you
   expect at least a small gameplay difference?
7. **Difficulty targets** — are 5,000 / 4,200 / 6,000 in the right ballpark, and
   are the optional objectives (Perfect Release, Grab, Throw, Rip, Double Hook)
   clear goals you can chase on purpose?
