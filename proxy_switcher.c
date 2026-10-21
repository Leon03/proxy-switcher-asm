/*
 * Proxy Switcher — Windows 系统代理切换工具
 * 纯 C 实现，零依赖，MSVC 编译
 * 功能: 系统托盘 + 右键菜单 + 全局热键 + 开机启动
 */

#define WIN32_LEAN_AND_MEAN
#include <windows.h>
#include <shellapi.h>
#include <wininet.h>
#include <regstr.h>

#pragma comment(lib, "shell32.lib")
#pragma comment(lib, "advapi32.lib")
#pragma comment(lib, "wininet.lib")

// ── 常量 ──
#define APP_NAME        L"Proxy Switcher"
#define CLASS_NAME      L"ProxySwitcherWnd"
#define REG_PATH        L"Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings"
#define REG_AUTORUN     L"Software\\Microsoft\\Windows\\CurrentVersion\\Run"
#define AUTORUN_NAME    L"ProxySwitcher"
#define DEFAULT_PROXY   L"127.0.0.1:7890"
#define DEFAULT_BYPASS  L"<local>"

#define WM_TRAYICON     (WM_USER + 4)
#define IDI_APP         100
#define IDM_PROXY_ON    2001
#define IDM_PROXY_OFF   2002
#define IDM_PROXY_TOGGLE 2003
#define IDM_AUTOSTART   2004
#define IDM_EXIT        2005
#define HOTKEY_ID       2003

// ── 全局变量 ──
HINSTANCE g_hInst = NULL;
HWND      g_hWnd = NULL;
HMENU     g_hMenu = NULL;
NOTIFYICONDATA g_nid = {0};

// ── 前向声明 ──
LRESULT CALLBACK WndProc(HWND, UINT, WPARAM, LPARAM);
void InitTrayIcon(void);
void SetProxy(int enabled);
int GetProxyEnabled(void);
void ToggleProxy(void);
void UpdateMenuChecks(void);
void ToggleAutoStart(void);
int IsAutoStartEnabled(void);
void AddAutoStart(void);
void RemoveAutoStart(void);

// ══════════════════════════════════════════════════════════════════
// wWinMain
// ══════════════════════════════════════════════════════════════════
int APIENTRY wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                      LPWSTR lpCmdLine, int nCmdShow)
{
    (void)hPrevInstance;
    (void)lpCmdLine;
    (void)nCmdShow;

    g_hInst = hInstance;

    // 单实例检查
    HWND existing = FindWindow(CLASS_NAME, NULL);
    if (existing) {
        return 0;
    }

    // 注册窗口类
    WNDCLASSEXW wcex = {0};
    wcex.cbSize = sizeof(WNDCLASSEXW);
    wcex.style = CS_HREDRAW | CS_VREDRAW;
    wcex.lpfnWndProc = WndProc;
    wcex.hInstance = hInstance;
    wcex.hIcon = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APP));
    wcex.hCursor = LoadCursor(NULL, IDC_ARROW);
    wcex.hbrBackground = (HBRUSH)(COLOR_WINDOW + 1);
    wcex.lpszClassName = CLASS_NAME;
    wcex.hIconSm = LoadIcon(hInstance, MAKEINTRESOURCE(IDI_APP));
    RegisterClassExW(&wcex);

    // 创建隐藏窗口
    g_hWnd = CreateWindowExW(0, CLASS_NAME, APP_NAME, WS_OVERLAPPEDWINDOW,
                             0, 0, 0, 0, NULL, NULL, hInstance, NULL);

    // 创建菜单
    g_hMenu = CreatePopupMenu();

    // 初始化托盘
    InitTrayIcon();

    // 注册全局热键 Ctrl+Alt+P
    RegisterHotKey(g_hWnd, HOTKEY_ID, MOD_CONTROL | MOD_ALT, 'P');

    // 消息循环
    MSG msg;
    while (GetMessage(&msg, NULL, 0, 0)) {
        TranslateMessage(&msg);
        DispatchMessage(&msg);
    }

    // 清理
    UnregisterHotKey(g_hWnd, HOTKEY_ID);
    Shell_NotifyIcon(NIM_DELETE, &g_nid);

    return (int)msg.wParam;
}

// ══════════════════════════════════════════════════════════════════
// WndProc
// ══════════════════════════════════════════════════════════════════
LRESULT CALLBACK WndProc(HWND hWnd, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
    // 热键
    if (uMsg == WM_HOTKEY) {
        if (wParam == HOTKEY_ID) {
            ToggleProxy();
        }
        return 0;
    }

    // 托盘消息
    if (uMsg == WM_TRAYICON) {
        UINT msg = LOWORD(lParam);
        if (msg == WM_RBUTTONUP) {
            POINT pt;
            GetCursorPos(&pt);
            SetForegroundWindow(hWnd);
            TrackPopupMenu(g_hMenu, TPM_LEFTALIGN | TPM_RIGHTBUTTON,
                           pt.x, pt.y, 0, hWnd, NULL);
        }
        else if (msg == WM_LBUTTONDBLCLK) {
            // 打开 Windows 代理设置
            ShellExecuteW(NULL, L"open", L"ms-settings:network-proxy", NULL, NULL, SW_SHOWNORMAL);
        }
        return 0;
    }

    // 关闭
    if (uMsg == WM_DESTROY) {
        Shell_NotifyIcon(NIM_DELETE, &g_nid);
        PostQuitMessage(0);
        return 0;
    }

    // 菜单命令
    if (uMsg == WM_COMMAND) {
        WORD id = LOWORD(wParam);
        switch (id) {
            case IDM_PROXY_ON:  SetProxy(1); break;
            case IDM_PROXY_OFF: SetProxy(0); break;
            case IDM_PROXY_TOGGLE: ToggleProxy(); break;
            case IDM_AUTOSTART: ToggleAutoStart(); break;
            case IDM_EXIT: DestroyWindow(hWnd); break;
        }
        return 0;
    }

    return DefWindowProc(hWnd, uMsg, wParam, lParam);
}

