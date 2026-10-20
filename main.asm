; ═════════════════════════════════════════════════════════════════
; Proxy Switcher — 纯汇编实现 (MASM x64)
; 无外部依赖，内联所有结构体和常量
; 功能: 系统托盘 + 右键菜单 + 切换代理 + 开机启动 + 全局热键
; ═════════════════════════════════════════════════════════════════

; ── 结构体定义 ──
POINT struct
    x DWORD ?
    y DWORD ?
POINT ends

RECT struct
    left DWORD ?
    top DWORD ?
    right DWORD ?
    bottom DWORD ?
RECT ends

WNDCLASSEX struct
    cbSize DWORD ?
    style DWORD ?
    lpfnWndProc QWORD ?
    cbClsExtra DWORD ?
    cbWndExtra DWORD ?
    hInstance QWORD ?
    hIcon QWORD ?
    hCursor QWORD ?
    hbrBackground QWORD ?
    lpszMenuName QWORD ?
    lpszClassName QWORD ?
    hIconSm QWORD ?
WNDCLASSEX ends

MSG struct
    hwnd QWORD ?
    message DWORD ?
    wParam QWORD ?
    lParam QWORD ?
    time DWORD ?
    pt POINT <>
MSG ends

NOTIFYICONDATA struct
    cbSize DWORD ?
    hwnd QWORD ?
    uID DWORD ?
    uFlags DWORD ?
    uCallbackMessage DWORD ?
    hIcon QWORD ?
    szTip BYTE 128 dup(?)
    dwState DWORD ?
    dwStateMask DWORD ?
    szInfo BYTE 256 dup(?)
    uVersion DWORD ?
    szInfoTitle BYTE 64 dup(?)
    dwInfoFlags DWORD ?
    guidItem GUID <>
    hBalloonIcon QWORD ?
NOTIFYICONDATA ends

; ── 常量定义 ──
; Window
CS_HREDRAW        equ 0002h
CS_VREDRAW        equ 0001h
WS_OVERLAPPEDWINDOW equ 00CF0000h
SW_SHOWNORMAL     equ 1
COLOR_WINDOW      equ 5
IDC_ARROW         equ 32512

; Messages
WM_DESTROY        equ 0002h
WM_COMMAND        equ 0111h
WM_RBUTTONUP      equ 0205h
WM_LBUTTONDBLCLK  equ 0203h
WM_HOTKEY         equ 0312h

; NotifyIcon
NIM_ADD           equ 00000000h
NIM_MODIFY        equ 00000001h
NIM_DELETE        equ 00000002h
NIF_ICON          equ 00000002h
NIF_MESSAGE       equ 00000001h
NIF_TIP           equ 00000004h
NIF_INFO          equ 00000010h

; Menu
MF_STRING         equ 00000000h
MF_SEPARATOR      equ 00000800h
MF_CHECKED        equ 00000008h
MF_UNCHECKED      equ 00000000h
TPM_LEFTALIGN     equ 00000000h
TPM_RIGHTBUTTON   equ 00000002h

; Hotkey
MOD_CONTROL       equ 0002h
MOD_SHIFT         equ 0004h

; Registry
HKEY_CURRENT_USER equ 80000001h
KEY_READ          equ 00020019h
KEY_SET_VALUE     equ 00000002h
REG_DWORD         equ 00000004h
REG_SZ            equ 00000001h
ERROR_SUCCESS     equ 0

; Internet Options
INTERNET_OPTION_SETTINGS_CHANGED equ 39
INTERNET_OPTION_REFRESH          equ 37

; IDs
IDI_APP           equ 100
WM_TRAYICON       equ 0400h + 4
IDM_PROXY_ON      equ 2001
IDM_PROXY_OFF     equ 2002
IDM_PROXY_TOGGLE  equ 2003
IDM_AUTOSTART     equ 2004
IDM_EXIT          equ 2005

; ── 数据段 ──
.data
className       db "ProxySwitcherWnd", 0
appName         db "Proxy Switcher", 0
regPath         db "Software\Microsoft\Windows\CurrentVersion\Internet Settings", 0
regAutoRun      db "Software\Microsoft\Windows\CurrentVersion\Run", 0
regValueEnable  db "ProxyEnable", 0
regValueServer  db "ProxyServer", 0
regValueOverride db "ProxyOverride", 0
autoRunName     db "ProxySwitcher", 0
proxyServer     db "127.0.0.1:7890", 0
proxyOverride   db "<local>", 0

wcex            WNDCLASSEX <>
msg             MSG <>
hInst           dq 0
hWndMain        dq 0
hMenu           dq 0
hPopup          dq 0
notifyData      NOTIFYICONDATA <>
pt              POINT <>
cs              WNDCLASSEX <>

; ── 代码段 ──
.code

