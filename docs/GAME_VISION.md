# ANTLER MAYHEM — Game Vision

> **Status: mostly design document.** Beyond the built vertical slice (the Stag
> Lodge, the Cabin World map, and Cabin levels 1–3 — see `README.md`), nothing in
> this file is implemented. This is the north star for *what the game could
> become*, written down so future work has a direction and so we do not
> re-litigate it every sprint. Do not build the remaining systems until a sprint
> explicitly asks for them.

Grab. Swing. Smash. Regret nothing.

---

## 1. Elevator pitch

A physics comedy about a very enthusiastic stag with very poor impulse control.
One-thumb slingshot control, a room full of junk, and a hook-and-swing mechanic
that turns every level into a Rube Goldberg machine you get to pull the pin on.
Sessions are measured in seconds. The joke is that you almost never aim where you
end up, and that is the point.

**Genre:** physics destruction / one-button arcade / score attack.
**Tone:** slapstick, warm, slightly chaotic. Cartoon mayhem, never gore.
**Platform:** mobile-first landscape (touch), playable with mouse/keyboard.
**Session:** 30–90 seconds per level attempt, built for "one more go".

---

## 2. Core pillars

1. **One button of control, a room of consequences.** The player only aims,
   hooks, and releases. Everything else — the swings, the collapses, the chains —
   comes out of physics. Depth comes from *when*, not *how many buttons*.
2. **Instant replayability.** Retry is always one tap and one frame away. The
   level is a toy you want to shake again, not a puzzle you solve once.
3. **Readable chaos.** Destruction is loud, but it must always look like *your
   fault*. The player should be able to trace a chain reaction back to their
   launch and laugh.
4. **Every run is a story.** No two launches land the same. The environment
   persists across the three stags of a level, so the room ends in a shape that
   is a record of what you did.

---

## 3. Fantasy & fiction

The stag is a menace, but a lovable one. It lives in a cluttered house and treats
every room as a personal playground. There is no villain and no violence — just a
stag, some gravity, and a homeowner's insurance premium.

**The Stag (player character)**
- Big antlers, bigger confidence. Comic timing in the animation, not the words.
- Personality shown through `stag_visual.gd`: squinting eyes, antler wobble,
  anticipation squash before a launch, an "uh oh" widen when a hook connects.
- Never speaks. Reacts.

**The Stag Lodge (hub)**
- A cozy, chaotic home base where the stag keeps its trophies (best scores,
  antlers earned) and picks the next room to wreck.
- Framing device for level select and progression without a spreadsheet of menus.

**Characters (future, small cast)**
- The Stag. Maybe a long-suffering roommate or a dog that reacts to the noise.
- Kept minimal on purpose — the props and the physics are the real co-stars.

---

## 4. The core loop

```
AIM → LAUNCH → HOOK ─┐
                     ├→ SWING / CARRY → RELEASE → SMASH → CHAIN → SCORE
         GRAB ───────┘
   ↺ (next stag)                                    ↓
                              THREE STAGS → LEVEL RESULTS
                                             ↓
                                     RETRY / NEXT ROOM
```

- **Aim** — drag back from the stag, release to fling. Power = pull distance.
- **Launch** — ballistic arc; a faint preview shows the *path*, never the swing.
- **Hook** — tap near a ring while airborne to catch it and swing on a fixed
  radius. The skill is **timing**: hook and release near the bottom to keep speed.
- **Grab** — tap near a loose prop to grip it and carry it instead of swinging.
  Hold a rippable prop to load tension and **rip** it loose.
- **Swing / Carry → Release** — let go to convert arc momentum (or a carried prop)
  into a straight projectile. A perfect, fast, flat release pays a bonus.
- **Smash → Chain** — direct hits, knocks, and collapses build a combo multiplier.
- **Score → Rate** — clear the room in three stags; earn up to three antlers.

**Mechanic vocabulary (things the room can be made of)**

The game is one verb ("fling the stag") meeting a box of toys. Every level is
assembled from the same small set of readable verbs. They stack in three tiers —
each tier only *adds* to the one below, and none adds a button:

**FOUNDATION — move the stag (the original loop)**
- **Launch** — slingshot fling; power = pull distance.
- **Antler hook** — catch a ring while airborne; swing on a fixed radius.
- **Release** — let go to convert swing momentum into a straight projectile.

**INTERACTION — act on the room**
- **Antler grab** — grip a loose prop while airborne on a momentum-preserving
  soft constraint; carry it into something.
- **Throw** — release while gripping to fling the prop, boosted past your speed.
- **Pull & rip** — hold a *rippable* prop until tension fills and the joint
  **rips**, releasing whatever it held.
- **Weight classes** — light / medium / heavy props respond differently to a grip.
- **Bounce & redirect** — springy pads (vertical mushroom, horizontal springboard)
  put a falling stag or prop onto a deterministic arc.
- **Chain-reaction objects** — jars, crates and the Acorn Blast Crate move the
  mayhem on for you.

