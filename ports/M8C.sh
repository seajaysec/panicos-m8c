#!/bin/bash
# M8C.sh — PortMaster launch script for m8c (Dirtywave M8 headless client)
# https://github.com/laamaa/m8c (v1.7.9, SDL2 + libserialport, aarch64)
#
# Plug an M8 (or Teensy running M8 headless) into USB before/after launch;
# m8c waits for the device. Audio from the M8 arrives over USB audio and is
# routed to the handheld's output when audio_enabled=true (seeded below).
# Quit: hold Select + R3 (stick click), or Select+Start via gptokeyb.

XDG_DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}

if   [ -d "/opt/system/Tools/PortMaster/" ]; then controlfolder="/opt/system/Tools/PortMaster"
elif [ -d "/opt/tools/PortMaster/"        ]; then controlfolder="/opt/tools/PortMaster"
elif [ -d "$XDG_DATA_HOME/PortMaster/"    ]; then controlfolder="$XDG_DATA_HOME/PortMaster"
else                                              controlfolder="/roms/ports/PortMaster"
fi

source "$controlfolder/control.txt"
[ -f "$controlfolder/mod_${CFW_NAME}.txt" ] && source "$controlfolder/mod_${CFW_NAME}.txt"
get_controls

GAMEDIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)/m8c"
cd "$GAMEDIR"

export HOME="$GAMEDIR/data"
export XDG_DATA_HOME="$HOME/.local/share"
export LD_LIBRARY_PATH="$GAMEDIR/libs:$LD_LIBRARY_PATH"
export SDL_GAMECONTROLLERCONFIG="$sdl_controllerconfig"

mkdir -p "$GAMEDIR/logs" "$XDG_DATA_HOME/m8c"

# FAT32 does not preserve execute bits
chmod +x "$GAMEDIR/m8c" 2>/dev/null

# The M8 is a USB CDC-ACM serial device; the module is not loaded until
# something asks for it. Idempotent.
modprobe cdc-acm 2>/dev/null || true

# Seed config on first run: enable USB audio routing (the M8 headless has no
# audio jack of its own — sound arrives over USB and must be re-played here).
# Everything else stays at m8c defaults; edit data/.local/share/m8c/config.ini
# to taste (m8c rewrites it with the full option set after first run).
CFG="$XDG_DATA_HOME/m8c/config.ini"
if [ ! -f "$CFG" ]; then
    cat > "$CFG" << 'M8CFG'
[graphics]
fullscreen=true
[audio]
audio_enabled=true
M8CFG
fi

# SDL controller database (m8c looks for it in its pref dir)
[ -f "$XDG_DATA_HOME/m8c/gamecontrollerdb.txt" ] || \
    cp "$GAMEDIR/gamecontrollerdb.txt" "$XDG_DATA_HOME/m8c/" 2>/dev/null

$GPTOKEYB "m8c" &
pm_platform_helper "$GAMEDIR/m8c"
"$GAMEDIR/m8c" 2>&1 | tee -a "$GAMEDIR/logs/m8c.log"
pm_finish
