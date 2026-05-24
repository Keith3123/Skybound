# 🌤️ SKYBOUND — Endless Vertical Platformer
> Made with Godot 4.x · Beginner-Friendly · No External Assets Needed

---

## 📁 Project Structure

```
Skybound/
├── project.godot              ← Open this in Godot
├── icon.svg                   ← App icon
│
├── autoload/
│   └── game_manager.gd        ← Singleton: score, save/load, scene switching
│
├── scripts/
│   ├── player.gd              ← Player movement & auto-jump
│   ├── platform.gd            ← Platform types & drawing
│   ├── coin.gd                ← Collectible coins
│   ├── cloud.gd               ← Decorative clouds
│   ├── game.gd                ← Main game loop
│   ├── main_menu.gd           ← Title screen
│   └── game_over.gd           ← Game over screen
│
├── scenes/
│   ├── main_menu.tscn
│   ├── game.tscn
│   ├── game_over.tscn
│   ├── player.tscn
│   ├── platform.tscn
│   ├── coin.tscn
│   └── cloud.tscn
│
└── sounds/
	├── game.mp3                ← Background music (gameplay)
	├── 369515__lefty_studios__jumping-sfx.wav   ← Jump sound
	├── 336933__the-sacha-rush__coin4.wav        ← Coin collect sound
	├── 172204__leszek_szary__menu-button.wav    ← Button click sound
	└── 412168__poligonstudio__arcade-game-over.wav  ← Game over sound
```

---

## 🚀 How to Import & Run

1. **Open Godot 4** (version 4.1 or higher recommended).
2. On the Project Manager screen, click **"Import"**.
3. Navigate to the `Skybound/` folder and select **`project.godot`**.
4. Click **"Import & Edit"**.
5. Press **F5** (or the ▶ button) to run the game!

> ✅ No plugins, no external assets, no setup needed.
> Everything is drawn with GDScript code.

---

## 🎮 Controls

| Action      | Key        |
|-------------|------------|
| Move Left   | ← Arrow    |
| Move Right  | → Arrow    |
| Jump        | **Automatic** — happens when you land on a platform |

---

## 🏗️ Platform Types

| Color  | Type       | Effect                          |
|--------|------------|---------------------------------|
| 🟩 Green | Normal   | Standard jump                   |
| 🟦 Blue  | Boost    | Much higher jump!               |
| 🟥 Red   | Breakable| Breaks after you land on it     |
| 🟨 Yellow| Speed    | Sideways speed dash in the direction you are moving |

---

## 🪙 Scoring

- **Height** — Score increases the higher you climb
- **Coins** — Each coin gives **+50 points**
- **High Score** — Automatically saved between sessions

---

## 📈 Difficulty Progression

| Score Range | What Changes                        |
|-------------|-------------------------------------|
| 0 – 100     | Only normal green platforms         |
| 100 – 350   | Blue boost platforms appear         |
| 350 – 750   | Red & yellow platforms appear       |
| 750+        | All types, larger gaps, hard mode!  |

---

## 🎵 Audio
| Sound       | When it Plays      |
|-------------|--------------------|
| Background Music | Plays on the Main Menu screen |
| Jump SFX  	   | Every time the player lands on a platform |
| Coin SFX  	   | When the player collects a coin |
| Button SFX       | When clicking any menu button |
| Game Over SFX    | When the game over screen appears |

---

## 🌅 Background Themes
| Theme       |Look |
|-------------|----------------|
| ☀️ Day Sky  | Clear blue sky |
| 🌅 Sunset   | Orange and purple sky |
| 🌙 Night    | Dark blue night sky |
| 🌌 Space    | Nearly black with deep purple |

---

## ⏸️ Menu Button
Press the ☰ button during gameplay to open the menu:
 ▶ Resume — continue the game
 ↺ Retry — restart from the beginning
 ⌂ Home — go back to the Main Menu
🔊 Music Volume — adjust the background music volume
🎵 Sound Effects — toggle SFX on or off

---

## 💡 Tips for Beginners

- All visual drawing uses Godot's built-in `_draw()` method
- All collision shapes are created in `_ready()` (no scene editor needed)
- The `GameManager` autoload (`autoload/game_manager.gd`) is a **Singleton** — it survives scene changes
- Check `game.gd` to learn how procedural level generation works
- The camera only follows the player **upward** — if you fall off the bottom, it's game over!

---

## 🛠️ Godot Version

Built for **Godot 4.6.2 using GDScript 2.0 syntax.

If you get errors on older Godot versions, update to 4.1 or later.

---

Happy jumping! ☁️🕹️
