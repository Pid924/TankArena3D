# Tank Arena 3D

An original top-down 3D tank shooter made with **Godot 4.3**. It runs in the browser (GitHub Pages), no install needed.
Everything (tanks, walls, effects, textures) is generated in code from primitive meshes, so the project has no external assets.

## How to play

Ten levels, 20 enemy tanks each. New enemy types are introduced gradually: tough tanks from level 1, hovercraft from level 5, twin guns from level 6, flamers from level 7 and item thieves only from level 8. Each player can take **3 hits**. Before every level a briefing screen shows which enemies are coming and what they do.
The menu has 1-player and 2-player modes, a start-level picker and four languages (Thai, English, German, Dutch) picked with flag buttons.

| | Player 1 | Player 2 |
|---|---|---|
| Move | WASD | Arrow keys |
| Fire | Space / J | Enter / Right Ctrl / Numpad 0 |
| Gamepad | first pad | second pad |

In 1-player mode both key sets control the same tank, and on touch screens you drag on the left half to move and hold the right half to fire.
Every item affects both players.

### Terrain
| Tile | Effect |
|---|---|
| Brick | Breaks after 2 hits (1 hit at weapon level 3) |
| Steel | Only breakable at weapon level 3 |
| Water | Blocks tanks (bullets fly over). With the amphibious item you can escape across it |
| Bush | Hides you: enemies cannot target you |
| Ice | Slippery, hard to stop |
| High ground + ramps | Bullets from below hit the cliff; you can shoot down from above |

### Enemies
| Enemy | Ability |
|---|---|
| Scout (grey) | Drives around and shoots |
| Racer (orange) | Very fast, fast bullets |
| Bulwark (purple) | Slow, 4 HP |
| Mortar (brown) | Lobs shells over walls at your position (red circle) |
| Ghost (dark blue) | Nearly invisible and hidden from the minimap; shows up when close or when it fires |
| Hovercraft (teal) | Crosses water |
| Mine Layer (olive) | Drops visible landmines that last 8 s; driving over one costs 1 HP |
| Twin Gun (steel blue) | Fires forward and backward at the same time |
| Flamer (red) | Switches a flamethrower on and off at random; the fireball one cell in front hurts you |
| Thief (pink) | Drives to items and steals them; a stolen item has the opposite effect on you |

Tanks #3, 7, 11, 15 and 19 flash red and drop an item when hit. Later tanks in each wave have more HP (+1 from #8, +2 from #15, +1 more from level 5 and +2 from level 9).

### Items
| Icon | Item | If a thief steals it |
|---|---|---|
| Gold star | Weapon upgrade: Lv1 faster shots, Lv2 two shots, Lv3 breaks steel | Weapon level -1 |
| Blue shield | Shield 10 s | Enemies shielded 8 s |
| Red heart | +1 HP (max 5) | Every enemy +1 HP |
| Snowflake | Enemies frozen 8 s | You are frozen 3 s |
| Bomb | Destroys all enemies on the field | The blast hits you |
| Tank on waves | Drive across water 15 s | Enemies cross water 12 s |
| Flame | Flamethrower 7 s: a fireball one cell in front burns enemies (you can still shoot) | All enemies get flamethrowers 7 s |
| Lightning | Speed boost 10 s | Enemies faster 10 s |
| Hourglass | Enemies slowed 10 s | You are slowed 6 s |

## Sound

All sound effects and jingles are synthesized in code at startup (`scripts/sfx.gd`), so there are no audio files. Press **M** (or the speaker button on the title screen) to turn sound on or off; the choice is remembered.

## Development

Open the folder in Godot 4.3 and press F5. Levels are text maps at the top of `scripts/main.gd` (legend in the comments), so adding a level means adding a new entry to `LEVELS` and a `lv_N` name in `scripts/i18n.gd`. All game text lives in `scripts/i18n.gd`. Thai text uses Noto Sans Thai (`fonts/`, SIL Open Font License).

Run the headless smoke test:

```
godot --headless --fixed-fps 60 --script res://tests/smoke_test.gd
```

## Deployment

`.github/workflows/deploy.yml` exports the web build with headless Godot and publishes it to GitHub Pages on every push to `main`.
The export uses the single-threaded web template, because GitHub Pages cannot send the COOP/COEP headers that threaded builds need.
In the repository settings, **Pages → Source** must be set to **GitHub Actions**.
