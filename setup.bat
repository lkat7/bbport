@echo off
setlocal EnableExtensions
title Bloodborne PC port - setup
cd /d "%~dp0"

REM One-click setup: installs Python and MSYS2 if missing, installs every build
REM dependency, gets the source with submodules and builds out\bbport.exe.
REM Nothing is added to PATH permanently: build.bat adds MSYS2 for its own run.
REM Safe to run again; finished steps are skipped.

set "MSYS_ROOT=C:\msys64"
set "REPO_URL=https://github.com/lkat7/bbport.git"
set "PY_URL=https://www.python.org/ftp/python/3.12.10/python-3.12.10-amd64.exe"
set "MSYS_URL=https://github.com/msys2/msys2-installer/releases/latest/download/msys2-x86_64-latest.exe"

set "HAVE_WINGET="
where winget >nul 2>nul && set "HAVE_WINGET=1"

echo.
echo [1/5] Python (used by the launcher and the patch scripts)
call :find_python
if defined PYTHON_EXE goto python_ok
if defined HAVE_WINGET (
    winget install -e --id Python.Python.3.12 --scope user --silent --accept-package-agreements --accept-source-agreements
    call :find_python
)
if defined PYTHON_EXE goto python_ok
echo Downloading the Python installer...
curl.exe -L --fail -o "%TEMP%\bb-python-setup.exe" "%PY_URL%" || goto fail
"%TEMP%\bb-python-setup.exe" /quiet InstallAllUsers=0 PrependPath=1 Include_tcltk=1 Include_test=0
call :find_python
if not defined PYTHON_EXE (
    echo Python could not be installed. Install Python 3.10+ from python.org, then run setup.bat again.
    goto fail
)
:python_ok
echo Python: %PYTHON_EXE%

echo.
echo [2/5] MSYS2 (compiler and libraries)
if exist "%MSYS_ROOT%\usr\bin\bash.exe" goto msys_ok
if defined HAVE_WINGET (
    winget install -e --id MSYS2.MSYS2 --silent --accept-package-agreements --accept-source-agreements
)
if exist "%MSYS_ROOT%\usr\bin\bash.exe" goto msys_ok
echo Downloading the MSYS2 installer...
curl.exe -L --fail -o "%TEMP%\bb-msys2-setup.exe" "%MSYS_URL%" || goto fail
"%TEMP%\bb-msys2-setup.exe" in --confirm-command --accept-messages --root C:/msys64
if not exist "%MSYS_ROOT%\usr\bin\bash.exe" (
    echo MSYS2 could not be installed. Install it from https://www.msys2.org to C:\msys64, then run setup.bat again.
    goto fail
)
:msys_ok
set "MSYSTEM=MINGW64"
set "CHERE_INVOKING=1"
set "BASH=%MSYS_ROOT%\usr\bin\bash.exe"
echo Updating MSYS2 (the first update can restart itself, so it runs twice)...
"%BASH%" -lc "pacman -Syuu --noconfirm"
"%BASH%" -lc "pacman -Syuu --noconfirm" || goto fail
"%BASH%" -lc "pacman -S --needed --noconfirm git" || goto fail

echo.
echo [3/5] Source code
if exist ".git" if exist "gpu\CMakeLists.txt" goto have_repo
if exist "bbport\.git" (
    cd /d "%~dp0bbport"
    goto have_repo
)
echo Downloading the source code into "%~dp0bbport"...
"%BASH%" -lc "git clone --recursive '%REPO_URL%' bbport" || goto fail
cd /d "%~dp0bbport"
:have_repo
"%BASH%" -lc "git submodule update --init --recursive" || goto fail
echo Source: %CD%

echo.
echo [4/5] Build dependencies
"%BASH%" -lc "tr -d '\r' < scripts/setup_msys2.sh | bash -s" || goto fail

echo.
echo [5/5] Building
call "%CD%\build.bat" || goto fail

echo.
echo ============================================================
echo  Setup complete.
echo  Next: run launch_gui.bat in
echo    %CD%
echo  and select your own dumped CUSA03173 (v1.09) game folder.
echo ============================================================
pause
exit /b 0

:fail
echo.
echo Setup failed. Scroll up for the first error message.
pause
exit /b 1

REM Same search order as launch_gui.bat, which needs a python.org install (tkinter).
:find_python
set "PYTHON_EXE="
for %%P in (
    "C:\Program Files\Python313\python.exe"
    "C:\Program Files\Python312\python.exe"
    "C:\Program Files\Python311\python.exe"
    "C:\Program Files\Python310\python.exe"
    "%LocalAppData%\Programs\Python\Python313\python.exe"
    "%LocalAppData%\Programs\Python\Python312\python.exe"
    "%LocalAppData%\Programs\Python\Python311\python.exe"
    "%LocalAppData%\Programs\Python\Python310\python.exe"
) do (
    if not defined PYTHON_EXE if exist %%P set "PYTHON_EXE=%%~P"
)
exit /b 0
