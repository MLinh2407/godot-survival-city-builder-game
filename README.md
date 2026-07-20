# Look For The Light

**Course:** COSC3072|COSC3073 - Games Studio 1  
**Engine:** Godot 4.6

---

## About

Look for the Light is a survival city-building game set in a dying underground colony beneath the ruins of a collapsed megacity. The year is 2147. The Syndicate's AI governance network has failed, taking power, water and food distribution with it. You are the Director of Grid-7, an underground settlement of 847 survivors, and you have 35 days to keep them alive before a city-wide electromagnetic storm makes the decision for you.

Manage three core resources (Power, Food and Morale), construct and upgrade 9 types of buildings, assign workers and respond to scripted crisis events. Every decision shifts a persistent Hope/Order ideological slider that, combined with your survival rate, determines which of narrative endings your colony reaches.

The game is not about whether you survive. It is about what survival costs.

> *"You have 5 weeks to keep 847 survivors alive underground but the hardest part is deciding what kind of people you want them to become."*

**Genre:** Survival City-Builder / Strategy  
**Art Style:** Dark Cyberpunk / Post-Apocalyptic  
**Estimated Playtime:** 35-45 minutes per campaign run

---

## Running the Compiled Build

No Godot installation required.

1. Clone the repository:
   ```
   git clone https://github.com/MLinh2407/look-for-the-light.git
   ```
2. Open the `game/` folder.
3. Double-click **`LookForTheLight.exe`** to launch.
4. From the Main Menu, click **New Game** to begin.

---

## Opening from Source in Godot

1. Clone the repository:
   ```
   git clone https://github.com/MLinh2407/look-for-the-light.git
   ```
3. Open Godot → **Import** → browse to the cloned folder → select `project.godot` → **Import & Edit**.
4. Press **F5** to run. If prompted for a main scene, select `scenes/UI/MainMenu.tscn`.

---

## Troubleshooting - Git LFS

The compiled `.exe` is stored using **Git LFS**. If you cloned the repo and the file inside `game/` is only a few hundred bytes (a text pointer file) instead of the full executable, Git LFS did not pull the binary.

Fix it with the following steps:

```bash
# Install Git LFS (one-time setup)
git lfs install

# Pull the actual LFS files
git lfs pull
```
---

## System Requirements

| | Minimum |
|-|---------|
| OS | Windows 10 / 11 (64-bit) |
| GPU | DirectX 12 capable (keep drivers up to date) |
| RAM | 4 GB |
| Storage | ~400 MB |

---
## License

*Copyright (c) 2026 Team03 Studio. All rights reserved. This project is proprietary. Code and assets cannot be used, copied, or modified without permission.*