; ════════════════════════════════════════════════════════════════════
; WinMain
; ═══════════════════════════════════════════════════════════════════
WinMain proc

    ; 获取模块句柄
    invoke GetModuleHandle, 0
    mov hInst, rax

    ; 注册窗口类
    mov cs.cbSize, sizeof WNDCLASSEX
    lea rax, className
    mov cs.lpszClassName, rax
    mov cs.style, CS_HREDRAW or CS_VREDRAW
    lea rax, WndProc
    mov cs.lpfnWndProc, rax
    mov rax, hInst
    mov cs.hInstance, rax
    invoke LoadIcon, hInst, IDI_APP
    mov cs.hIcon, rax
    invoke LoadCursor, 0, IDC_ARROW
    mov cs.hCursor, rax
    mov cs.hbrBackground, COLOR_WINDOW+1
    mov cs.lpszMenuName, 0
    mov cs.cbClsExtra, 0
    mov cs.cbWndExtra, 0
    invoke RegisterClassEx, ADDR cs

    ; 创建隐藏窗口
    invoke CreateWindowEx, 0, ADDR className, ADDR appName, \
            WS_OVERLAPPEDWINDOW, 0, 0, 0, 0, 0, 0, hInst, 0
    mov hWndMain, rax

    ; 创建托盘菜单
    invoke CreatePopupMenu
    mov hPopup, rax

    ; 初始化托盘图标
    invoke InitTrayIcon

    ; 注册全局热键 Ctrl+Shift+P
    invoke RegisterHotKey, hWndMain, IDM_PROXY_TOGGLE, \
        MOD_CONTROL or MOD_SHIFT, 'P'

    ; 消息循环
    msg_loop:
    invoke GetMessage, ADDR msg, 0, 0, 0
    cmp rax, 0
    je exit_loop
    invoke TranslateMessage, ADDR msg
    invoke DispatchMessage, ADDR msg
    jmp msg_loop

    exit_loop:
    ; 清理
    invoke UnregisterHotKey, hWndMain, IDM_PROXY_TOGGLE
    invoke ExitProcess, msg.wParam
    ret

WinMain endp

; ════════════════════════════════════════════════════════════════════
; WndProc — 窗口过程
; ════════════════════════════════════════════════════════════════════
WndProc proc hWnd:HWND, uMsg:UINT, wParam:WPARAM, lParam:LPARAM

    ; ── 热键消息 ──
    cmp uMsg, WM_HOTKEY
    jne check_tray
        ; wParam = hotkey ID
        cmp wParam, IDM_PROXY_TOGGLE
        jne defproc
            invoke ToggleProxy
            jmp defproc

    ; ── 托盘消息 ──
    check_tray:
    cmp uMsg, WM_TRAYICON
    jne check_destroy

        ; lParam 的低字包含鼠标事件
        mov rax, lParam
        and rax, 0FFFFh

        ; 右键弹菜单
        cmp eax, WM_RBUTTONUP
        jne check_lbutton
            invoke GetCursorPos, ADDR pt
            invoke SetForegroundWindow, hWnd
            invoke TrackPopupMenu, hPopup, TPM_LEFTALIGN or TPM_RIGHTBUTTON, \
                pt.x, pt.y, 0, hWnd, 0
            jmp defproc

        ; 双击托盘 — 打开 Windows 代理设置
        check_lbutton:
        cmp eax, WM_LBUTTONDBLCLK
        jne defproc
            ; 打开 Windows 设置 -> 代理
            invoke ShellExecuteA, 0, 0, \
                CSTR("ms-settings:network-proxy"), 0, 0, SW_SHOWNORMAL
            jmp defproc

    check_destroy:
    cmp uMsg, WM_DESTROY
    jne check_command
        ; 移除托盘图标
        invoke Shell_NotifyIcon, NIM_DELETE, ADDR notifyData
        invoke PostQuitMessage, 0
        xor rax, rax
        ret

    ; ── 菜单命令 ──
    check_command:
    cmp uMsg, WM_COMMAND
    jne defproc
        mov rax, wParam
        and rax, 0FFFFh

        cmp eax, IDM_PROXY_ON
        jne check_off
            invoke SetProxy, 1
            jmp defproc
        check_off:
        cmp eax, IDM_PROXY_OFF
        jne check_toggle
            invoke SetProxy, 0
            jmp defproc
        check_toggle:
        cmp eax, IDM_PROXY_TOGGLE
        jne check_autostart
            invoke ToggleProxy
            jmp defproc
        check_autostart:
        cmp eax, IDM_AUTOSTART
        jne check_exit_cmd
            invoke ToggleAutoStart
            jmp defproc
        check_exit_cmd:
        cmp eax, IDM_EXIT
        jne defproc
            invoke DestroyWindow, hWnd
            jmp defproc

    defproc:
    invoke DefWindowProc, hWnd, uMsg, wParam, lParam
    ret

