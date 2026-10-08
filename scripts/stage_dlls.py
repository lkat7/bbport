"""Copy the MinGW runtime DLLs that out/*.exe need next to them.

Walks each executable's PE import table recursively and copies every DLL found
in the MinGW bin directories. DLL names carry version numbers (avcodec-63.dll)
that change with MSYS2 updates, so nothing is hardcoded. System DLLs are never
copied, and vulkan-1.dll must come from the GPU driver.
"""
import os
import shutil
import struct
import sys
from pathlib import Path

out = Path("out")
out.mkdir(parents=True, exist_ok=True)

search_dirs = [
    Path(os.environ.get("MINGW_BIN", r"C:\msys64\mingw64\bin")),
    Path(r"C:\msys64\mingw64\bin"),
]
if os.environ.get("SDL3_DIR"):
    search_dirs.append(Path(os.environ["SDL3_DIR"]) / "bin")
search_dirs = [d for d in search_dirs if d.is_dir()]

SKIP = {"vulkan-1.dll"}


def pe_imports(path):
    """Return the DLL names in a PE file's import table."""
    data = path.read_bytes()
    if data[:2] != b"MZ":
        return []
    pe = struct.unpack_from("<I", data, 0x3C)[0]
    if data[pe:pe + 4] != b"PE\0\0":
        return []
    nsec, = struct.unpack_from("<H", data, pe + 6)
    optsize, = struct.unpack_from("<H", data, pe + 20)
    opt = pe + 24
    magic, = struct.unpack_from("<H", data, opt)
    ddir = opt + (112 if magic == 0x20B else 96)
    imp_rva, = struct.unpack_from("<I", data, ddir + 8)
    if not imp_rva:
        return []
    sections = []
    for i in range(nsec):
        s = opt + optsize + i * 40
        vsize, va, rawsize, rawptr = struct.unpack_from("<IIII", data, s + 8)
        sections.append((va, max(vsize, rawsize), rawptr))

    def off(rva):
        for va, size, raw in sections:
            if va <= rva < va + size:
                return rva - va + raw
        return None

    names = []
    p = off(imp_rva)
    while p is not None and p + 20 <= len(data):
        name_rva = struct.unpack_from("<I", data, p + 12)[0]
        if not name_rva:
            break
        n = off(name_rva)
        if n is not None:
            names.append(data[n:data.index(b"\0", n)].decode("ascii", "replace"))
        p += 20
    return names


def find(dll):
    for d in search_dirs:
        src = d / dll
        if src.is_file():
            return src
    return None


staged = 0
missing = set()
seen = set()
queue = sorted(out.glob("*.exe"))
while queue:
    for dll in pe_imports(queue.pop()):
        key = dll.lower()
        if key in seen or key in SKIP:
            continue
        seen.add(key)
        src = find(dll)
        if src is None:
            continue  # system DLL (kernel32, user32, ...)
        dst = out / src.name
        if not dst.exists():
            try:
                shutil.copy2(src, dst)
                staged += 1
            except OSError:
                missing.add(dll)
                continue
        queue.append(dst)

print(f"Runtime DLL staging complete ({staged} new DLLs staged, {len(seen)} imports checked).")
if missing:
    print("Could not copy: " + ", ".join(sorted(missing)), file=sys.stderr)
    sys.exit(1)
