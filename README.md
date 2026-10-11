# vdscreen

给 Mac 凭空加一块 HiDPI 虚拟显示器。约 180 行 Objective-C 核心 + 一个管理脚本 + 一个可选的菜单栏小应用，
零第三方依赖。

原始用途：让无显示器或远程访问的 Mac 拥有一块与 **iPad mini 7** 完全对齐的屏幕
——背板 2266×1488、逻辑 1133×744（正是 iPad mini 7 的原生像素与默认缩放）。

```
$ vdscreen on
已就绪："iPad mini 7"  displayID=67  UI 1133x744  背板 2266x1488  HiDPI
```

## 系统要求与风险

- macOS 13 或更高（在 macOS 27 上开发和测试）；编译需要 Xcode Command Line Tools（`xcode-select --install`）。
- 依赖 Apple **私有 API** `CGVirtualDisplay`：不受兼容性承诺保护，系统更新可能让它失效；
  也不能上架 App Store。请自行评估风险，按 MIT 协议「按原样」提供，不附带任何担保。
- 菜单栏 App 没有签名，请自己编译后使用（`build.sh` 产物在本机运行不会触发 Gatekeeper 拦截）。

## 快速开始

```sh
./build.sh                        # 编译核心 + 菜单栏 App（需要 Command Line Tools）
./vdscreen install                # CLI 装到 ~/bin/vdscreen，之后任意目录可用
cp -R VDScreenBar.app ~/Applications/ && open ~/Applications/VDScreenBar.app
vdscreen on                       # 或者直接从菜单栏点选
```

## 菜单栏应用

`VDScreenBar.app` 是一个纯菜单栏小应用（`LSUIElement`，不占 Dock、没有窗口），
它本身只做前端，实际动作全部交给 `vdscreen` CLI，所以 CLI 和它共享同一份状态与配置。

菜单内容：

- 顶部显示当前状态（如「已开启：iPad mini 7　1133x744（横屏）」）
- 「关闭虚拟屏」「横竖切换」「界面缩放」子菜单（75%…200%，会变软的档位标「略软」）
- 预设分辨率列表，当前生效的那条前面带 ✓，点一下即切换
- 「自定义分辨率…」弹窗输入任意尺寸，例如 `1280x800`（会按 2× 创建 2560x1600 背板）
- 「重新载入预设」「打开配置目录」
- 「在 Dock 显示图标」「登录时自动启动」两个开关

### 菜单栏被挤爆时怎么办（竖屏尤其常见）

竖屏时逻辑宽度很小，菜单栏放不下的状态项会被 macOS **直接隐藏**，vdscreen 的图标也可能
看不到。所以除了图标，还有这些入口，彼此独立：

| 入口 | 用法 |
| --- | --- |
| 全局快捷键 | `⌥⌘0` 开/关 · `⌥⌘R` 横竖切换 · `⌥⌘=` / `⌥⌘-` 放大 / 缩小界面 · `⌥⌘1…9` 切到第 1…9 条预设 · `⌃⌥⌘V` 在鼠标处弹出完整菜单 |
| 悬浮提示 | 用快捷键时屏幕下方会弹出结果（如「✓ iPad mini 7 · 1133x744 · 横屏 · HiDPI」） |
| URL scheme | `open vdscreen://rotate`，另有 `on` `off` `toggle` `menu` `preset/<名字>` `size/1280x800` `zoom/125`（或 `in` `out` `max` `reset`） |
| Dock 图标 | 菜单里勾选「在 Dock 显示图标」；点图标弹出菜单，右键同样有菜单 |
| 重新打开 App | 从 Spotlight / Launchpad 再打开一次，会在鼠标处弹出菜单 |
| 命令行 | `vdscreen rotate` / `vdscreen preset "iPad mini 7"`，远程时用 SSH |

快捷键用 Carbon `RegisterEventHotKey` 注册，**不需要辅助功能权限**；若某个组合被别的程序占用，
会记进 `/tmp/vdscreen-bar.log`（搜「注册失败」）。`⌥⌘1…9` 对应预设文件的行序，
菜单里每条预设后面也标着它的快捷键。

URL scheme 只在本机可用（脚本、Mac 上的快捷指令、SSH 里的 `open`）；iPad/iPhone 上的
快捷指令打不开 Mac 的自定义 scheme，远程客户端请用快捷键或 SSH。任何网页也能触发
`vdscreen://…`（浏览器会先弹确认），不想要可以去掉 Info.plist 里的 `CFBundleURLTypes`。

想让它开机就在菜单栏里：系统设置 → 通用 → 登录项，把 `VDScreenBar.app` 加进去即可。

App 包内自带一份 `vdscreen` CLI 与 `vdscreen-core`，因此它不依赖仓库路径、可以单独
拷贝到任何地方运行；反过来说，改完代码要刷新安装的副本：

```sh
./build.sh
cp -R VDScreenBar.app ~/Applications/     # 覆盖旧副本
```

