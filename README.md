# Proxy Switcher

纯 C 实现的 Windows 系统代理切换工具，零依赖，单文件 exe。

## 功能

- 🖥 **系统托盘** — 启动后最小化到托盘，无窗口
- 🖱 **右键菜单** — 代理开启 / 关闭 / 切换，带勾选状态显示
- ⚡ **全局热键** — `Ctrl+Alt+P` 快速切换代理
- 🔄 **开机启动** — 注册表 `Run` 键，菜单内一键切换
- 🎯 **双击托盘** — 打开 Windows 代理设置页 (`ms-settings:network-proxy`)
- 🚀 **零依赖** — 纯 Win32 API，单 exe ~52KB

## 下载

从 [Releases](https://github.com/Leon03/proxy-switcher-asm/releases/latest) 页面下载 `ProxySwitcher.exe`，双击运行即可。

## 构建

GitHub Actions 自动编译（`windows-latest` runner），push 到 `master` 触发 CI/CD，自动发布 Release。

本地构建（需 Visual Studio）：
```cmd
build.bat
```

## 技术细节

| 项目 | 实现 |
|------|------|
| **语言** | C (MSVC `cl.exe`) |
| **子系统** | GUI (无控制台窗口) |
| **代理控制** | 注册表 `HKCU\...\Internet Settings` + `InternetSetOption` 刷新 |
| **托盘** | `Shell_NotifyIcon` + `NOTIFYICONDATA` |
| **开机启动** | 注册表 `HKCU\...\Run` |
| **热键** | `RegisterHotKey` / `UnregisterHotKey` |
| **单实例** | `FindWindow` 检查 |

## CI/CD

- **平台**: GitHub Actions
- **Runner**: `windows-latest`
- **触发**: push 到 `master` / 手动触发
- **产物**: `ProxySwitcher.exe` (artifact + release)
