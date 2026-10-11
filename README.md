# vdscreen

给 Mac 凭空加一块 HiDPI 虚拟显示器。约 90 行 Objective-C 核心 + 一个管理脚本，
零第三方依赖，不装任何 App。

原始用途：让无显示器或远程访问的 Mac 拥有一块与 **iPad mini 7** 完全对齐的屏幕
——背板 2266×1488、逻辑 1133×744（正是 iPad mini 7 的原生像素与默认缩放）。

```
$ vdscreen on
已创建虚拟屏 "iPad mini 7"  displayID=67  背板 2266x1488  UI 1133x744 @60Hz
```

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

- 顶部显示当前状态（如「已开启：iPad mini 7　1133x744」）
- 「关闭虚拟屏」一键关闭
- 预设分辨率列表，当前生效的那条前面带 ✓，点一下即切换
- 「自定义分辨率…」弹窗输入任意尺寸，例如 `1280x800`（会按 2× 创建 2560x1600 背板）
- 「重新载入预设」「打开配置目录」
- 菜单栏图标本身也会显示当前分辨率；关闭时显示为划掉的显示器图标

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

自带预设以 2026 年在售机型的真实逻辑分辨率为准（iPhone 18 系列数据取自 Wikipedia
对应机型的屏幕参数）：

| 设备 | 逻辑尺寸 | 背板 |
| --- | --- | --- |
| iPad mini 7 | 1133×744 | 2266×1488 |
| iPad Air 11 / iPad 10-11 | 1180×820 | 2360×1640 |
| iPad Air 13 / iPad Pro 12.9 | 1366×1024 | 2732×2048 |
| iPad Pro 11 (M4) | 1210×834 | 2420×1668 |
| iPad Pro 13 (M4) | 1376×1032 | 2752×2064 |
| iPhone 18 Pro | 402×874 | 1206×2622 |
| iPhone 18 Pro Max | 440×956 | 1320×2868 |
| iPhone 17 / 18 (6.3") | 402×874 | 1206×2622 |
| iPhone Air | 420×912 | 1260×2736 |
| iPhone SE (3rd) | 375×667 | 750×1334 |
| 1080p / 1440p / 4K | 960×540 / 1280×720 / 1920×1080 | — |

iPad 用横屏尺寸、iPhone 用竖屏尺寸。想要另一个方向就把宽高对调。
基础款 iPhone 18 的屏幕参数目前还没有公开条目，这里沿用 iPhone 17 的 6.3" 面板
（402×874pt）；拿到实际数据后直接改这一行即可。

命令行同样能用预设：

```sh
vdscreen presets              # 列出全部预设
vdscreen preset "iPhone 18 Pro"
vdscreen on 1280x800 "随意名字"   # 直接给任意尺寸
```

## 管理与关闭

**本项目没有菜单栏图标，也没有 App 窗口**——只有命令行和后台的 LaunchAgent，
这是刻意的（保持零依赖、约 90 行）。所有操作走同一个命令：

| 命令 | 作用 |
| --- | --- |
| `vdscreen status` | 查看服务状态、进程、显示器与当前配置（默认动作） |
| `vdscreen state` | 机器可读状态（菜单栏用它刷新界面） |
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

## 已知限制

- **私有 API**：不在 Apple SDK 的兼容性承诺内，macOS 更新可能导致失效。同类工具
  （BetterDisplay、vdisplay、DeskPad 等）都建立在这个 API 上，风险相同。
- 进程存活期间显示器才存在（由 LaunchAgent 保证）。
- 同一时刻不能有两块身份完全相同的虚拟屏（serial 由名字派生，故默认按名字区分）。
- 只管"建屏 + 定分辨率"，没有菜单栏、多配置档、布局管理、DDC 亮度等。
  想要菜单栏图形界面可以看 [vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）。

## 文件

```
vdscreen-core           编译产物（git 忽略）
vdscreen.m              核心：创建虚拟显示器
CGVirtualDisplayShim.h  私有 API 的最小声明
vdscreen                管理 CLI（on / off / status / config / set / install / uninstall）
vdscreen-bar.swift      菜单栏应用源码
build.sh                编译核心 + 打包 VDScreenBar.app
```

## 致谢

私有 API 的用法来自这些开源项目，本项目在其基础上重新实现：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）——最早的公开示例
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）——100 DPI 的关键配方
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）——HiDPI 镜像思路

## License

MIT，见 [LICENSE](LICENSE)。
