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
# Launched from ES these are inherited; the fallbacks are PanicOS's session
# values so a manual (SSH) launch can find the Wayland display too.
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/var/run/0-runtime-dir}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

mkdir -p "$GAMEDIR/logs" "$XDG_DATA_HOME/m8c"

# FAT32 does not preserve execute bits
chmod +x "$GAMEDIR/m8c" 2>/dev/null

# The M8 is a USB CDC-ACM serial device; the module is not loaded until
# something asks for it. Idempotent.
modprobe cdc-acm 2>/dev/null || true

# PanicOS elects ANY USB audio sink as the system default the moment it
# appears (USB-C DAC convenience rule, priority 2000 in
# 95-panicos-routing.conf) — which silently reroutes ALL device audio out the
# M8's headphone jack while it is plugged in, muting the speaker until it is
# unplugged. The M8 is an instrument, not a DAC: pin its OUTPUT below the
# built-in codec so the speaker stays default (m8c then plays the M8's audio
# out the speaker; the M8 capture side is untouched). One-time drop-in; the
# audio stack restarts only when it was just installed.
_m8wp="/usr/share/wireplumber/wireplumber.conf.d/96-m8-not-default-sink.conf"
if [ ! -f "$_m8wp" ] && [ -d "$(dirname "$_m8wp")" ]; then
    cat > "$_m8wp" <<'M8WP'
# The Dirtywave M8 is an instrument, not a USB-C DAC: its USB audio output
# must never be elected the default sink (95-panicos-routing.conf bumps all
# alsa_output.usb-* to 2000, which silently reroutes ALL system audio out
# the M8 headphone jack the moment it is plugged in). Drop it below the
# built-in codec (~1000) so the speaker stays default; m8c then plays the
# M8 capture stream out the speaker. The M8 CAPTURE side is untouched.
monitor.alsa.rules = [
  {
    matches = [
      { node.name = "~alsa_output\\.usb-Dirtywave_M8.*" }
    ]
    actions = {
      update-props = {
        priority.driver  = 500
        priority.session = 500
      }
    }
  }
]
M8WP
    if [ -s "$_m8wp" ] && command -v systemctl >/dev/null 2>&1; then
        systemctl restart pipewire pipewire-pulse wireplumber 2>/dev/null
        for _i in $(seq 1 15); do
            pgrep -x pipewire >/dev/null 2>&1 && pgrep -x wireplumber >/dev/null 2>&1 && break
            sleep 1
        done
        # Re-elect the output (speaker vs HDMI) after the stack restart —
        # same pattern as the Norns port.
        sleep 1
        command -v hdmi_sense >/dev/null 2>&1 && hdmi_sense >/dev/null 2>&1 || true
        unset _i
    fi
fi
unset _m8wp

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
