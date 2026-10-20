# Proxy Switcher

轻量级系统代理切换工具，支持 Windows 和 Linux(XFCE)，纯 C 实现。

## 功能

### Windows
- 🖥 **系统托盘** — 启动后最小化到托盘，无窗口
- 🖱 **右键菜单** — 代理开启 / 关闭 / 切换，带勾选状态显示
- ⚡ **全局热键** — `Ctrl+Alt+P` 快速切换代理
- 🔄 **开机启动** — 注册表 `Run` 键，菜单内一键切换
- 🎯 **双击托盘** — 打开 Windows 代理设置页 (`ms-settings:network-proxy`)

### Linux (XFCE)
- 🖥 **系统托盘** — GTK3 `GtkStatusIcon`
- 🖱 **右键菜单** — 代理开启 / 关闭 / 切换
- 🎯 **双击托盘** — 切换代理
- 🔧 **代理控制** — `xfconf-query` 设置 xsettings 代理

## 下载

从 [Releases](https://github.com/Leon03/proxy-switcher-asm/releases/latest) 下载对应平台的二进制文件。

- **Windows**: `ProxySwitcher.exe`（双击运行，零依赖）
- **Linux**: `proxy_switcher_linux`（需安装 `libgtk-3-0`）

## 构建

### Windows (需 Visual Studio)
```cmd
build.bat
```

### Linux (需 GTK3 开发库)
```bash
sudo apt install libgtk-3-dev
gcc -O2 -o proxy_switcher_linux proxy_switcher_linux.c $(pkg-config --cflags --libs gtk+-3.0)
```

## 技术细节

| 项目 | Windows | Linux(XFCE) |
|------|---------|-------------|
| **语言** | C (MSVC `cl.exe`) | C (GCC) |
| **托盘** | `Shell_NotifyIcon` + `NOTIFYICONDATA` | `GtkStatusIcon` (GTK3) |
| **代理控制** | 注册表 + `InternetSetOption` 刷新 | `xfconf-query` (xsettings) |
| **热键** | `RegisterHotKey` (`Ctrl+Alt+P`) | 双击托盘 |
| **开机启动** | 注册表 `HKCU\...\Run` | — |
| **单实例** | `FindWindow` 检查 | — |
| **大小** | ~102KB | ~20KB |

## CI/CD

- **平台**: GitHub Actions
- **Windows**: `windows-latest` + MSVC
- **Linux**: `ubuntu-latest` + GCC + GTK3
- **触发**: push 到 `master` / 手动触发
- **产物**: 两个平台的二进制自动发布到 Release