WndProc endp

; ════════════════════════════════════════════════════════════════════
; SetProxy — 设置系统代理 (0=关, 1=开)
; ════════════════════════════════════════════════════════════════════
SetProxy proc uses rbx rsi rdi enabled:DWORD
    local hKey:qword
    local dwValue:DWORD

    ; 打开注册表
    invoke RegOpenKeyExA, HKEY_CURRENT_USER, ADDR regPath, 0, \
        KEY_SET_VALUE, ADDR hKey
    test rax, rax
    jnz fail_open

    ; 写 ProxyEnable
    mov eax, enabled
    mov dwValue, eax
    invoke RegSetValueExA, hKey, ADDR regValueEnable, 0, \
        REG_DWORD, ADDR dwValue, sizeof DWORD

    ; 如果启用代理，写 ProxyServer 和 ProxyOverride
    cmp enabled, 0
    je skip_server

    invoke RegSetValueExA, hKey, ADDR regValueServer, 0, \
        REG_SZ, ADDR proxyServer, sizeof proxyServer
    invoke RegSetValueExA, hKey, ADDR regValueOverride, 0, \
        REG_SZ, ADDR proxyOverride, sizeof proxyOverride

    skip_server:
    invoke RegCloseKey, hKey

    ; 刷新系统代理设置
    invoke InternetSetOptionW, 0, INTERNET_OPTION_SETTINGS_CHANGED, 0, 0
    invoke InternetSetOptionW, 0, INTERNET_OPTION_REFRESH, 0, 0

    ; 更新菜单勾选状态
    invoke UpdateMenuChecks
    xor rax, rax
    ret

    fail_open:
    mov rax, 1
    ret

SetProxy endp

; ════════════════════════════════════════════════════════════════════
; ToggleProxy — 切换代理开关
; ════════════════════════════════════════════════════════════════════
ToggleProxy proc
    local currentEnabled:DWORD

    invoke GetProxyEnabled
    mov currentEnabled, eax
    xor eax, 1
    invoke SetProxy, eax
    ret

ToggleProxy endp

; ════════════════════════════════════════════════════════════════════
; GetProxyEnabled — 读取当前代理状态 (返回 0 或 1)
; ════════════════════════════════════════════════════════════════════
GetProxyEnabled proc
    local hKey:qword
    local dwValue:DWORD
    local cbData:DWORD

    mov dwValue, 0
    invoke RegOpenKeyExA, HKEY_CURRENT_USER, ADDR regPath, 0, \
        KEY_READ, ADDR hKey
    test rax, rax
    jnz fail

    mov cbData, sizeof DWORD
    invoke RegQueryValueExA, hKey, ADDR regValueEnable, 0, 0, \
        ADDR dwValue, ADDR cbData
    invoke RegCloseKey, hKey

    mov eax, dwValue
    ret

    fail:
    xor eax, eax
    ret

GetProxyEnabled endp

; ════════════════════════════════════════════════════════════════════
; UpdateMenuChecks — 更新菜单勾选
; ════════════════════════════════════════════════════════════════════
UpdateMenuChecks proc
    local enabled:DWORD

    invoke GetProxyEnabled
    mov enabled, eax

    ; 代理开启菜单项
    mov eax, enabled
    test eax, eax
    jz clear_on
    invoke CheckMenuItem, hPopup, IDM_PROXY_ON, MF_CHECKED
    jmp check_off_menu
    clear_on:
    invoke CheckMenuItem, hPopup, IDM_PROXY_ON, MF_UNCHECKED

    check_off_menu:
    mov eax, enabled
    test eax, eax
    jnz clear_off
    invoke CheckMenuItem, hPopup, IDM_PROXY_OFF, MF_CHECKED
    jmp check_autostart_menu
    clear_off:
    invoke CheckMenuItem, hPopup, IDM_PROXY_OFF, MF_UNCHECKED

    check_autostart_menu:
    invoke IsAutoStartEnabled
    test eax, eax
    jz clear_autostart
    invoke CheckMenuItem, hPopup, IDM_AUTOSTART, MF_CHECKED
    jmp done
    clear_autostart:
    invoke CheckMenuItem, hPopup, IDM_AUTOSTART, MF_UNCHECKED

    done:
    xor rax, rax
    ret

UpdateMenuChecks endp

; ════════════════════════════════════════════════════════════════════
; ToggleAutoStart — 切换开机启动
; ════════════════════════════════════════════════════════════════════
ToggleAutoStart proc
    invoke IsAutoStartEnabled
    test eax, eax
    jnz remove_autostart

    ; 添加开机启动
    invoke AddAutoStart
    jmp autostart_done

    remove_autostart:
    invoke RemoveAutoStart

    autostart_done:
    invoke UpdateMenuChecks
    xor rax, rax
    ret

