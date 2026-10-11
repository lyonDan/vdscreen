# vdscreen

[![CI](https://github.com/lyonDan/vdscreen/actions/workflows/ci.yml/badge.svg)](https://github.com/lyonDan/vdscreen/actions/workflows/ci.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

在 macOS 上创建 **HiDPI 虚拟显示器**的命令行工具与菜单栏应用。适用于没有物理显示器的 Mac（远程桌面、
串流、无头主机），或需要一块指定分辨率、指定缩放的额外屏幕。

- 以 iPad、iPhone 的真实逻辑分辨率预设，一条命令切换
- 真 HiDPI：背板为逻辑分辨率的 2 倍，系统无法提供时自动退回 1:1，并如实报告
- 横竖屏切换、界面缩放
- 菜单栏应用，另有全局快捷键、URL scheme，菜单栏图标被挤掉时仍可操作
- 无第三方依赖，只需系统自带的编译工具

> **注意**：本项目依赖 Apple 私有 API `CGVirtualDisplay`，不受兼容性承诺保护，系统更新可能使其失效。
> 详见[已知限制](#已知限制)。

## 系统要求

- macOS 13 或更高（最低部署目标为 13.0；仅在 macOS 27、Apple Silicon 上测试过）
- 从源码构建（含 Homebrew 安装）需要 Xcode **Command Line Tools**：`xcode-select --install`。
  不需要完整的 Xcode。Homebrew 还要求 Command Line Tools 的版本与当前 macOS 匹配，
  见[故障排查](#故障排查)；不想安装编译工具可使用[预编译包](#预编译包)

## 安装

### Homebrew（推荐）

```sh
brew install lyonDan/tap/vdscreen
```

formula 在本机从源码编译，不下载二进制，因此不会触发 Gatekeeper。命令行工具装到 `$(brew --prefix)/bin/vdscreen`。
菜单栏应用编译在 formula 的目录里，复制出来即可使用：

```sh
cp -R "$(brew --prefix vdscreen)/VDScreenBar.app" ~/Applications/
open ~/Applications/VDScreenBar.app
```

### 从源码构建

```sh
git clone https://github.com/lyonDan/vdscreen.git && cd vdscreen
./build.sh                  # 生成 vdscreen-core 与 VDScreenBar.app
./vdscreen install          # 命令行工具安装到 ~/bin
cp -R VDScreenBar.app ~/Applications/
```

### 预编译包

[Releases](https://github.com/lyonDan/vdscreen/releases) 提供 `VDScreenBar-<版本>-arm64.zip`（仅 Apple Silicon，
Intel Mac 请从源码构建）。包内的 App 使用 Developer ID 签名并经 Apple 公证，解压后可直接打开，
Gatekeeper 不会拦截：

```sh
unzip VDScreenBar-<版本>-arm64.zip && cp -R VDScreenBar.app ~/Applications/
```

若校验包的完整性，可对照 Release 附件中的 `SHA256SUMS.txt`。

## 快速开始

```sh
vdscreen on                          # 按默认配置开启（iPad mini 7，1133×744）
vdscreen preset "iPhone 18 Pro"      # 切换到预设
vdscreen rotate                      # 横竖屏切换
vdscreen zoom 120                    # 界面放大到 120%
vdscreen status                      # 查看状态
vdscreen off                         # 关闭
```

```
$ vdscreen preset "iPad mini 7"
已就绪："iPad mini 7"  displayID=67  UI 1133x744  背板 2266x1488  HiDPI
  实际: 背板 2266x1488 / 逻辑 1133x744 —— HiDPI
```

## 命令行参考

| 命令 | 说明 |
| --- | --- |
| `vdscreen on [宽x高] [名字]` | 开启，可临时指定逻辑尺寸与显示器名字；已开启时即切换 |
| `vdscreen off` | 关闭，并卸下 LaunchAgent（之后不再随登录自启） |
| `vdscreen restart` | 重启 |
| `vdscreen status` | 服务、进程、显示器、当前尺寸（默认命令） |
| `vdscreen state` | 机器可读：`on <名字> <宽x高>` 或 `off` |
| `vdscreen presets` | 列出预设 |
| `vdscreen preset <名字>` | 按预设开启 |
| `vdscreen rotate` | 横竖屏切换，保持当前缩放 |
| `vdscreen zoom [倍数\|in\|out\|max\|reset]` | 界面缩放；不带参数显示当前值与清晰上限 |
| `vdscreen config` | 查看配置 |
| `vdscreen set <size\|name\|core> <值>` | 修改默认尺寸 / 名字 / 核心路径 |
| `vdscreen install` / `uninstall` | 安装 / 卸载 `~/bin/vdscreen` |

`vdscreen on` 开启后由 launchd 托管，跨终端、跨登录存活；`off` 会移除 LaunchAgent，关闭后不会自动回来。

## 菜单栏应用

`VDScreenBar.app` 是纯菜单栏应用（`LSUIElement`，默认没有 Dock 图标和窗口）。它只是 `vdscreen` 命令行的前端，
与命令行共享同一份状态和配置。菜单包含：当前状态、关闭、横竖切换、界面缩放子菜单、预设列表（当前项带 ✓）、
自定义分辨率、重新载入预设、打开配置目录，以及「在 Dock 显示图标」「登录时自动启动」两个开关。

### 菜单栏图标不可见时

竖屏虚拟屏的逻辑宽度很小，macOS 对放不下的菜单栏图标是直接隐藏。因此除菜单栏图标外，还提供下列独立入口：

| 入口 | 用法 |
| --- | --- |
| 全局快捷键 | `⌥⌘0` 开/关 · `⌥⌘R` 横竖切换 · `⌥⌘=` / `⌥⌘-` 放大 / 缩小界面 · `⌥⌘1`…`⌥⌘9` 切到第 1…9 条预设 · `⌃⌥⌘V` 在鼠标处弹出完整菜单 |
| 悬浮提示 | 快捷键操作后，屏幕下方显示结果，如「✓ iPad mini 7 · 1133x744 · 横屏 · HiDPI」 |
| URL scheme | `open vdscreen://rotate`，见下 |
| Dock 图标 | 在菜单中勾选「在 Dock 显示图标」；点击或右键均可弹出菜单 |
| 重新打开应用 | 从 Spotlight / 启动台再次打开，会在鼠标处弹出菜单 |
| 命令行 | `vdscreen rotate`；远程时可通过 SSH 执行 |

快捷键通过 Carbon `RegisterEventHotKey` 注册，**不需要辅助功能权限**。若某个组合已被其他程序占用，
会在日志中记录「注册失败」（见[故障排查](#故障排查)）。`⌥⌘1`…`⌥⌘9` 对应预设文件的行序。

**URL scheme**：`vdscreen://<命令>`，命令为 `on`、`off`、`toggle`、`rotate`、`menu`、`preset/<名字>`、
`size/<宽x高>`、`zoom/<倍数|in|out|max|reset>`。仅在本机可用（脚本、SSH、Mac 上的快捷指令）；
iOS 的快捷指令无法打开 Mac 的自定义 scheme。任何网页都可以请求打开 `vdscreen://…`，浏览器会先确认；
不需要此功能可删去 `build.sh` 里 `Info.plist` 的 `CFBundleURLTypes`。

## 预设

预设保存在 `~/.config/vdscreen/presets`，纯文本，每行 `名字 = 宽x高`（逻辑尺寸）。首次运行自动生成；
增删修改后命令行与菜单栏立即生效（菜单栏可用「重新载入预设」）。

| 预设 | 逻辑尺寸 | 背板 |
| --- | --- | --- |
| iPad mini 7 | 1133×744 | 2266×1488 |
| iPad Air 11 / iPad 10-11 | 1180×820 | 2360×1640 |
| iPad Air 13 / iPad Pro 12.9 | 1366×1024 | 2732×2048 |
| iPad Pro 11 (M4) | 1210×834 | 2420×1668 |
| iPad Pro 13 (M4) | 1376×1032 | 2752×2064 |
| iPhone 18 Pro | 804×1748 | 1608×3496 |
| iPhone 18 Pro Max | 880×1912 | 1760×3824 |
| iPhone 17 / 18 (6.3") | 804×1748 | 1608×3496 |
| iPhone Air | 840×1824 | 1680×3648 |
| iPhone SE (3rd) | 750×1334 | 1500×2668 |
| 1080p / 1440p / 4K | 960×540 / 1280×720 / 1920×1080 | 2× |

iPad 预设为横屏，iPhone 预设为竖屏；用 `vdscreen rotate` 切换方向。

iPhone 预设使用的是手机的**像素尺寸**（如 804×1748），而不是点尺寸（402×874）。点尺寸的画布只有 402 点宽，
普通 Mac 窗口放不下，且过小的虚拟屏无法获得 HiDPI。基础款 iPhone 18 暂无公开的屏幕参数，沿用 iPhone 17 的 6.3" 面板。

## 界面缩放

`vdscreen zoom <倍数>` 将请求的尺寸除以倍数得到实际画布，界面因此显得更大：125% 时 804×1748 的画布变为 643×1398。

- 可用写法：`125`、`125%`、`1.25`、`in`、`out`、`max`、`reset`；范围 50%–200%
- `rotate` 保持当前缩放；切换预设或手动 `on` 会还原为 100%
- `zoom in` 先停在「清晰上限」，再按一次才进入略软区；`zoom max` 直接到清晰上限

画布缩小到一定程度后，macOS 不再提供 HiDPI 模式。程序据此估算每个尺寸的**清晰上限**（超过后退回 1:1，
画面略软，但界面比例仍然正确），并在切换后核对真实结果，如实标注「非 HiDPI」，不会拦截你。

| 请求尺寸 | 估算的清晰上限 |
| --- | --- |
| 804×1748（手机竖屏） | 120% |
| 1748×804（手机横屏） | 134% |
| 1133×744（iPad mini 横屏） | 124% |
| 744×1133（iPad mini 竖屏） | 111% |

HiDPI 的判定由系统内部决定，没有公开规则。在 macOS 27 上的观察结果：

| 提供 HiDPI | 不提供 HiDPI |
| --- | --- |
| 660×800 · 660×900 · 660×1000 · 700×1000 · 800×600 · 960×540 · 1000×660 · 1300×600 | 500×1100 · 600×800 · 640×960 · 650×1000 · 660×700 · 720×600 · 760×600 · 900×480 · 1000×480 |

估算公式（宽 ≥ 670、高 ≥ 600、面积 ≥ 48 万点）取了保守的余量，只用于菜单标注与 `zoom max`；
最终是否 HiDPI 以切换后的实际检测为准。缩小界面（< 100%）会使画布变大，观察到 67%–75% 仍为 HiDPI。

## 配置与文件位置

| 路径 | 说明 |
| --- | --- |
| `~/.config/vdscreen/config` | 默认值：`LABEL`、`CORE`、`NAME`、`SIZE`（shell 变量，可手工编辑） |
| `~/.config/vdscreen/presets` | 预设 |
| `~/Library/LaunchAgents/io.github.lyondan.vdscreen.plist` | 开启期间的 LaunchAgent（`LABEL` 可改，用于并存多块虚拟屏；1.1.0 及更早版本使用 `com.local.vdscreen.ipadmini7`，升级后沿用至下次 `vdscreen off`） |
| `/tmp/vdscreen.log`、`/tmp/vdscreen.err` | 核心的标准输出 / 错误 |
| `/tmp/vdscreen-bar.log` | 菜单栏应用的动作、CLI 回显、快捷键触发与注册失败 |

## 故障排查

```sh
vdscreen status                                     # 服务、进程、显示器
cat /tmp/vdscreen.log /tmp/vdscreen.err             # 核心输出
tail -30 /tmp/vdscreen-bar.log                      # 菜单栏应用日志
launchctl print gui/$(id -u)/io.github.lyondan.vdscreen
```

| 现象 | 处理 |
| --- | --- |
| 切换到某个尺寸后画面发软 | 该尺寸系统不提供 HiDPI，输出里会标注「非 HiDPI」；换更大的尺寸或降低缩放 |
| 提示「核心没有在预期时间内就绪」 | 查看 `/tmp/vdscreen.err`；同一身份的虚拟屏已在运行也会导致创建失败 |
| 某个快捷键无反应 | 在 `/tmp/vdscreen-bar.log` 中搜「注册失败」，说明组合被其他程序占用 |
| `brew install` 报 `Your Command Line Tools are too outdated` | 这是 Homebrew 对编译工具版本的检查，与本项目无关。在「系统设置 → 软件更新」里更新 Command Line Tools；没有更新时执行 `sudo rm -rf /Library/Developer/CommandLineTools && xcode-select --install`。或改用[预编译包](#预编译包) |
| 菜单栏看不到图标 | 见[菜单栏图标不可见时](#菜单栏图标不可见时) |
| 菜单栏应用图标在 Finder 中为空白 | 重新执行 `./build.sh`（会清理扩展属性并签名），再 `killall Dock Finder` |

## 卸载

```sh
vdscreen uninstall                              # 关闭虚拟屏并移除 ~/bin/vdscreen
rm -rf ~/Applications/VDScreenBar.app           # 菜单栏应用（如加入过登录项，也请移除）
rm -rf ~/.config/vdscreen                       # 配置与预设（可选）
brew uninstall vdscreen                         # 若通过 Homebrew 安装
```

## 工作原理

核心 `vdscreen-core`（Objective-C）通过 `CGVirtualDisplay` 创建虚拟显示器，进程存活期间显示器存在，
退出即移除；由 LaunchAgent 托管其生命周期。要让 macOS 提供 HiDPI 模式，需同时满足：

1. `maxPixelsWide/High` = 逻辑尺寸 × 2
2. `sizeInMillimeters` = 逻辑尺寸 × 0.254（按约 100 DPI 折算，**不是**真实物理尺寸）；
   按真实尺寸填写时，系统会把逻辑尺寸当作 1:1 的原生分辨率，HiDPI 模式不会出现
3. `modes` 同时声明逻辑模式与其 2× 模式
4. `hiDPI = 1`，且 vendor / product / serial 组合唯一

满足以上仍只是「申请」。创建后核心会读回实际模式：先尝试显式切换到 HiDPI 变体，系统确实没有时才重建为 1:1，
保证界面比例正确。

**显示器身份** = 名字 + 尺寸 + 是否 HiDPI（编码在 `serial` 中）。macOS 会按身份记住上次使用的模式；
若某个身份曾以非 HiDPI 使用，之后它的模式表里就不再提供 HiDPI 变体。让尺寸与 HiDPI 标志参与身份，
可避免不同尺寸互相污染。代价是更换尺寸会被系统视为新显示器，窗口不会自动迁移；同一尺寸反复切换则身份不变，窗口布局得以保留。

macOS 不接受高度小于 480 的显示器，此类尺寸（如手机横屏 874×402）会按宽高比放大到高 480；`rotate` 以最初
请求的尺寸为准，因此连续两次切换可原路返回。

## 已知限制

- **私有 API**：`CGVirtualDisplay` 不在 Apple SDK 的兼容性承诺内，系统更新可能使其失效，也无法上架 App Store。
  同类工具（BetterDisplay、vdisplay、DeskPad 等）建立在同一 API 上，风险相同。
- **平台**：仅在 macOS 27 / Apple Silicon 上测试；预编译包仅含 arm64。
- 同一时刻不能存在两块身份完全相同的虚拟屏。
- 只负责「建屏 + 定分辨率」，不含多配置档、窗口布局、DDC 亮度等。

## 开发

### 构建

```sh
./build.sh                                  # 核心 + 菜单栏应用
VERSION=1.2.0 ./build.sh                    # 指定写入 Info.plist 的版本号
SIGN_IDENTITY="Developer ID Application: …" ./build.sh    # 使用证书签名（默认 ad-hoc）
```

### 测试

```sh
tests/unit.sh                               # 单元测试，不碰显示器，数秒完成
tests/integration.sh --yes                  # 集成测试，会真的切换虚拟屏，约 3 分钟，结束后恢复原状态
```

- **单元测试**覆盖命令行的纯逻辑（尺寸归一化、缩放计算、清晰上限估算、参数解析、plist 读写、预设文件）和不碰显示器的命令；
  在隔离的 `HOME` 与不存在的 launchd 标签下运行，不会影响真实环境。CI 与提交前钩子都会运行它。
  启用提交钩子：`git config core.hooksPath .githooks`
- **集成测试**验证全部预设的尺寸与 HiDPI、横竖切换往返、低于高度下限的尺寸、界面缩放，
  可用于确认某个 macOS 版本上行为是否仍然成立。需要图形会话，因此不在 CI 中运行。
- 菜单栏应用（Swift）目前没有自动化测试。

### 发布

推送形如 `v1.2.0` 的 tag，GitHub Actions 会构建并创建 Release，附带 `VDScreenBar-<版本>-arm64.zip`、
`SHA256SUMS.txt`，以及已填好 url 与 sha256 的 Homebrew formula（`vdscreen.rb`）。

```sh
git tag v1.2.0 && git push origin v1.2.0
```

### 目录结构

```
vdscreen.m                  核心：创建虚拟显示器
CGVirtualDisplayShim.h      私有 API 的最小声明
vdscreen                    管理命令行（zsh）
vdscreen-bar.swift          菜单栏应用（菜单、全局快捷键、悬浮提示、URL scheme）
build.sh                    构建核心并打包 VDScreenBar.app
make-icon.swift             生成 AppIcon.icns（仅修改图标设计时需要运行）
AppIcon.icns                应用图标
tests/                      单元测试与集成测试
packaging/homebrew/         Homebrew formula 模板
.github/workflows/          CI 与发布流程
.githooks/                  提交前钩子
```

## 致谢

私有 API 的用法参考了下列开源项目，本项目在此基础上重新实现：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）

## 许可证

[MIT](LICENSE)
