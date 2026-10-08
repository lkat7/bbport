# Getting Bloodborne PC running on Windows

There are two ways to get the port. Both end the same way: you point the launcher at **your own dumped copy of the game**.

You need Windows 10 or 11 (64-bit), a GPU with Vulkan 1.3 support and current drivers, and a CPU with AVX2.

## Option A: download the ready-made build (easiest)

1. Go to the [Releases page](https://github.com/lkat7/bbport/releases) and download `bbport-windows-x64.zip`.
2. Unzip it anywhere, for example `C:\Games\bbport`.
3. Install **Python 3.12** from [python.org](https://www.python.org/downloads/windows/). The launcher is written in Python.
   - Use the python.org installer, not the Microsoft Store version: the launcher won't find the Store one.
4. Double-click `launch_gui.bat`.

## Option B: build it yourself with one script

1. Download [`setup.bat`](https://raw.githubusercontent.com/lkat7/bbport/master/setup.bat) (right-click → Save link as), or clone the repo with `git clone --recursive https://github.com/lkat7/bbport`.
2. Double-click `setup.bat`. It will:
   - install Python and MSYS2 (the compiler) if you don't have them,
   - download the source code if it isn't already next to the script (into a `bbport` folder),
   - install every library the build needs,
   - build the game executable.

   The first run downloads about 400 MB and installs about 2.5 GB, then compiles for a while. Running it again is safe: it skips what's already done.
3. When it says **Setup complete**, double-click `launch_gui.bat` in the folder it shows.

You **don't** need to edit any environment variables or PATH. The scripts find everything on their own.

## Preparing your game files

The port needs a decrypted dump of **your own copy** of Bloodborne (`CUSA03173`) with the **1.09 update merged in**. No game files are included or provided. The base game alone (version 1.00) will not run: the launcher stops with "Game File Verification Failed".

If you have the game and the update as two `.pkg` files:

1. **Extract both packages** with a PS4 PKG extractor (shadPS4's package installer works). Extracting a package gives you folders like `Image0` (the game, including `eboot.bin`) and `Sc0` (the console's `sce_sys` metadata).
2. **Merge the update into the base game.** Copy everything from the extracted 1.09 update over the extracted base game and replace files when asked. `eboot.bin` must come from the update.
3. **Check that `param.sfo` is where the port looks for it.** The folder you give the launcher needs `sce_sys\param.sfo`. If you only have `Sc0\param.sfo`, copy it to `Image0\sce_sys\param.sfo`.

The launcher checks the result and tells you what is missing, for example `Only Bloodborne CUSA03173 with update 1.09 is supported` or `No such file ... sce_sys\param.sfo`.

## Playing

In the launcher, select your prepared game folder (or the `eboot.bin` inside it, for example `CUSA03173\Image0\eboot.bin`), pick your settings and patches, and press start.

## Troubleshooting

| Problem | Fix |
|---|---|
| `'build.bat' is not recognized` in PowerShell | Type `.\build.bat` in PowerShell (or just double-click `setup.bat`). |
| A window opens and closes instantly | Run the script from a terminal so you can read the error, or use `setup.bat`, which waits for a key at the end. |
| `Python not found` from the launcher | Install Python from python.org (not the Microsoft Store), then try again. |
| Setup fails partway | Run `setup.bat` again. If it fails at the same step, copy the first error message and ask for help. |
| Game won't start: `vulkan-1.dll` missing | Update your graphics drivers. That DLL comes from the driver. |
| `Game File Verification Failed` (`missing_update`, `other_title`) | The game folder is the base game or another edition. Merge the 1.09 update (see "Preparing your game files"). |
| `prepare failed: ... sce_sys\param.sfo` | Copy `Sc0\param.sfo` to `Image0\sce_sys\param.sfo`. |
| Process exits with code `3221225781` (`0xC0000135`) right after "Launching" | A runtime DLL is missing from `out\`. Run `python scripts\stage_dlls.py` from the project folder (needs MSYS2 in `C:\msys64`). |

## For developers: what the setup does

`scripts/setup_msys2.sh` installs the MSYS2 MINGW64 packages and the libraries MSYS2 doesn't package:

- **magic_enum** v0.9.7 (header-only)
- **miniz** 3.1.2, built as a static library. Version 3.1 or newer is required for `MZ_ZIP_FLAG_READ_ALLOW_WRITING`.
- **xbyak** v7.43 (header-only)
- `vk_mem_alloc.h`, copied from `include/vma/` to `include/`, where the sources expect it.

Everything goes into `C:\msys64\mingw64`, which `build.bat` and `gpu/CMakeLists.txt` search automatically.