ToggleAutoStart endp

; ════════════════════════════════════════════════════════════════════
; AddAutoStart — 添加开机启动注册表项
; ════════════════════════════════════════════════════════════════════
AddAutoStart proc
    local hKey:qword
    local exePath[MAX_PATH]:BYTE

    ; 获取当前 exe 路径
    invoke GetModuleFileNameA, 0, ADDR exePath, MAX_PATH

    ; 打开注册表 Run 键
    invoke RegOpenKeyExA, HKEY_CURRENT_USER, ADDR regAutoRun, 0, \
        KEY_SET_VALUE, ADDR hKey
    test rax, rax
    jnz add_fail

    invoke RegSetValueExA, hKey, ADDR autoRunName, 0, \
        REG_SZ, ADDR exePath, MAX_PATH
    invoke RegCloseKey, hKey

    xor rax, rax
    ret

    add_fail:
    mov rax, 1
    ret

AddAutoStart endp

; ════════════════════════════════════════════════════════════════════
; RemoveAutoStart — 删除开机启动注册表项
; ════════════════════════════════════════════════════════════════════
RemoveAutoStart proc
    local hKey:qword

    invoke RegOpenKeyExA, HKEY_CURRENT_USER, ADDR regAutoRun, 0, \
        KEY_SET_VALUE, ADDR hKey
    test rax, rax
    jnz remove_fail

    invoke RegDeleteValueA, hKey, ADDR autoRunName
    invoke RegCloseKey, hKey

    xor rax, rax
    ret

    remove_fail:
    mov rax, 1
    ret

RemoveAutoStart endp

; ════════════════════════════════════════════════════════════════════
; IsAutoStartEnabled — 检查是否已设置开机启动
; ════════════════════════════════════════════════════════════════════
IsAutoStartEnabled proc
    local hKey:qword

    invoke RegOpenKeyExA, HKEY_CURRENT_USER, ADDR regAutoRun, 0, \
        KEY_READ, ADDR hKey
    test rax, rax
    jnz not_enabled

    ; 尝试读取值
    invoke RegQueryValueExA, hKey, ADDR autoRunName, 0, 0, 0, 0
    invoke RegCloseKey, hKey

    ; 如果 RegQueryValueEx 成功返回 ERROR_SUCCESS (0)
    test rax, rax
    jnz not_enabled

    mov eax, 1
    ret

    not_enabled:
    xor eax, eax
    ret

IsAutoStartEnabled endp

; ════════════════════════════════════════════════════════════════════
; InitTrayIcon — 初始化系统托盘图标
; ════════════════════════════════════════════════════════════════════
InitTrayIcon proc
    ; 填充 NOTIFYICONDATA 结构
    mov notifyData.cbSize, sizeof NOTIFYICONDATA
    mov rax, hWndMain
    mov notifyData.hwnd, rax
    mov notifyData.uID, IDI_APP
    mov notifyData.uFlags, NIF_ICON or NIF_MESSAGE or NIF_TIP
    mov notifyData.uCallbackMessage, WM_TRAYICON
    mov rax, hInst
    mov rcx, IDI_APP
    invoke LoadIcon, rax, ecx
    mov notifyData.hIcon, rax
    lea rax, appName
    ; 复制提示文本
    invoke lstrcpy, ADDR notifyData.szTip, ADDR appName

    ; 添加托盘图标
    invoke Shell_NotifyIcon, NIM_ADD, ADDR notifyData

    ; 初始化菜单
    invoke AppendMenuA, hPopup, MF_STRING, IDM_PROXY_ON, CSTR("代理开启")
    invoke AppendMenuA, hPopup, MF_STRING, IDM_PROXY_OFF, CSTR("代理关闭")
    invoke AppendMenuA, hPopup, MF_STRING, IDM_PROXY_TOGGLE, CSTR("切换代理 (Ctrl+Shift+P)")
    invoke AppendMenuA, hPopup, MF_SEPARATOR, 0, 0
    invoke AppendMenuA, hPopup, MF_STRING, IDM_AUTOSTART, CSTR("开机启动")
    invoke AppendMenuA, hPopup, MF_SEPARATOR, 0, 0
    invoke AppendMenuA, hPopup, MF_STRING, IDM_EXIT, CSTR("退出")

    ; 更新菜单勾选
    invoke UpdateMenuChecks

    xor rax, rax
    ret

InitTrayIcon endp

; ════════════════════════════════════════════════════════════════════
; 入口点
; ════════════════════════════════════════════════════════════════════
entry proc
    ; 如果已有实例运行，退出
    invoke FindWindow, ADDR className, 0
    test rax, rax
    jz create_instance
    xor rax, rax
    ret

    create_instance:
    invoke WinMain
    ret

entry endp

end entry