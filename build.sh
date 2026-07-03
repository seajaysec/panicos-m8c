#!/usr/bin/env bash
# build.sh — reproducible aarch64 build of m8c for PanicOS / PortMaster handhelds.
# Output: dist/ staging tree ready to copy to /storage/roms/ports/ on the device
# (M8C.sh + m8c/). Needs Docker (arm64 container; native on Apple Silicon).
set -euo pipefail

M8C_REF="${M8C_REF:-v1.7.9}"   # last SDL2 release — the device ships SDL2, not SDL3
HERE="$(cd "$(dirname "$0")" && pwd)"
SRC="$HERE/dist/m8c-src"
OUT="$HERE/dist"

rm -rf "$SRC" && mkdir -p "$SRC"
git clone --depth 1 --branch "$M8C_REF" https://github.com/laamaa/m8c "$SRC"

# Build in a clean arm64 container; stream source in / artifacts out (no volume
# mounts — works with colima whose VM does not share /tmp).
tar cf - -C "$SRC" --exclude .git . | docker run --rm -i --platform linux/arm64 debian:bookworm-slim sh -c '
set -e
mkdir -p /b && tar xf - -C /b && cd /b
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq gcc make pkg-config libsdl2-dev libserialport-dev >/dev/null 2>&1
make -j4 >/dev/null
cp /usr/lib/aarch64-linux-gnu/libserialport.so.0.1.0 libserialport.so.0
tar cf - m8c libserialport.so.0
' > "$OUT/m8c-build.tar"

rm -rf "$OUT/norns-staging" "$OUT/m8c" && mkdir -p "$OUT/m8c/libs" "$OUT/m8c/data" "$OUT/m8c/logs"
tar xf "$OUT/m8c-build.tar" -C "$OUT/m8c" m8c
tar xf "$OUT/m8c-build.tar" -C "$OUT/m8c/libs" libserialport.so.0
cp "$SRC/gamecontrollerdb.txt" "$OUT/m8c/"
cp "$HERE/ports/M8C.sh" "$OUT/"
chmod +x "$OUT/M8C.sh" "$OUT/m8c/m8c"
rm -f "$OUT/m8c-build.tar"

echo ""
echo "=== done ==="
echo "deploy:  scp -r $OUT/M8C.sh $OUT/m8c root@<device>:/storage/roms/ports/"
