@echo off
REM ═══════════════════════════════════════════════════════════════
REM build.bat — MSVC 编译脚本 (GitHub Actions windows runner)
REM ═══════════════════════════════════════════════════════════════

REM 设置 VS 环境
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

REM 创建输出目录
if not exist build mkdir build

REM 编译 (C, Unicode, GUI subsystem, 无控制台)
cl /c /W4 /O2 /DUNICODE /D_UNICODE /Fobuild\proxy_switcher.obj proxy_switcher.c
if errorlevel 1 (
    echo Compilation failed
    exit /b 1
)

REM 链接 (SUBSYSTEM:WINDOWS = 无控制台窗口)
link /SUBSYSTEM:WINDOWS /OUT:build\ProxySwitcher.exe /ENTRY:wWinMainCRTStartup /MACHINE:X64 ^
    build\proxy_switcher.obj ^
    kernel32.lib user32.lib shell32.lib advapi32.lib wininet.lib

if errorlevel 1 (
    echo Linking failed
    exit /b 1
)

echo Build successful: build\ProxySwitcher.exe