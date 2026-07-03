# panicos-m8c

[m8c](https://github.com/laamaa/m8c) — the Dirtywave **M8 tracker headless
client** — packaged as a PanicOS / PortMaster port for ARM handhelds
(RG35XX Pro class, aarch64).

Pinned to **m8c v1.7.9**, the last SDL2 release (PanicOS ships SDL2; m8c
v2.x requires SDL3). libserialport is bundled (`m8c/libs/`).

## Build

```sh
./build.sh          # needs Docker (arm64 container; native on Apple Silicon)
```

Output lands in `dist/`: `M8C.sh` + `m8c/`, ready to copy to the device.

## Install

```sh
scp -r dist/M8C.sh dist/m8c root@<device>:/storage/roms/ports/
```

**M8C** appears in the Ports menu after an EmulationStation restart
(`systemctl restart panicos-es.service`, or reboot).

## Use

Plug the M8 (or a Teensy 4.1 running [M8 headless
firmware](https://github.com/Dirtywave/M8HeadlessFirmware)) into the
handheld's USB port — before or after launching; m8c shows a waiting screen
until the device appears (CDC-ACM serial, VID 16c0).

- **Audio**: the M8's sound arrives over USB audio and is re-played through
  the handheld (`audio_enabled=true` is seeded; kernel has
  `CONFIG_SND_USB_AUDIO=y`).
- **Controls**: SDL game controller — D-pad = arrows, A = edit, B = option,
  Select/Start = M8 select/start. **Quit: hold Select + R3** (stick click).
- **Config**: `m8c/data/.local/share/m8c/config.ini` (m8c rewrites it with
  the full option set after first run; delete it to reseed defaults).
- **Log**: `m8c/logs/m8c.log`.
