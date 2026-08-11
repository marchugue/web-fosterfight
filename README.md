# FosterFight

An original 2D arcade fighting game built with **Godot 4.x (.NET / C#)**. Inspired by
the *feel* of classic arcade fighters — not a copy of any of them. No copyrighted
characters, art, audio, code, or trademarks are used anywhere in this project;
every character, move, and asset reference here is original.

---

## 1. Project overview

Two fighters ("programs," themed loosely around university degree programs —
BSIT, BSBA, BSME, BSED — as a fun, original hook) face off in best-of-3 rounds.
Each round is a standard knockout-or-timer fight with light/heavy punches and
kicks, a chargeable special attack, combo tracking, and a round timer. Results
feed a local SQLite-backed leaderboard.

**Flow:** `MainMenu → ProgramSelect (match mode) → CharacterSelect → Battle → Result`,
with `Leaderboard` reachable from the menu, character select, and result screens.

---

## 2. Folder structure

```
FosterFight/
  Assets/                  Sprites, animations, audio, fonts (art not included — see §8)
  Scenes/                  One .tscn per screen, plus reusable Components/
  Scripts/
    Managers/              App-flow & match-flow singletons and orchestrators
    Character/             Single-responsibility fighter components
    UI/                    Thin screen controllers (event wiring only)
    Database/              SQLite access, isolated behind repositories
    Utilities/             Constants, input abstraction, extension methods
  Resources/               Data-driven .tres content (characters, attacks, config)
  Database/                Reserved for local reference; the live DB lives in
                            the OS user-data folder at runtime (see §6)
  FosterFight.csproj
  project.godot
```

---

## 3. Requirements

- **Godot 4.3+ (.NET / Mono build)** — the standard build does not run C#.
- **.NET SDK 8.0** on your PATH (Godot's .NET build compiles against it).
- No other external dependencies except the one NuGet package below.

---

## 4. How to run

1. Install Godot 4.3+ **.NET**, and the .NET 8 SDK.
2. Open this folder in Godot (`project.godot` at the root). Godot will prompt
   to build the C# project on first open — let it.
3. Press **Run** (F5). `MainMenu.tscn` is the configured main scene.
4. On first run, `Microsoft.Data.Sqlite` will restore via NuGet automatically
   as part of the .NET build (see `FosterFight.csproj`).

### Controls (local two-player, one keyboard)

Both profiles are defined in `project.godot [input]` and read via
`InputHelper.ReadPlayerOne()` / `ReadPlayerTwo()` — see
`Constants.Actions.PlayerOne` / `PlayerTwo` for the action names.

| Action         | Player 1      | Player 2       |
|----------------|---------------|----------------|
| Move Left      | `A`           | `←`            |
| Move Right     | `D`           | `→`            |
| Jump           | `W`           | `↑`            |
| Crouch         | `S`           | `↓`            |
| Light Punch    | `U`           | `,`            |
| Heavy Punch    | `I`           | `.`            |
| Light Kick     | `J`           | `/`            |
| Heavy Kick     | `K`           | `'`            |
| Special Attack | `L`           | Right `Shift`  |
| Pause          | `Esc` (shared)|                |

Rebind any of these from Godot's **Project → Project Settings → Input Map**
— the action names are the source of truth, not the physical key, so
rebinding there needs no code changes.

---

## 5. How to add a new character

This is intentionally code-free:

1. Duplicate one of the files in `Resources/Characters/` (e.g. `BSIT.tres`).
2. Edit its `DisplayName`, `Id`, and stats.
3. Build the animation set **in the Godot editor**, not code: select the
   character's `AnimatedSprite2D` (or work in a scratch scene), open the
   **SpriteFrames** panel (`Animation → New SpriteFrames`), and either:
   - add each frame as an **individual image**, one at a time, per
     animation — good when your frames aren't laid out on a shared sheet, or
   - load a sprite-sheet texture into the panel and use its built-in
     **"Add frames from a Sprite Sheet"** grid tool, which lets you set rows/
     columns/margins visually and preview exactly which cells get sliced.

   Either way, name the animations `idle`, `walk`, `jump`, `punch`, `kick`,
   `special`, `ko`. Light and heavy punches share the `punch` track; light
   and heavy kicks share `kick` — only their `AttackData` timing/knockback
   (in `Resources/Attacks/`) and the character's own `AttackDamageLight` /
   `AttackDamageHeavy` differ, so you only need one animation per pair.
   (If you'd rather use different track names, remap them in the
   character's `.tres` under `AnimationNames` instead of renaming tracks.)
4. Save that SpriteFrames as its own `.tres` and assign it to the
   character's `Frames` field (and a portrait image to `Portrait`).
5. Save the character `.tres` inside `Resources/Characters/`.
   `CharacterSelectUI` scans that folder at runtime, so the new fighter
   appears automatically — nothing else needs to change.

There is **no runtime slicing code** — `CharacterAnimation` just assigns
whatever `SpriteFrames` you built straight onto the `AnimatedSprite2D`.
What you see in the editor's animation preview is exactly what plays.

See `FosterFight_Character_Art_Requirements.md` for the full frame-count
guidance (ranges per animation, timing budget for punch/kick, portrait
sizing) if you're producing art rather than importing existing frames.

---

## 6. How the leaderboard works

- **SQLite is used ONLY for the leaderboard.** Gameplay state lives in memory;
  configuration lives in `Resources/Config/GameSettings.tres`. No save files.
- `SQLiteManager` owns the connection string and schema (`Players` and
  `Matches` tables), created automatically on first run at
  `user://leaderboard.db` (Godot's per-OS user data directory — this keeps
  the database writable even though the rest of the project is read-only
  after export).
- `PlayerRepository` holds aggregate stats (wins, losses, matches played,
  highest combo, fastest win). `MatchRepository` appends one row per
  finished match to a history log. Both use parameterized queries exclusively.
- `LeaderboardManager` (autoload) is the *only* class gameplay/UI code talks
  to — `MatchManager` calls `RecordMatchResult(...)` once a match ends, and
  `LeaderboardUI` calls `GetTopPlayersByWins/Combo/FastestWin(...)`.
- Player identity is simply the winning/losing character's `DisplayName` —
  there's no account system in scope. Swapping in real player-name entry
  is a small addition to `CharacterSelectUI` and `MatchManager.EndMatch`.

---

## 7. Facing & positioning

- **Facing always tracks the opponent** — not movement input. Every physics
  frame, `CharacterController` compares X positions and pushes the result
  into `Movement.SetFacing()`, which flips the sprite and mirrors the
  Hitbox's offset (`CharacterCombat.SetFacing`). This is what lets a fighter
  walk backward (retreating) while still facing — and being able to attack
  — forward, like a classic arcade fighter rather than a generic platformer.
- **Pushbox** (fighters can't overlap each other) needs no dedicated system —
  both `CharacterController`s are `CharacterBody2D`s sharing collision
  layer/mask `1` in `Character.tscn`, so Godot's own `MoveAndSlide()`
  collision resolution already keeps them from passing through one another.
- **Stage/corner bounds** — `CharacterController.ClampToStageBounds()` keeps
  both fighters within `Constants.Stage.MinX/MaxX` after each physics step,
  so neither can be pushed off-screen or through a stage edge. Adjust those
  two constants (or make them per-stage once multiple stages exist) to match
  your actual playable width.

---

## 8. Art & audio

No sprite frames or audio files are included — only the folder structure
(`Assets/Sprites/`, `Assets/Audio/`, etc., each with a `.gitkeep`) and the
data-driven pipeline that consumes them (see §5 for characters, §9 for UI).
Every system that needs a texture or clip (character animations, portraits,
button hover/press feedback, health/energy bar art, BGM/SFX) reads it from
an `Export` field or an `AudioManager` call — no script changes required to
skin the game once you have art.

---

## 9. UI theming & animation hooks

Two component scenes exist specifically so designers can style/animate the
UI entirely from the editor, without touching C#:

**`Scenes/Components/AnimatedButton.tscn`** — every button in every menu
(`MainMenu`, `ProgramSelect`, `CharacterSelect`, `Result`, `Leaderboard`) is
an instance of this scene, not a raw `Button`. It *is* a `Button`
(`AnimatedButtonComponent : Button`), so nothing else changes — existing
`GetNode<Button>(...)` calls keep working. It ships with an empty child
`AnimationPlayer`; open any button instance, select that `AnimationPlayer`,
and add animations named:

| Animation name | Plays when |
|---|---|
| `hover` | mouse enters the button |
| `unhover` | mouse exits (falls back to `RESET` if you have one) |
| `pressed` | the button is pressed down |
| `activate` | a full click completes |

Any name you don't create is simply skipped — add only what you need.

**`Scenes/Components/HealthBar.tscn`** — the `Bar` node is a
`TextureProgressBar`, not a themed `ProgressBar`, so it's fully art-driven.
Select it in the Inspector and assign:

- `Texture Under Texture` — the empty/background bar art
- `Texture Progress Texture` — the fill that grows/shrinks with health
- `Texture Over Texture` *(optional)* — a frame/overlay drawn on top

There's also a **`DelayBar`** — a second `TextureProgressBar` drawn *behind*
`Bar`. On damage, `Bar` snaps to the new value instantly while `DelayBar`
holds at the pre-hit value for a beat, then drains down to match — the
trailing sliver between them reads as "how much you just lost." Give
`DelayBar` its own `Texture Progress Texture` (traditionally a lighter or
brighter color than the main bar's fill, e.g. white or yellow, so the trail
is visible peeking out from behind it) — no script changes needed, the
hold/drain timing is tunable via `Constants.UI.HealthDelayHoldSeconds` /
`HealthDelayDrainSeconds`. Healing and round resets skip the delay effect
and snap both bars together.

The two energy bars in `Battle.tscn` (`PlayerOneEnergyBar` /
`PlayerTwoEnergyBar`) are plain `TextureProgressBar`s (no delay bar) for the
same texture-driven reason — assign textures to them the same way.

---

## 10. Notes on additions beyond the original file list

Everything in the requested folder structure exists as specified. A handful
of small, clearly-scoped files were added because they're structurally
required for the requested scenes/resources to be anything other than inert
placeholders (which the brief explicitly disallows):

- `Scripts/Character/CharacterData.cs`, `AttackData.cs`,
  `Scripts/Utilities/GameSettingsData.cs` — Godot `.tres` Resources need a
  backing C# class to define their schema. These *are* the character/attack/
  config system described in the brief, just given a home.
- `Scripts/UI/ProgramSelectUI.cs` — controller for `ProgramSelect.tscn`
  (match-mode select), which had no dedicated script in the original list.
- `Scripts/UI/HealthBarComponent.cs`, `TimerComponent.cs` — small
  controllers for `Scenes/Components/HealthBar.tscn` and `Timer.tscn` so
  those reusable components are functional rather than unscripted.
- `Scripts/UI/AnimatedButtonComponent.cs` and
  `Scenes/Components/AnimatedButton.tscn` — the animatable button described
  in §9. Every button in every menu instances this scene.

No other files were added or renamed.

---

## 11. Future improvements

- AI-controlled CPU opponent (the "Player vs CPU" button on `ProgramSelect`
  is present and wired for navigation, just disabled until an AI controller
  exists — a natural drop-in replacement for `InputHelper.ReadDevice`).
- Controller/gamepad support — `InputHelper.ReadDevice(deviceId)` exists as
  a separate entry point from the two keyboard profiles for exactly this
  purpose (it currently falls back to Player One's keyboard bindings).
- Additional stages/backgrounds, hit-spark/VFX layer, screen shake
  (`GameSettingsData.ScreenShakeEnabled` is already reserved for this).
- Online multiplayer — the signal-driven, data-owning-its-own-state design
  of `CharacterHealth`/`Energy`/`Combo`/`Combat` was chosen specifically so
  those states could later be replicated without restructuring gameplay code.
