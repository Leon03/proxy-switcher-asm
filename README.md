# Proxy Switcher (ASM)

纯 x64 汇编实现的 Windows 系统代理切换工具。

## 功能
- 🖥 **系统托盘** — 启动后最小化到托盘，无窗口
- 🖱 **右键菜单** — 代理开启/关闭/切换，带勾选状态
- ⚡ **全局热键** — Ctrl+Shift+P 快速切换代理
- 🔄 **开机启动** — 通过注册表 Run 键，菜单内切换
- 🎯 **双击托盘** — 打开 Windows 代理设置页
- ⚡ **零依赖** — 纯 Win32 API，最终 exe ~20KB

## 构建
GitHub Actions 自动编译（windows-latest runner），push 到 main 触发 CI。

## 技术细节
- **语言**: MASM x64 (`ml64.exe`)
- **子系统**: GUI (无控制台窗口)
- **代理控制**: 注册表 `HKCU\...\Internet Settings` + `InternetSetOption` 刷新
- **托盘**: `Shell_NotifyIcon` + `NOTIFYICONDATA`
- **开机启动**: 注册表 `HKCU\...\Run`
- **热键**: `RegisterHotKey` / `UnregisterHotKey`
