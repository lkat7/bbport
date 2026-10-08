#!/usr/bin/env bash
# Installs every build dependency into MSYS2's MINGW64 prefix (/mingw64).
# Run from an MSYS2 shell, or let setup.bat call it. Safe to run again.
set -euo pipefail

PREFIX=/mingw64
MAGIC_ENUM_VERSION=v0.9.7
MINIZ_VERSION=3.1.2   # 3.1+ needed: cache_storage.cpp uses MZ_ZIP_FLAG_READ_ALLOW_WRITING
XBYAK_VERSION=v7.43

echo "==> Installing MSYS2 packages"
pacman -S --needed --noconfirm \
    git unzip \
    mingw-w64-x86_64-toolchain \
    mingw-w64-x86_64-cmake \
    mingw-w64-x86_64-ninja \
    mingw-w64-x86_64-pkgconf \
    mingw-w64-x86_64-python \
    mingw-w64-x86_64-fmt \
    mingw-w64-x86_64-boost \
    mingw-w64-x86_64-robin-map \
    mingw-w64-x86_64-vulkan-headers \
    mingw-w64-x86_64-vulkan-loader \
    mingw-w64-x86_64-vulkan-memory-allocator \
    mingw-w64-x86_64-xxhash \
    mingw-w64-x86_64-sdl3 \
    mingw-w64-x86_64-zydis \
    mingw-w64-x86_64-ffmpeg

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT

# Not packaged by MSYS2: magic_enum (header-only)
if [ ! -f "$PREFIX/include/magic_enum/magic_enum.hpp" ]; then
    echo "==> Installing magic_enum $MAGIC_ENUM_VERSION"
    git clone -q --depth 1 --branch "$MAGIC_ENUM_VERSION" https://github.com/Neargye/magic_enum "$work/magic_enum"
    cp -r "$work/magic_enum/include/magic_enum" "$PREFIX/include/"
fi

# Not packaged by MSYS2: miniz (static library from the single-file release)
if ! grep -q MZ_ZIP_FLAG_READ_ALLOW_WRITING "$PREFIX/include/miniz.h" 2>/dev/null \
        || [ ! -f "$PREFIX/lib/libminiz.a" ]; then
    echo "==> Building miniz $MINIZ_VERSION"
    curl -sSLf -o "$work/miniz.zip" \
        "https://github.com/richgel999/miniz/releases/download/$MINIZ_VERSION/miniz-$MINIZ_VERSION.zip"
    unzip -oq "$work/miniz.zip" -d "$work/miniz"
    gcc -O2 -c "$work/miniz/miniz.c" -o "$work/miniz/miniz.o"
    rm -f "$PREFIX/lib/libminiz.a"
    ar rcs "$PREFIX/lib/libminiz.a" "$work/miniz/miniz.o"
    cp "$work/miniz/miniz.h" "$PREFIX/include/miniz.h"
fi

# Not packaged by MSYS2: xbyak (header-only)
if [ ! -f "$PREFIX/include/xbyak/xbyak.h" ]; then
    echo "==> Installing xbyak $XBYAK_VERSION"
    git clone -q --depth 1 --branch "$XBYAK_VERSION" https://github.com/herumi/xbyak "$work/xbyak"
    cp -r "$work/xbyak/xbyak" "$PREFIX/include/"
fi

# MSYS2 installs vk_mem_alloc.h under include/vma/; the sources include it directly.
if [ ! -f "$PREFIX/include/vk_mem_alloc.h" ] && [ -f "$PREFIX/include/vma/vk_mem_alloc.h" ]; then
    echo "==> Exposing vk_mem_alloc.h"
    cp "$PREFIX/include/vma/vk_mem_alloc.h" "$PREFIX/include/vk_mem_alloc.h"
fi

echo "==> Build dependencies ready"