**MASTERY — do it with style**
- **Perfect Release** — release a fast, flat swing near the bottom for a bonus.
- **Double Hook** — catch a second ring after releasing the first, mid-flight.
- **Trick shots** — **Stag Assist** (your wrecked prop hits the next stag) and
  **Bounce Combo** (a prop you launched chains fast).
- **Chain reactions** — deliberately trip the whole room from one launch.

| Layer | Verb | What it does |
| ----- | ---- | ------------ |
| **Foundation** | Launch | Slingshot fling; power = pull distance. |
| **Foundation** | Antler hook | Catch a ring while airborne; swing on a fixed radius. |
| **Foundation** | Release | Let go to convert swing momentum into a straight projectile. |
| **Interaction** | Antler grab | Grip a loose prop; the antlers become a carrying tool. |
| **Interaction** | Throw | Release a grip to fling the prop, boosted. |
| **Interaction** | Pull & rip | Hold a weak joint until it rips and drops what it held. |
| **Interaction** | Weight classes | Light/medium/heavy props resist a grip differently. |
| **Interaction** | Breakable supports | Hold structures up. A strong hit (or a rip) drops the shelf. |
| **Interaction** | Rolling barrels | Heavy, low-friction; a rolling barrel wrecks supports. |
| **Interaction** | Bounce / redirect | Mushroom (vertical) and springboard (horizontal) deterministic arcs. |
| **Interaction** | Breakable ropes | Hanging objects whose ropes snap under a strong hit. |
| **Interaction** | Chain-reaction objects | Jars, crates, Acorn Blast Crate that carry the mayhem on. |
| **Mastery** | Perfect Release | Bonus for a fast, flat release near the bottom. |
| **Mastery** | Double Hook | Catch a second ring after releasing the first. |
| **Mastery** | Stag Assist / Bounce Combo | Trick-shot payouts for indirect, clever destruction. |
| **Progression (later)** | Room gimmicks | Per-room twists built from the same verbs (cans, carts, scaffolding). |

The guiding constraint: **a new mechanic must be combinable with the existing
verbs, visible in the level, and usable without a new control.** If it needs a
new button, it belongs in a later, more intentional game.

---

## 5. Structure & progression

**Rooms** are the unit of content. Each room is a themed physics toy with its own
props, hazard gimmick, and layout.

The first world, **Cabin**, exists today as a three-cabin vertical slice.
Proposed world list:

