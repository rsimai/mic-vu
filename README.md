# Mic VU Plasmoid (Plasma 6)

Mic VU is a KDE Plasma 6 plasmoid that shows live microphone activity and color
transitions from silent to noisy.

This project is plasmoid-only and uses no Python or virtual environment.

## Features

- live microphone level indicator in panel
- configurable silent and noisy colors
- configurable polling interval
- version stamp in tooltip

## Architecture

- QML plasmoid UI
- small C helper binary (`mic_level`) that samples default input via PulseAudio/PipeWire
- installer builds helper and installs package with `kpackagetool6`

## Requirements

- KDE Plasma 6
- `kpackagetool6`
- C compiler (`cc`/`gcc`/`clang`)
- PulseAudio development libraries for linking (`libpulse-simple`, `libpulse`)

For openSUSE, typical packages are:

```bash
sudo zypper install plasma6-sdk gcc libpulse-devel
```

## Install

```bash
chmod +x install-plasmoid.sh
./install-plasmoid.sh
```

Then add widget:

- Right-click panel
- Add Widgets
- Search for Mic VU
- Drag into panel

If updates do not appear immediately:

```bash
kquitapp6 plasmashell && kstart6 plasmashell
```

## Behavior

- gray/red on sampling error
- transitions between configured silent/noisy colors during activity

## License

This project is licensed under the GNU Lesser General Public License v3.0 or later (LGPL-3.0-or-later).
