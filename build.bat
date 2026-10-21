@echo off
REM ═══════════════════════════════════════════════════════════════
REM build.bat — MSVC 编译脚本 (GitHub Actions windows runner)
REM ═══════════════════════════════════════════════════════════════

REM 设置 VS 环境
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

REM 创建输出目录
if not exist build mkdir build

REM 编译资源文件 (rc.exe → .res)
rc /nologo /Fobuild\resource.res resource.rc
if errorlevel 1 (
    echo Resource compilation failed
    exit /b 1
)

REM 编译 C (UTF-8 源文件, Unicode, GUI subsystem, 无控制台)
cl /c /W4 /O2 /utf-8 /DUNICODE /D_UNICODE /Fobuild\proxy_switcher.obj proxy_switcher.c
if errorlevel 1 (
    echo Compilation failed
    exit /b 1
)

REM 链接 (SUBSYSTEM:WINDOWS = 无控制台窗口, 包含资源)
link /SUBSYSTEM:WINDOWS /OUT:build\ProxySwitcher.exe /ENTRY:wWinMainCRTStartup /MACHINE:X64 ^
    build\proxy_switcher.obj ^
    build\resource.res ^
    kernel32.lib user32.lib shell32.lib advapi32.lib wininet.lib

if errorlevel 1 (
    echo Linking failed
    exit /b 1
)

echo Build successful: build\ProxySwitcher.exe