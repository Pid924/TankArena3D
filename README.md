# Tank Arena 3D

An original top-down 3D tank shooter made with **Godot 4.3**. It runs in the browser (GitHub Pages), no install needed.
Everything (tanks, walls, effects, textures) is generated in code from primitive meshes, so the project has no external assets.

## How to play

- **Move:** WASD or arrow keys (gamepad left stick works too)
- **Fire:** Space or J (gamepad A)
- **Touch:** drag on the left half of the screen to move, hold the right half to fire
- On the title screen, press **Enter** to start or **1-3** to jump to a level.

Destroy all 20 enemy tanks in each arena. You can take **3 hits**; the third one ends the game.
Flashing red tanks drop an item when you hit them.

### Terrain
| Tile | Effect |
|---|---|
| Brick | Breaks after 2 hits (1 hit at weapon level 3) |
| Steel | Only breakable at weapon level 3 |
| Water | Blocks tanks, bullets fly over |
| Bush | Hides you: enemies cannot target you |
| Ice | Slippery, hard to stop |
| High ground + ramps | Bullets from below hit the cliff; you can shoot down from above |

### Enemies
Basic (grey), Fast (orange), Heavy (purple, 4 HP), Artillery (brown, lobs shells over walls at your position: watch for the red circle), Stealth (nearly invisible, hidden from the minimap without radar).

### Items
Items appear as round picture badges (drawn in code, also shown on the minimap).

| Icon | Item |
|---|---|
| Gold star | Weapon upgrade: Lv1 faster shots, Lv2 two shots at once, Lv3 breaks steel |
| Blue shield | Shield for 10 s |
| Red heart | One extra HP (max 5) |
| Snowflake | Freezes all enemies for 8 s |
| Bomb | Destroys every enemy on the field |
| Tank on waves | Amphibious for 15 s: drive across water (a float ring appears; it never runs out while you are still on water) |
| Radar | Radar for 15 s: reveals stealth tanks on screen and minimap |

## Development

Open the folder in Godot 4.3 and press F5. Levels are text maps at the top of `scripts/main.gd` (legend in the comments), so adding a level means adding a new entry to `LEVELS`.

Run the headless smoke test:

```
godot --headless --fixed-fps 60 --script res://tests/smoke_test.gd
```

## Deployment

`.github/workflows/deploy.yml` exports the web build with headless Godot and publishes it to GitHub Pages on every push to `main`.
The export uses the single-threaded web template, because GitHub Pages cannot send the COOP/COEP headers that threaded builds need.
In the repository settings, **Pages → Source** must be set to **GitHub Actions**.
