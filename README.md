# One More Bell: Resonance

![A run through the Rain Arcade](screenshots/gameplay.png)

A short, replayable 2D platformer set inside a rain-soaked clocktower. A little bellkeeper follows an unfamiliar echo inside. To find the way out, you have to make the tower answer back.

Ring your handbell to turn nearby glass ledges solid for a few seconds, use bronze platforms to launch upward and recharge, and time delayed echoes to reach the upper routes. Ringing again will not extend a lit ledge's lifetime. A premature press gets a head shake without adding another cooldown penalty.

## What’s inside

- Five distinct courses, from the Rain Arcade to the Great Belfry, with branching routes and different obstacle combinations.
- Violet, diamond-marked ledges that respond to their linked echo fixture. Ring before a launch to have the next landing ready when you arrive.
- Four bellkeepers with running strides, rising and falling poses, weighted landings, bell swings, blinking eyes, and moving scarves.
- A brief visual prologue when you select **Play**, and an escape ending after all five courses.
- Three optional echo notes per course, individual best times, all-notes records, medals, and an optional personal-best ghost.
- Pendulums, forged spike racks, pistons, and brass steam pipes. Pipe gauges rise, outlets rattle, and wisps escape before the full burst. Spike and pipe designs vary between courses. A fall or hit restarts the course from the beginning; there are no checkpoints.
- Adjustable audio, bell timing, movement, ghost visibility, character appearance, display mode, resolution, VSync, parallax, camera shake, flashes, particles, contrast, and keyboard bindings.

| Prologue | Escape |
| --- | --- |
| ![The bellkeeper enters the tower](screenshots/prologue.png) | ![The tower exit at dawn](screenshots/escape.png) |

## Play

Open [`project.godot`](project.godot) in **Godot 4.7.2** and press **F5**. On Windows, you can also run [`PLAY.cmd`](PLAY.cmd); it looks for Godot on your PATH or in the standard WinGet installation location, imports the assets, and launches the game. The first import may take a moment.

To check the Windows asset import without opening the game, run `PLAY.cmd --verify` from Command Prompt.

Choose **Play** for the story route or **Courses** to replay a level directly. Cutscenes can be skipped with Space, Enter, Esc, a controller Start button, or the on-screen Skip button.

## Controls

| Action | Keyboard | Controller |
| --- | --- | --- |
| Move | A/D or arrow keys | Left stick |
| Jump | Space or Up | A |
| Ring | J or Shift | X |
| Pause | Esc | Start/Options |

Hold Jump for a higher leap, or release it for a short hop. The primary keyboard bindings can be changed in Settings.

## Bell timing

The handbell reaches 340 world pixels; an echo reaches 520. Ordinary glass lasts 3.6 seconds with the default settings. Violet shortcut glass lasts about 2.45 seconds and only responds to its connected fixture, whose pulse follows a 0.62-second wind-up. Fine lines connect the fixture to its ledges, and its prongs close before it releases the pulse. A dim fixture is still resetting.

Lit ledges cannot be refreshed. Watch for the final blink, and commit when the next landing will still be there. Bronze launches restore your handbell immediately, but they do not reset an echo fixture. The lower routes give you places to stop; the upper routes reward planning ahead.

## Records and settings

The five courses can be replayed individually. Each keeps a best time and a separate all-notes time. Custom bell, glass, or movement-speed settings are available, but runs using them do not set timed records. Saves and settings are stored in Godot’s `user://one_more_bell_resonance.cfg`, outside the project folder. The revised routes use a separate record set, so older times and ghosts do not compete against a changed course. Your settings and completed courses remain; the old records are retained in the save file.

The game supports windowed, fullscreen, and borderless modes, with resolutions up to 2560 × 1440. Parallax makes distant scenery move more slowly than the playable course to give the tower depth; it can be disabled in Settings.

## Tests

After importing the project, run these with Godot from the project directory:

```text
godot --headless --path . --script res://tools/test_all.gd
godot --headless --path . --script res://tools/test_timing.gd
godot --headless --path . --script res://tools/test_hazard_art.gd
godot --headless --path . --script res://tools/route_bot.gd
```

The test harness disables save loading and writing, so it cannot overwrite personal records or settings. `test_all.gd` covers controls, collisions, settings, retries, and story transitions. `test_timing.gd` checks pulse reach, expiry, echo timing, and cosmetic-only character poses. `test_hazard_art.gd` validates every spike and pipe mesh through a full steam cycle, including high contrast. `route_bot.gd` replays recorded inputs from spawn to exit, collecting every note without deaths on all five courses. It also tests mistimed ringing against the same movement inputs.

