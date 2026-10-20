@echo off
REM ═══════════════════════════════════════════════════════════════
REM build.bat — MASM64 编译脚本 (在 GitHub Actions windows runner 上运行)
REM ═══════════════════════════════════════════════════════════════

REM 设置 VS 环境
call "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\VC\Auxiliary\Build\vcvars64.bat"

REM 创建输出目录
if not exist build mkdir build

REM 编汇编
ml64 /c /Fobuild\main.obj main.asm
if errorlevel 1 (
    echo MASM compilation failed
    exit /b 1
)

REM 链接
link /SUBSYSTEM:WINDOWS /OUT:build\ProxySwitcher.exe /ENTRY:entry /MACHINE:X64 /LARGEADDRESSAWARE ^
    build\main.obj ^
    kernel32.lib user32.lib shell32.lib advapi32.lib wininet.lib

if errorlevel 1 (
    echo Linking failed
    exit /b 1
)

echo Build successful: build\ProxySwitcher.exe
