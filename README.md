# Blipo

A small, cozy falling-Blip puzzle game made in Godot 4. Line up four or more Blips of the same color to clear them, wipe out every target Blip, and try not to let the box fill to the top.

Play it in your browser on itch.io: https://forestsagesarah.itch.io/

## Features

- Falling two-Blip pairs with move, rotate, soft drop, and an instant drop (double-tap Down)
- Match-four clearing with cascading chains
- Target Blips to clear for the win, and a top-out loss
- Selectable starting speed plus an in-level speed ramp
- A HUD with score, level, targets left, and speed
- Original pixel art, a dancing logo, several music tracks with an in-game selector, a volume slider and mute, and sound effects
- Intro, pause, instructions, and credits screens

## Controls

| Key | Action |
|---|---|
| Left / A | Move left |
| Right / D | Move right |
| Up / W / X | Rotate (Z rotates the other way) |
| Down / S | Soft drop (hold) |
| Down, Down | Instant drop |
| P / Esc | Pause and unpause |
| R | Restart |

On the intro screen, Left and Right change the starting speed, and any other key starts. The pause menu holds the music controls, instructions, and credits.

## How to play

Target Blips are seeded into the lower box at the start. Drop pairs and line up four or more of a color in a row or column to clear them. Clearing makes the Blips above fall, which can chain into more clears for bonus points. Clear every target to win the level. If the stack reaches the top, it is game over.

## Build from source

1. Install Godot 4.4.x (the standard build, not the .NET/C# one) from https://godotengine.org
2. Open `project.godot` in Godot.
3. Press F5 to play, or use Project, Export with the "Windows Desktop" and "Web" presets to build.

Pushes to `main` also automatically build both the Windows and Web versions via GitHub Actions (see `.github/workflows/build.yml`); the builds appear as downloadable artifacts on each run.

## Credits and license

The source code is released under the MIT License (see `LICENSE`). Art, music, sound, and fonts are original or third-party assets kept under their own terms, with full attribution in `CREDITS.md`.
