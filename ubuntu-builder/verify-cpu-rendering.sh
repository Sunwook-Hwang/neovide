#!/bin/bash
set -euo pipefail

root=$(pwd)
evidence="$root/target/cpu-rendering/evidence"
mkdir -p "$evidence"
test "$(getconf GNU_LIBC_VERSION)" = "glibc 2.28"
test ! -e /dev/dri
getconf GNU_LIBC_VERSION > "$evidence/glibc.txt"
printf 'No /dev/dri device is exposed to this container.\n' > "$evidence/gpu-devices.txt"
cd "$root/target/cpu-rendering/package"
sha256sum -c SHA256SUMS > "$evidence/package-checksum.txt"
tar -xzf neovide-linux-x86_64-glibc-2.28.tar.gz
cd "$root"

export DISPLAY=:99 LIBGL_ALWAYS_SOFTWARE=true GALLIUM_DRIVER=llvmpipe
export XDG_RUNTIME_DIR=/tmp/neovide-cpu-runtime
export XDG_CONFIG_HOME=/tmp/neovide-cpu-config
export NEOVIDE_CPU_REPORT="$evidence/ui-report.json"
export VIMRUNTIME="$root/target/cpu-rendering/neovim/runtime"
mkdir -p "$XDG_RUNTIME_DIR" "$XDG_CONFIG_HOME"
chmod 700 "$XDG_RUNTIME_DIR"
Xvfb :99 -screen 0 1280x800x24 -ac > "$evidence/xvfb.log" 2>&1 &
xvfb_pid=$!
trap 'kill "$xvfb_pid" 2>/dev/null || true' EXIT
for attempt in $(seq 1 50); do
    if xdpyinfo >/dev/null 2>&1; then break; fi
    sleep 0.2
done
glxinfo -B > "$evidence/opengl.txt"
grep -i 'OpenGL renderer string: llvmpipe' "$evidence/opengl.txt"

timeout 40s "$root/target/cpu-rendering/package/neovide-linux-x86_64/neovide" \
    --no-fork --neovim-bin "$root/target/cpu-rendering/neovim/build/bin/nvim" \
    -- -u "$root/ubuntu-builder/cpu-rendering-smoke.lua" -i NONE --noplugin \
    > "$evidence/neovide.log" 2>&1 &
neovide_pid=$!
for attempt in $(seq 1 100); do
    if test -f "$NEOVIDE_CPU_REPORT"; then break; fi
    if ! kill -0 "$neovide_pid" 2>/dev/null; then
        cat "$evidence/neovide.log"
        wait "$neovide_pid"
        exit 1
    fi
    sleep 0.2
done
xwininfo -root -tree > "$evidence/windows.txt"
import -window root "$evidence/cpu-rendering.png"
test -f "$NEOVIDE_CPU_REPORT"
wait "$neovide_pid"
cat "$NEOVIDE_CPU_REPORT"
grep -q '"success":true' "$NEOVIDE_CPU_REPORT"
printf '\nCPU rendering GUI smoke test passed.\n'