| # | Room | Status | Gimmick flavor |
| - | ---- | ------ | -------------- |
| 1 | **Cabin — The Workshop** | ✅ built | Shelves, barrels, hanging sign, jars. Teaches swing/hook. |
| 2 | **Cabin — Barrel Trouble** | ✅ built | The rolling barrel and the throw; redirect by projectile. |
| 3 | **Cabin — Rip It Down** | ✅ built | A loaded shelf on a weak joint; rewards a clean rip. |
| 4 | **Grocery Store** | 📝 vision | Rolling cans, stacked produce, fragile aisle displays. |
| 5 | **Office** | 📝 vision | Chairs with wheels, filing cabinets, monitors, partitions. |
| 6 | **Museum** | 📝 vision | Precious (don't-care) vases, plinths, velvet ropes. |
| 7 | **Construction Site** | 📝 vision | Scaffolding, bricks, wet paint, heavy beams. |
| 8 | **City** | 📝 vision | Rooftops, billboards, laundry lines — the escalation finale. |

**Progression (shipped for the Cabin world)**
- Each cabin is a **three-stag** attempt with a **main objective** (reach the
  cabin's target Mayhem) and **two optional objectives** (per-cabin).
- Clearing the target earns **1 antler**; each optional objective cleared adds
  **one more**, for a maximum of **3**. Missing the target scores **0**.
- Earning an antler opens the next cabin (1 antler required — a soft gate;
  replay is always free). Locked cabins are greyed with an unlock hint.
- A **Cabin World Map** shows best score and antler stars per cabin. The
  **Stag Lodge** grows a trophy for each cleared cabin.
- Rooms 4–8 remain design only.

---

## 6. Scoring & the mayhem meter

- **Points**: direct hits, prop knocks, prop-vs-prop chains, shatters, snapping a
  breakable support, snapping a rope, and the **Golden Acorn** / **Acorn Blast
  Crate** specials. Each object has a limited payout so you cannot farm points by
  bouncing on one crate.
- **Combo**: consecutive destruction raises a multiplier (up to x10) that decays
  if nothing happens. Combo is the moment-to-moment "keep it rolling" tension.
- **Mayhem meter**: a 0→100% gauge that fills as you score within a level and
  drives escalating feedback stages (**CALM → MESSY → CHAOS → MAYHEM!**). At the
  top it celebrates the player (banner, time-punch, shake) — a big, earned "yes".
- **Antler rating (objective-based)**: an attempt is built around a **main
  objective** (reach the room's target mayhem) and **two optional objectives**
  (per-room, e.g. *trigger the Acorn Blast*, *reach a x10 combo*). Clearing the
  target earns **1 antler**; each optional objective cleared adds **one more**,
  for a maximum of **3**. Missing the target scores **0**. This rewards *how* you
  wreck the room, not just how much, and keeps the replay goal legible:
  "I got one antler; I want three."

---

## 7. Special objects

- **Golden Acorn** — a rare, obviously-special prop. Smashing it releases a firm
  radial "mayhem shove" (cartoon, not a realistic explosion), huge feedback, and
  a big score bonus. It is a skill *and* luck reward: it often goes off as part of
  a chain reaction rather than a direct hit.
- **Acorn Blast Crate** — a louder sibling: a red, pulsing crate whose detonation
  is a bigger radial shove with a wider radius. It is the headline of a "chaos
  route" and doubles as an optional objective in Cabin 1.
- **Breakable supports** — wooden posts that hold a shelf up. They read as sturdy
  and are ignored until something heavy and fast hits them; then the whole shelf
  above comes down.
- **Rolling barrels** — heavy, low-friction, circular. A barrel knocked loose rolls
  a long way and can take out supports by itself.
- **Bounce objects** — springy mushroom pads. They redirect a falling stag (or a
  prop) onto a fixed, readable arc, enabling "low route" trick shots.
- **Breakable ropes** — the hanging sign and acorn sack swing until a strong hit
  frays the rope, which transmits the snap and drops the object onto whatever is
  below.
- Future ideas: domino rows, objects that only the golden burst can reach, and
  fragile chains that drop props.

---

## 8. Map, characters & cosmetics

- **Stag Lodge** (built): the warm hub. Your selected stag idles by the fire, a
  trophy shelf fills in as you clear cabins, and **PLAY / Dressing Room /
  Settings** are one tap away.
- **Cabin World Map** (built): a short trail of cabins. Each shows best score and
  antler stars; locked cabins are greyed with an unlock hint.
- **Characters** (built, cosmetic only): **Buck**, **Mochi**, **Bruno**. They
  change the art and personality animation and *nothing else* — no stats, no
  power, no wrong choice. Picked in the Dressing Room.
- **Cosmetics (earned, optional, future)**: antler styles, fur patterns, hats,
  trail effects, launch-pad skins. Purely expressive — **never** power. Cosmetics
  should be unlockable through play first.
- A tiny supporting cast for reaction shots during results remains a future idea.

---

## 9. Monetization (later; not now)

If the game ever ships, monetization must protect the core pillar of *instant,
no-friction replay*. Guiding rules:

- **Rewarded "bonus stag"** — watch an optional ad for one extra launch in a run.
  Opt-in only, never required to clear a room.
- **Remove ads** — a one-time purchase; the respectful default.
- **Cosmetics** — earnable, optionally purchasable, never power.
- **No** energy timers, **no** pay-to-win, **no** forced interstitials between
  retries. If a decision makes "one more go" slower, it is wrong.

> This section is a placeholder of intent. No monetization code, SDKs, store
> integrations, or tracking exist in the project.

---

## 10. Audio & feel

- Sound is **sparkle + thud**: bright, punchy, cartoon. Silence is not allowed to
  sit; every impact has a voice.
- All audio is synthesized in-engine (original, licensed-free) in `sfx.gd`.
- Feel layer (shake, time-punch, hit-stop, banners, popups) is as important as
  the physics. Destruction must be *felt* before it is understood.

---

## 11. Design guardrails

- **Depth from timing, not controls.** Resist adding buttons or meters that
  compete with the slingshot.
- **Destruction is comedy, not gore.** Props are wood, glass, and produce. No
  blood, no harm to the stag.
- **Runs stay short.** A level is a toy, not a commitment.
- **Retry is sacred.** One tap, one frame, no friction, no cost.
- **Readable first.** If the player can't tell what they did, it's a bug.

---

## 12. What exists today vs. this document

| Area | In project now | In this vision |
| ---- | -------------- | -------------- |
| Three cabins (Workshop, Barrel Trouble, Rip It Down), 3 stags each | ✅ | ✅ |
| Hook / swing / smash, antler grab, throw, pull & rip, weight classes | ✅ | ✅ |
| Perfect Release, Double Hook, Stag Assist, Bounce Combo | ✅ | ✅ |
| Springboard + bounce redirectors, rip-able brackets, heavy cabinets | ✅ | ✅ |
| Score, combo, mayhem stages, objective-based antler rating | ✅ | ✅ |
| **Stag Lodge hub, Cabin World Map, results → map loop** | ✅ | ✅ |
| **Three cosmetic characters (Buck / Mochi / Bruno) + Dressing Room** | ✅ | ✅ |
| **Settings (music / SFX / vibration) + save v2 with migration** | ✅ | ✅ |
| **Procedural lounge music loop** | ✅ | ✅ (more music later) |
| **Debug mode (unlock all, instant complete, score grant, reset save)** | ✅ | ✅ |
| Golden Acorn + Acorn Blast Crate specials | ✅ | ✅ (more specials later) |
| Breakable supports, rolling barrels, bounce objects, breakable ropes | ✅ | ✅ |
| Additional worlds (Grocery/Office/Museum/Construction/City) | ❌ | ✅ |
| Earned cosmetics (antler styles, hats, trails), supporting cast | ❌ | ✅ |
| Monetization, accounts, cloud, analytics | ❌ | 📝 intent only |

