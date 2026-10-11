# vdscreen

一块随叫随到的 HiDPI 虚拟显示器。约 90 行 Objective-C，零第三方依赖，不装任何 App。

原始用途：让 Mac 在无显示器或远程访问时，拥有一块与 **iPad mini 7** 完全对齐的屏幕
——背板 2266×1488、逻辑 1133×744（正是 iPad mini 7 的原生像素与默认缩放）。

```
$ ./ipad-vdisplay.sh on
已创建虚拟屏 "iPad mini 7"  displayID=67  背板 2266x1488  UI 1133x744 @60Hz
```

## 要求

- macOS（在 Apple Silicon M1 + macOS 27 上验证；旧版本未测）
- 命令行工具（Xcode Command Line Tools）提供的 `clang`

## 构建与使用

```sh
./build.sh                 # 编译出 ./vdscreen

./vdscreen 1133x744 "iPad mini 7"   # 前台运行；Ctrl-C 即移除显示器

./ipad-vdisplay.sh on      # 用 LaunchAgent 常驻启动
./ipad-vdisplay.sh off     # 关闭（并移除 LaunchAgent）
./ipad-vdisplay.sh status  # 查看状态
```

参数是**逻辑尺寸**，程序会另行申请 2× 背板（即上例实际得到 2266×1488 的背板）。

## 工作原理

用 Apple 的私有类 `CGVirtualDisplay`（CoreGraphics）创建一块虚拟显示器。要让 macOS
真的给出 HiDPI 模式，下面四条必须同时满足，缺一条只会得到模糊的 1:1 模式：

1. `maxPixels` = 逻辑尺寸 × 2
2. `sizeInMillimeters` = 逻辑尺寸 × 0.254（即按 ~100 DPI 折算，**不是**真实物理尺寸）
3. `modes` 里同时声明逻辑尺寸和它的 2× 尺寸
4. `hiDPI = 1`，且 `vendor/product/serial` 组合唯一，避免与其它虚拟屏身份冲突

第 2 条是最容易踩的坑：如果按面板真实尺寸（例如 8.3"）填写，macOS 会把逻辑尺寸当成
1:1 原生分辨率，HiDPI 模式根本不会出现在模式列表里。

显示器与创建它的进程同生命周期：进程退出，显示器即消失。因此 `ipad-vdisplay.sh`
用 LaunchAgent 托管，而不是 `nohup`——后者启动的子进程会随终端会话被回收。

## 已知限制

- **私有 API**：不在 Apple SDK 的兼容性承诺内，macOS 更新可能导致失效。所有同类工具
  （BetterDisplay、vdisplay、DeskPad 等）都建立在这个 API 上，风险相同。
- 进程存活期间显示器才存在（由 LaunchAgent 保证）。
- 同一时刻不能有两块身份完全相同的虚拟屏（同名会派生出相同 serial，故默认按名字区分）。
- 只管“建屏 + 定分辨率”，没有菜单栏、配置档、布局管理、DDC 亮度等。

## 致谢

私有 API 的用法来自这些开源项目，本项目在其基础上重新实现：

- [KhaosT/CGVirtualDisplay](https://github.com/KhaosT/CGVirtualDisplay)（Apache-2.0）——最早的公开示例
- [pacifistazero/vdisplay](https://github.com/pacifistazero/vdisplay)（MIT）——100 DPI 的关键配方
- [pasky/hidpi-mirror](https://github.com/pasky/hidpi-mirror)（MIT）——HiDPI 镜像思路

## License

MIT，见 [LICENSE](LICENSE)。
