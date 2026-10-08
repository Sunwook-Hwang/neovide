"""Bundle linked libraries and reject GLIBC requirements newer than 2.28."""

import json
from pathlib import Path
import re
import shutil
import subprocess
import tarfile
import hashlib


root = Path(__file__).resolve().parents[1]
package = root / "target/neovide-linux-x86_64"
(package / "bin").mkdir(parents=True, exist_ok=True)
(package / "lib").mkdir(exist_ok=True)
binary = package / "bin/neovide"
shutil.copy2(root / "target/release/neovide", binary)

# The host provides glibc and its loader. Graphics drivers remain host provided.
system = {
    "libc.so.6", "libm.so.6", "libdl.so.2", "libpthread.so.0",
    "librt.so.1", "libresolv.so.2", "libutil.so.1", "libanl.so.1",
}
pending = [binary]
bundled = set()
while pending:
    current = pending.pop()
    output = subprocess.check_output(["ldd", str(current)], text=True)
    if "not found" in output:
        raise SystemExit(f"Unresolved dependency: {current}\n{output}")
    for name, path in re.findall(r"^\s*(\S+) => (/\S+)", output, re.MULTILINE):
        if name in system or name in bundled:
            continue
        destination = package / "lib" / name
        shutil.copy2(path, destination, follow_symlinks=True)
        bundled.add(name)
        pending.append(destination)

requirements = {}
for elf in [binary, *sorted((package / "lib").iterdir())]:
    output = subprocess.check_output(["readelf", "--version-info", str(elf)], text=True)
    versions = set(re.findall(r"Name: (GLIBC_[A-Za-z0-9_.]+)", output))
    for version in versions:
        match = re.fullmatch(r"GLIBC_(\d+)\.(\d+)(?:\.(\d+))?", version)
        if match is None or tuple(int(x or 0) for x in match.groups()) > (2, 28, 0):
            raise SystemExit(f"Unsupported glibc requirement {version}: {elf}")
    requirements[str(elf.relative_to(package))] = sorted(versions)

launcher = package / "neovide"
launcher.write_text(
    '#!/bin/sh\nset -eu\n'
    'root=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)\n'
    'export LD_LIBRARY_PATH="$root/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"\n'
    'exec "$root/bin/neovide" "$@"\n'
)
launcher.chmod(0o755)
shutil.copy2(root / "LICENSE", package / "LICENSE")
(package / "README.txt").write_text(
    "Linux x86_64, glibc 2.28 or later. Run ./neovide.\n"
    "Keep bin/ and lib/ beside the launcher.\n"
    "Requires an X11/Wayland desktop, working OpenGL drivers and Neovim.\n"
    "Use ./neovide --neovim-bin /path/to/rvi to select reovim.\n"
)
(package / "BUILD.json").write_text(json.dumps({
    "revision": subprocess.check_output(["git", "rev-parse", "HEAD"], text=True).strip(),
    "glibc": subprocess.check_output(["getconf", "GNU_LIBC_VERSION"], text=True).strip(),
    "rustc": subprocess.check_output(["rustc", "--version"], text=True).strip(),
    "target_cpu": "x86-64",
    "skia": "built from source",
    "glibc_requirements": requirements,
}, indent=2) + "\n")
artifacts = root / "target/artifacts"
artifacts.mkdir(parents=True, exist_ok=True)
archive = artifacts / "neovide-linux-x86_64-glibc-2.28.tar.gz"
with tarfile.open(archive, "w:gz") as tar:
    tar.add(package, arcname=package.name)
(artifacts / "SHA256SUMS").write_text(
    f"{hashlib.sha256(archive.read_bytes()).hexdigest()}  {archive.name}\n"
)
print(f"Packaged {archive}; all GLIBC requirements <= 2.28")