// ══════════════════════════════════════════════════════════════════
// SetProxy — 设置系统代理
// ══════════════════════════════════════════════════════════════════
void SetProxy(int enabled)
{
    HKEY hKey;
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, REG_PATH, 0, KEY_SET_VALUE, &hKey);
    if (res != ERROR_SUCCESS) return;

    // 只切换 ProxyEnable 开关，不覆盖用户已有的 ProxyServer 地址
    DWORD val = enabled;
    RegSetValueExW(hKey, L"ProxyEnable", 0, REG_DWORD, (BYTE*)&val, sizeof(DWORD));
    RegCloseKey(hKey);

    // 刷新
    InternetSetOptionW(NULL, INTERNET_OPTION_SETTINGS_CHANGED, NULL, 0);
    InternetSetOptionW(NULL, INTERNET_OPTION_REFRESH, NULL, 0);

    UpdateMenuChecks();
}

// ══════════════════════════════════════════════════════════════════
// GetProxyEnabled
// ══════════════════════════════════════════════════════════════════
int GetProxyEnabled(void)
{
    HKEY hKey;
    DWORD val = 0, size = sizeof(DWORD);
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, REG_PATH, 0, KEY_READ, &hKey);
    if (res != ERROR_SUCCESS) return 0;

    RegQueryValueExW(hKey, L"ProxyEnable", NULL, NULL, (BYTE*)&val, &size);
    RegCloseKey(hKey);
    return (int)val;
}

// ══════════════════════════════════════════════════════════════════
void ToggleProxy(void)
{
    SetProxy(!GetProxyEnabled());
}

// ══════════════════════════════════════════════════════════════════
void UpdateMenuChecks(void)
{
    int enabled = GetProxyEnabled();
    CheckMenuItem(g_hMenu, IDM_PROXY_ON,  enabled ? MF_CHECKED : MF_UNCHECKED);
    CheckMenuItem(g_hMenu, IDM_PROXY_OFF, enabled ? MF_UNCHECKED : MF_CHECKED);
    CheckMenuItem(g_hMenu, IDM_AUTOSTART, IsAutoStartEnabled() ? MF_CHECKED : MF_UNCHECKED);
}

// ══════════════════════════════════════════════════════════════════
// 开机启动
// ══════════════════════════════════════════════════════════════════
int IsAutoStartEnabled(void)
{
    HKEY hKey;
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, REG_AUTORUN, 0, KEY_READ, &hKey);
    if (res != ERROR_SUCCESS) return 0;

    res = RegQueryValueExW(hKey, AUTORUN_NAME, NULL, NULL, NULL, NULL);
    RegCloseKey(hKey);
    return (res == ERROR_SUCCESS) ? 1 : 0;
}

void AddAutoStart(void)
{
    HKEY hKey;
    WCHAR path[MAX_PATH];
    GetModuleFileNameW(NULL, path, MAX_PATH);

    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, REG_AUTORUN, 0, KEY_SET_VALUE, &hKey);
    if (res == ERROR_SUCCESS) {
        RegSetValueExW(hKey, AUTORUN_NAME, 0, REG_SZ,
                       (BYTE*)path, (DWORD)((wcslen(path)+1)*sizeof(WCHAR)));
        RegCloseKey(hKey);
    }
}

void RemoveAutoStart(void)
{
    HKEY hKey;
    LONG res = RegOpenKeyExW(HKEY_CURRENT_USER, REG_AUTORUN, 0, KEY_SET_VALUE, &hKey);
    if (res == ERROR_SUCCESS) {
        RegDeleteValueW(hKey, AUTORUN_NAME);
        RegCloseKey(hKey);
    }
}

void ToggleAutoStart(void)
{
    if (IsAutoStartEnabled()) RemoveAutoStart();
    else AddAutoStart();
    UpdateMenuChecks();
}

// ══════════════════════════════════════════════════════════════════
// InitTrayIcon
// ══════════════════════════════════════════════════════════════════
void InitTrayIcon(void)
{
    ZeroMemory(&g_nid, sizeof(g_nid));
    g_nid.cbSize = sizeof(NOTIFYICONDATAW);
    g_nid.hWnd = g_hWnd;
    g_nid.uID = IDI_APP;
    g_nid.uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP;
    g_nid.uCallbackMessage = WM_TRAYICON;
    g_nid.hIcon = LoadIcon(g_hInst, MAKEINTRESOURCE(IDI_APP));
    wcscpy_s(g_nid.szTip, ARRAYSIZE(g_nid.szTip), APP_NAME);

    Shell_NotifyIcon(NIM_ADD, &g_nid);

    // 菜单项
    AppendMenuW(g_hMenu, MF_STRING, IDM_PROXY_ON, L"代理开启");
    AppendMenuW(g_hMenu, MF_STRING, IDM_PROXY_OFF, L"代理关闭");
    AppendMenuW(g_hMenu, MF_STRING, IDM_PROXY_TOGGLE, L"切换代理 (Ctrl+Alt+P)");
    AppendMenuW(g_hMenu, MF_SEPARATOR, 0, NULL);
    AppendMenuW(g_hMenu, MF_STRING, IDM_AUTOSTART, L"开机启动");
    AppendMenuW(g_hMenu, MF_SEPARATOR, 0, NULL);
    AppendMenuW(g_hMenu, MF_STRING, IDM_EXIT, L"退出");

    UpdateMenuChecks();
}