# RealRTCW — macOS Port

**RealRTCW** is a community-driven single-player overhaul for **Return to Castle Wolfenstein**, built on top of the original **iortcw** and **rtcw-sp** source code.

This repository is the **macOS port** (Apple Silicon / arm64) of RealRTCW, maintained at https://github.com/teamlynxoid/realrtcw_mac.

The project focuses on modernizing the engine, expanding gameplay systems, and improving overall stability and quality of life—while staying true to the original RTCW experience.

---

## ✨ Features

### Engine & Platform
- Full **iortcw feature set**, including proper widescreen support
- SDL3 backend
- **macOS support** (Apple Silicon / arm64) — native `.app` bundle and DMG packaging
- **Steam integration** via *Steamshim* (by Ryan C. Gordon)
- Steam Achievements and Steam Stats support
- Steam Workshop Integration
- Steam Rich Presence support
- **FFmpeg** video playback support  
- Increased engine limits  
- Custom **BSPC** and **BSPCUI** tools
- Foliage rendering system
- Atmospheric environmental effects
- Extended scripting functionality
- Automatic AI attribute system (`.aidefaults`)   
- Expanded `.weap` file system    

### Gameplay & Content
- Expanded weapon arsenal  
- Survival game mode
- Restored console ports content and features
- Modular HUD system

### Usability & Quality of Life
- Subtitles support
- Weapon wheel
- Improved localization system  
- Enhanced controller/gamepad support
- Aim assist for gamepads
- `.pk3` gating via CVARs  
- Numerous bug fixes and general QoL improvements  

---

## 🔨 Building from Source

### Linux

See [`HOWTO-Build (linux).md`](HOWTO-Build%20(linux).md) for distro-specific prerequisites.

```bash
git clone https://github.com/teamlynxoid/realrtcw_mac
cd realrtcw_mac
make
```

Requires **FFmpeg 8+**. RealRTCW 5.3 is the last version that does not require FFmpeg.

### macOS

**Prerequisites (Homebrew):**
```bash
brew install sdl3 ffmpeg pkg-config
```

```bash
git clone https://github.com/teamlynxoid/realrtcw_mac
cd realrtcw_mac

# Build (Apple Silicon)
./make-macosx.sh arm64

# Build .app bundle
./make-macosx-app.sh release arm64

# Package as DMG
./make-macosx-dmg.sh release
```

### Windows (cross-compile from Linux)

```bash
./cross-make-mingw64.sh
```

---

## 📄 Original README

The original id Software README that accompanied the RTCW source release is preserved as **`README.txt`** and can be found in the source tree for both the SP and MP codebases.

---

## 📦 Availability

- **ModDB**  
  https://www.moddb.com/mods/realrtcw-realism-mod

- **Steam**  
  https://store.steampowered.com/app/1379630/RealRTCW/

- **GOG**  
  https://www.gog.com/en/game/realrtcw

---

## 🐧 Linux Packages

- **Arch Linux (AUR)** – maintained by *M0Rf30*  
  https://aur.archlinux.org/packages/realrtcw/

- **openSUSE**  
  https://build.opensuse.org/package/show/games/realrtcw
