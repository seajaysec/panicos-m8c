#!/usr/bin/env bash
# build-2x.sh — EXPLORATION: m8c v2.x (SDL3) for PanicOS aarch64.
# m8c 2.x needs SDL3, which PanicOS does not ship — so SDL3 is built from
# source here and bundled next to the binary. Deployed as a SEPARATE port
# (M8C-Beta.sh + m8c-beta/) so the stable v1.7.9 port stays untouched.
#
# What 2.x adds over 1.7.9: in-app config UI, multichannel-USB product-id
# detection (newer M8 firmware audio modes), async command queue, better
# disconnect handling, buffer hardening.
#
# Sources are cloned INSIDE the container: tar-streaming a checkout from
# macOS leaks AppleDouble ._* metadata files that ninja then tries to
# compile as C (learned the hard way).
set -euo pipefail

M8C_REF="${M8C_REF:-v2.2.3}"
SDL_REF="${SDL_REF:-release-3.4.12}"   # latest stable SDL3 at pin time
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="$HERE/dist"
mkdir -p "$OUT"

docker run --rm --platform linux/arm64 debian:bookworm-slim sh -c '
set -e
apt-get update -qq >/dev/null 2>&1
apt-get install -y -qq gcc g++ make cmake ninja-build pkg-config git ca-certificates \
  libserialport-dev libwayland-dev wayland-protocols libxkbcommon-dev \
  libegl-dev libgles-dev libdrm-dev libgbm-dev libasound2-dev \
  libpipewire-0.3-dev libudev-dev libdbus-1-dev >/dev/null 2>&1
cd /root
git clone -q --depth 1 --branch '"$SDL_REF"' https://github.com/libsdl-org/SDL sdl3-src
git clone -q --depth 1 --branch '"$M8C_REF"'  https://github.com/laamaa/m8c m8c2-src
cmake -S sdl3-src -B sdl3-build -G Ninja -DCMAKE_BUILD_TYPE=Release \
  -DSDL_WAYLAND=ON -DSDL_KMSDRM=ON -DSDL_X11=OFF \
  -DSDL_ALSA=ON -DSDL_PIPEWIRE=ON -DSDL_PULSEAUDIO=OFF \
  -DSDL_TESTS=OFF -DSDL_EXAMPLES=OFF -DCMAKE_INSTALL_PREFIX=/opt/sdl3 >/dev/null
cmake --build sdl3-build >/dev/null
cmake --install sdl3-build >/dev/null
# m8c 2.2.3 passes libs only via target_link_options (pkg-config LDFLAGS),
# which this generator places before the object files -> every SDL3/sp_
# symbol undefined. Append a proper target_link_libraries.
cat >> m8c2-src/CMakeLists.txt <<'"'"'CMAKEFIX'"'"'
target_link_libraries(${APP_NAME} PRIVATE SDL3::SDL3)
if (USE_LIBSERIALPORT)
    target_link_libraries(${APP_NAME} PRIVATE ${LIBSERIALPORT_LIBRARIES})
endif ()
CMAKEFIX
SDL3_CMAKE_DIR=$(dirname "$(find /opt/sdl3 -name SDL3Config.cmake | head -1)")
PKG_CONFIG_PATH=$(dirname "$(find /opt/sdl3 -name sdl3.pc | head -1)") \
  cmake -S m8c2-src -B m8c-build -DCMAKE_BUILD_TYPE=Release -DSDL3_DIR="$SDL3_CMAKE_DIR" >/dev/null
cmake --build m8c-build -j4 >/dev/null
mkdir -p /stage
cp m8c-build/m8c /stage/
find /opt/sdl3 \( -name "libSDL3.so.0*" -type f -o -name "libSDL3.so.0*" -type l \) -exec cp -P {} /stage/ \;
cp /usr/lib/aarch64-linux-gnu/libserialport.so.0.1.0 /stage/libserialport.so.0
cp m8c2-src/gamecontrollerdb.txt /stage/ 2>/dev/null || true
cd /stage && tar cf - .
' > "$OUT/m8c2-build.tar"

rm -rf "$OUT/m8c-beta" && mkdir -p "$OUT/m8c-beta/libs" "$OUT/m8c-beta/data" "$OUT/m8c-beta/logs"
tar xf "$OUT/m8c2-build.tar" -C "$OUT/m8c-beta" ./m8c ./gamecontrollerdb.txt
tar xf "$OUT/m8c2-build.tar" -C "$OUT/m8c-beta/libs" --exclude ./m8c --exclude ./gamecontrollerdb.txt
sed -e 's|)/m8c"|)/m8c-beta"|' -e 's|"m8c" &|"m8c-beta" \&|' "$HERE/ports/M8C.sh" > "$OUT/M8C-Beta.sh"
chmod +x "$OUT/M8C-Beta.sh" "$OUT/m8c-beta/m8c"
rm -f "$OUT/m8c2-build.tar"

echo ""
echo "=== done ==="
echo "deploy:  scp -r $OUT/M8C-Beta.sh $OUT/m8c-beta root@<device>:/storage/roms/ports/"