## 预设分辨率

预设存放在 `~/.config/vdscreen/presets`，纯文本，每行 `名字 = 宽x高`（逻辑尺寸）。
首次运行会自动生成；**可自由增删改，CLI 和菜单栏立即生效，无需重新编译**。

**手机预设用的是手机的「像素尺寸」，不是「点尺寸」**（iPhone 18 Pro 是 804×1748，而不是
402×874）。原因有两个：普通 Mac 窗口往往要 800+ 点宽，402 点的画布放不下；而且太窄的虚拟屏
macOS 不给 HiDPI。像素尺寸既够宽、又能拿到真 HiDPI。代价是客户端缩放后字会偏小，
嫌小可以用下面的「界面缩放」临时放大（应急用，清晰放大约 1.2 倍，再大会变软）。
基础款 iPhone 18 的屏幕参数目前没有公开条目，沿用 iPhone 17 的 6.3" 面板。

| 设备 | 逻辑尺寸 | 背板 |
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
| 1080p / 1440p / 4K | 960×540 / 1280×720 / 1920×1080 | — |

iPad 用横屏尺寸、iPhone 用竖屏尺寸。想要另一个方向用 `vdscreen rotate`（或菜单栏「横竖切换」）。

**一个绕不开的限制**：macOS 只会为"足够大"的虚拟屏提供 HiDPI 模式（实测大致需要宽 ≥ ~660、
高 ≥ 600、面积 ≥ ~48 万点，细节见下面「界面缩放」）。拿不到时程序会
**自动退回 1:1**——UI 比例正确，只是画面略软，并如实告诉你「非 HiDPI」。另外 macOS 不接受
高度 < 480 的显示器，此类尺寸（如手机横屏 874×402）会保持宽高比等比放大到高 480；
`rotate` 以你**原本请求的尺寸**为准，所以连按两次能原路回来。

### 界面缩放

手机预设的画布是 804×1748，字偏小。`vdscreen zoom 120` 把画布按倍数缩小，UI 就显得大 1.2 倍
（请求尺寸 ÷ 倍数 = 逻辑画布）。可用 `125` / `125%` / `1.25` / `in` / `out` / `max` / `reset`，
范围 50%–200%；`rotate` 会保持当前缩放，换预设则还原为 100%。

**边界在哪**：画布缩小到一定程度 macOS 就不再给 HiDPI。实测（逻辑尺寸，✓ = HiDPI）：

| 有 | 没有 |
| --- | --- |
| 660×800 / 660×900 / 660×1000 · 800×600 · 1000×660 · 1300×600 | 650×1000 · 660×700 · 760×600 · 1000×480 |

大致条件是 **宽 ≥ ~660、高 ≥ 600、面积 ≥ ~48 万点**，与物理尺寸（DPI）无关。程序按
宽 ≥ 670、高 ≥ 600、面积 ≥ 48 万留了点余量，算出每个尺寸的「清晰上限」：

| 请求尺寸 | 清晰上限 |
| --- | --- |
| 804×1748（手机竖屏） | 120% |
| 1748×804（手机横屏） | 134% |
| 1133×744（iPad mini 横屏） | 124% |
| 744×1133（iPad mini 竖屏） | 111% |

在上限以内放大仍是真 HiDPI（背板 = 2× 画布）；越过后**不拦你**，而是退回 1:1 并如实标注
「非 HiDPI，画面略软」（UI 比例仍是对的）。`zoom in` 会先停在清晰上限那一档，再按一次才进入略软区；
`zoom max` 直接到清晰上限。缩小（<100%）画布变大、字变小，实测 67%–75% 仍是 HiDPI。
所以手机想要「又大又清晰」只有约 1.2 倍的空间；想再大，就得接受略软。

命令行同样能用预设：

```sh
vdscreen presets              # 列出全部预设
vdscreen preset "iPhone 18 Pro"
vdscreen on 1280x800 "随意名字"   # 直接给任意尺寸
```

## 管理与关闭

菜单栏 App 只是前端，所有动作最终都走同一个命令行：

| 命令 | 作用 |
| --- | --- |
| `vdscreen status` | 查看服务状态、进程、显示器与当前配置（默认动作） |
| `vdscreen state` | 机器可读状态（菜单栏用它刷新界面） |
| `vdscreen rotate` | 横竖切换 |
| `vdscreen zoom [倍数\|in\|out\|max\|reset]` | 界面缩放；不带参数显示当前值与清晰上限 |
| `vdscreen presets` / `preset <名字>` | 列出 / 按预设启动 |
| `vdscreen on` | 启动虚拟屏 |
| `vdscreen off` | **关闭**：停掉进程并卸下 LaunchAgent（不再开机自启） |
| `vdscreen restart` | 重启（改完配置后用它生效） |
| `vdscreen config` | 查看配置文件路径与内容 |
| `vdscreen set size 1133x744` | 改默认分辨率 |
| `vdscreen set name "iPad mini 7"` | 改默认名字 |
| `vdscreen uninstall` | 关闭并移除 `~/bin/vdscreen` |

