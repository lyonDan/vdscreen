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
./build.sh          # 编译出 ./vdscreen-core（需要 Xcode Command Line Tools）
./vdscreen install  # 装到 ~/bin/vdscreen，之后任意目录可用
vdscreen on         # 启动
```

## 管理与关闭

**本项目没有菜单栏图标，也没有 App 窗口**——只有命令行和后台的 LaunchAgent，
这是刻意的（保持零依赖、约 90 行）。所有操作走同一个命令：

| 命令 | 作用 |
| --- | --- |
| `vdscreen status` | 查看服务状态、进程、显示器与当前配置（默认动作） |
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
build.sh                一条 clang 命令完成编译
```

## 致谢

私有 API 的用法来自这些开源项目，本项目在其基础上重新实现：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）——最早的公开示例
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）——100 DPI 的关键配方
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）——HiDPI 镜像思路

## License

MIT，见 [LICENSE](LICENSE)。
