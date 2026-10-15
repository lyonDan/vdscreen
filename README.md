# vdscreen

[![CI](https://github.com/lyonDan/vdscreen/actions/workflows/ci.yml/badge.svg)](https://github.com/lyonDan/vdscreen/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

在 macOS 上创建 **HiDPI 虚拟显示器**的命令行工具与菜单栏应用，适用于远程桌面、串流、无头主机，
或需要指定分辨率的额外屏幕。

- 内置 iPad、iPhone 与常用分辨率预设，也可自定义逻辑尺寸
- 支持 2× HiDPI；系统不支持时自动退回 1:1，并报告实际模式
- 横竖方向锁定、一键切换主屏
- 支持菜单栏、全局快捷键与 URL scheme

## 系统要求

- macOS 13 或更高；目前仅在 macOS 27 / Apple Silicon 上测试
- 预编译包仅支持 Apple Silicon；Intel Mac 需从源码构建
- 源码构建需要 Xcode Command Line Tools：`xcode-select --install`；预编译安装无需编译工具

> 本项目使用 Apple 私有 API `CGVirtualDisplay`，系统更新可能影响兼容性。

## 安装

### Homebrew（推荐）

```sh
brew install --cask lyonDan/tap/vdscreen
open /Applications/VDScreenBar.app
```

安装已签名并经 Apple 公证的预编译包，App 位于 `/Applications/VDScreenBar.app`，
命令行工具自动链接到 Homebrew 的 `bin` 目录。使用 `--appdir` 时，请相应调整 App 路径。

升级：`brew upgrade --cask lyonDan/tap/vdscreen`。

### 预编译包

```sh
curl -fsSL https://raw.githubusercontent.com/lyonDan/vdscreen/main/install.sh | zsh
```

脚本下载最新 Release，安装 App 到 `~/Applications/VDScreenBar.app`、命令行工具到 `~/bin/vdscreen`。

也可从 [Releases](https://github.com/lyonDan/vdscreen/releases) 下载 DMG 或 arm64 ZIP；
完整性校验见附件 `SHA256SUMS.txt`。

### 从源码构建

```sh
git clone https://github.com/lyonDan/vdscreen.git
cd vdscreen
./build.sh
./vdscreen install          # 命令行工具安装到 ~/bin
mkdir -p ~/Applications
cp -R VDScreenBar.app ~/Applications/
open ~/Applications/VDScreenBar.app
```

源码或脚本安装后，若找不到 `vdscreen` 命令，请将 `~/bin` 加入 `PATH`。

## 快速开始

```sh
vdscreen on                          # 默认开启 iPad mini 7，1133×744
vdscreen preset "iPhone 18 Pro"       # 切换预设
vdscreen on 1920x1080                 # 自定义逻辑尺寸
vdscreen orientation 竖屏             # 锁定竖屏，换预设后保持
vdscreen main                        # 虚拟屏与第一个其他显示器之间切换主屏
vdscreen status                      # 查看状态与实际 HiDPI 模式
vdscreen off                         # 关闭，并取消虚拟屏随登录自启
```

`on` 开启后由 launchd 托管，无需保持终端打开。`orientation auto` 取消方向锁定，跟随预设方向。

## 命令行参考

| 命令 | 说明 |
| --- | --- |
| `vdscreen on [宽x高] [名字]` | 开启或切换虚拟屏，可临时指定逻辑尺寸与名字 |
| `vdscreen off` | 关闭并移除 LaunchAgent |
| `vdscreen restart` | 重启 |
| `vdscreen status` | 查看服务、显示器与当前尺寸（默认命令） |
| `vdscreen state` | 机器可读状态：`on <名字> <宽x高>` 或 `off` |
| `vdscreen presets` | 列出全部预设及尺寸 |
| `vdscreen preset <名字>` | 按预设开启 |
| `vdscreen orientation [横屏\|竖屏\|auto]` | 查看或设置方向锁定 |
| `vdscreen main` | 切换主屏，分辨率不变 |
| `vdscreen config` | 查看配置 |
| `vdscreen set <size\|name\|core> <值>` | 修改默认尺寸、名字或核心路径 |
| `vdscreen install` / `uninstall` | 安装 / 卸载 `~/bin/vdscreen`；卸载时同时关闭虚拟屏 |

## 菜单栏与快捷键

`VDScreenBar.app` 与命令行共享状态和配置，提供开关、预设、自定义分辨率、横竖切换、主屏切换，
以及「在 Dock 显示图标」「登录时自动启动」选项。

| 快捷键 | 操作 |
| --- | --- |
| `⌥⌘0` | 开 / 关 |
| `⌥⌘R` | 横竖切换 |
| `⌥⌘M` | 切换主屏 |
| `⌥⌘1`…`⌥⌘9` | 切换到预设文件中的第 1…9 条预设 |
| `⌃⌥⌘V` | 在鼠标处弹出完整菜单 |

快捷键无需辅助功能权限，操作后会显示结果提示。竖屏等较窄的主屏可能让菜单栏图标被隐藏，
此时可用快捷键、Dock 图标，或从 Spotlight 重新打开应用来弹出菜单。

也可通过 `open 'vdscreen://<命令>'` 调用应用，支持 `on`、`off`、`toggle`、`main`、`menu`、
`orientation/<横屏|竖屏|auto>`、`preset/<名字>`、`size/<宽x高>`。URL 需在 Mac 上执行。

## 预设与配置

预设保存在 `~/.config/vdscreen/presets`，首次运行自动生成，每行格式为 `名字 = 宽x高`：

```text
iPad mini 7 = 1133x744
我的屏幕 = 1600x900
```

使用 `vdscreen presets` 查看完整列表。修改后命令行立即生效，菜单栏可点击「重新载入预设」。
iPad 预设默认横屏，iPhone 默认竖屏；iPhone 使用像素尺寸作为逻辑画布，以容纳 Mac 窗口并支持 HiDPI。

| 路径 | 说明 |
| --- | --- |
| `~/.config/vdscreen/config` | 默认配置：`LABEL`、`CORE`、`NAME`、`SIZE` 等 shell 变量 |
| `~/.config/vdscreen/presets` | 自定义预设 |
| `~/Library/LaunchAgents/io.github.lyondan.vdscreen.plist` | 虚拟屏的 LaunchAgent |
| `/tmp/vdscreen.log`、`/tmp/vdscreen.err` | 核心输出与错误日志 |
| `/tmp/vdscreen-bar.log` | 菜单栏应用与快捷键日志 |

## 故障排查与限制

先运行 `vdscreen status` 查看状态，再检查上述日志。

| 现象 | 处理 |
| --- | --- |
| 画面发软，显示「非 HiDPI」 | 系统未提供该尺寸的 HiDPI 模式，尝试更大的尺寸 |
| 提示「核心没有在预期时间内就绪」 | 查看 `/tmp/vdscreen.err`，检查是否已有同一身份的虚拟屏运行 |
| 快捷键无反应 | 在 `/tmp/vdscreen-bar.log` 中查找「注册失败」，检查组合是否被占用 |
| 菜单栏看不到图标 | 使用 `⌃⌥⌘V` 或重新打开应用弹出菜单 |

- 高度小于 480 的尺寸会按宽高比放大到高 480。
- 更换尺寸会被系统视为新显示器，窗口不会自动迁移；同一尺寸反复切换可保留布局。
- 同一时刻不能创建两块身份完全相同的虚拟屏。
- 仅负责创建和控制虚拟屏，不提供远程串流、窗口布局或亮度控制。

## 卸载

Homebrew 安装：

```sh
vdscreen off
brew uninstall --cask lyonDan/tap/vdscreen
```

源码或脚本安装：

```sh
vdscreen uninstall
rm -rf ~/Applications/VDScreenBar.app
```

如启用过「登录时自动启动」，请先关闭。配置与预设默认保留，可按需删除：`rm -rf ~/.config/vdscreen`。

## 开发

```sh
./build.sh                                 # 编译核心与菜单栏 App，默认 ad-hoc 签名
tests/unit.sh                              # 单元测试，不操作真实显示器
tests/integration.sh --yes                 # 集成测试，需图形会话并操作虚拟屏
tests/integration.sh --yes --all           # 额外验证全部预设
```

构建时可用 `VERSION` 指定版本号、`SIGN_IDENTITY` 指定签名证书。
CI 运行单元测试并检查构建；本地提交前测试可通过 `git config core.hooksPath .githooks` 启用。

## 致谢

私有 API 用法参考了以下开源项目：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）

## 许可证

[MIT](LICENSE)