临时用别的尺寸启动（不写入配置）：`vdscreen on 1024x768 "Test Screen"`

显示器与创建它的进程同生命周期。命令行不可用时，也可以直接操作底层：

```sh
# 只结束进程：显示器立刻消失，但服务在下次登录时还会自动拉起
pkill -f vdscreen-core

# 彻底停掉服务
launchctl bootout gui/$(id -u)/com.local.vdscreen.ipadmini7
```

## 配置

配置文件是纯 shell 片段，位于 `~/.config/vdscreen/config`：

```sh
CORE="/path/to/vdscreen-core"
NAME="iPad mini 7"
SIZE="1133x744"
```

`vdscreen set ...` 会改写它，也可以手工编辑后执行 `vdscreen restart`。
`SIZE` 是**逻辑尺寸**，程序会另外申请 2× 背板（1133×744 → 背板 2266×1488）。

## 卸载

```sh
vdscreen uninstall                            # 关闭虚拟屏，移除 ~/bin/vdscreen
rm -rf ~/Applications/VDScreenBar.app         # 菜单栏 App（如在「登录项」里加过，也请移除）
rm -rf ~/.config/vdscreen                     # 配置与预设（可选）
```

## 开机自启

`vdscreen on` 会写入 LaunchAgent
（`~/Library/LaunchAgents/com.local.vdscreen.ipadmini7.plist`）并交给 launchd 托管，
因此跨终端、跨登录都稳定，并随登录自动拉起。`off` 会卸下它，确保关闭后不会自动回来。

## 工作原理

核心用 Apple 的私有类 `CGVirtualDisplay`（CoreGraphics）创建虚拟显示器。要让 macOS
真的给出 HiDPI 模式，下面四条必须同时满足，缺一条只会得到模糊的 1:1 模式：

1. `maxPixels` = 逻辑尺寸 × 2
2. `sizeInMillimeters` = 逻辑尺寸 × 0.254（即按 ~100 DPI 折算，**不是**真实物理尺寸）
3. `modes` 里同时声明逻辑尺寸和它的 2× 尺寸
4. `hiDPI = 1`，且 `vendor/product/serial` 组合唯一，避免与其它虚拟屏身份冲突

第 2 条是最容易踩的坑：若按面板真实尺寸（例如 8.3"）填写，macOS 会把逻辑尺寸当成
1:1 原生分辨率，HiDPI 模式根本不会出现在模式列表里。

但四条都满足也仅是"申请"HiDPI：**macOS 还会额外要求虚拟屏足够大**（实测宽 ≥ ~660、高 ≥ 600、面积 ≥ ~48 万点）。
拿不到时系统会悄悄退回 1:1，此时若把 2× 背板当成逻辑尺寸用，UI 比例会整体放大一倍、
字小到没法看。所以程序在创建后会核对实际模式：先尝试显式切到 HiDPI 变体，系统确实没有
时才重建为 1:1，保证 UI 比例永远正确。

**显示器身份 = 名字 + 尺寸 + 是否 HiDPI**（体现在 `serial` 里）。macOS 会按身份记住上次用过的
模式，如果某个身份曾以 LoDPI 使用过，之后它的模式表里就**不再提供** HiDPI 变体，且无法挽回。
让尺寸参与身份后，每个尺寸互不污染；代价是换尺寸会被系统当成一块新显示器，窗口不会自动搬过去，
而同一尺寸反复切换时身份不变，布局可以保留。

## 已知限制

- **私有 API**：不在 Apple SDK 的兼容性承诺内，macOS 更新可能导致失效。同类工具
  （BetterDisplay、vdisplay、DeskPad 等）都建立在这个 API 上，风险相同。
- 进程存活期间显示器才存在（由 LaunchAgent 保证）。
- 同一时刻不能有两块身份完全相同的虚拟屏。
- 只管"建屏 + 定分辨率"，没有多配置档、布局管理、DDC 亮度等。

## 文件

```
vdscreen-core           编译产物（git 忽略）
vdscreen.m              核心：创建虚拟显示器
CGVirtualDisplayShim.h  私有 API 的最小声明
vdscreen                管理 CLI（on / off / rotate / preset / status / config / set / install / uninstall）
vdscreen-bar.swift      菜单栏应用源码（菜单、全局快捷键、悬浮提示、URL scheme）
build.sh                编译核心 + 打包 VDScreenBar.app
make-icon.swift         生成 AppIcon.icns 的脚本（仅改图标设计时才需要跑）
AppIcon.icns            菜单栏 App 的图标
```

## 致谢

私有 API 的用法来自这些开源项目，本项目在其基础上重新实现：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）——最早的公开示例
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）——100 DPI 的关键配方
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）——HiDPI 镜像思路

## License

MIT，见 [LICENSE](LICENSE)。
