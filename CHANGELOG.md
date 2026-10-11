# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

## [1.2.8]

### 新增
- **方向锁定**：`vdscreen orientation 横屏|竖屏|auto` 与菜单「方向」子菜单（勾选项，持久保存）。
  锁定后换预设、换分辨率都保持所选方向；对正在运行的虚拟屏设置时立即重摆。`rotate` 仍为一次性切换
- URL scheme 新增 `vdscreen://orientation/<landscape|portrait|auto>`

### 变更
- 菜单栏「自定义分辨率」改为**宽、高两个数字输入框**，不用再输入乘号；
  预填当前逻辑尺寸，范围超限会提示有效区间
- 预设调整：移除 iPhone Air、iPhone SE (3rd)；通用分辨率改为 1600×900、1280×720、1920×1080
  （已是用户机器上的旧 presets 文件不受影响，新装生效）

## [1.2.7]

### 修复
- 菜单栏界面缩放恒显 100%：`zoominfo` 输出带换行导致第二个数解析失败（缩放本身一直生效，
  坏的是显示层：标题、勾选、「略软」标注）

## [1.2.6]

### 新增
- **一键切换主屏**：`vdscreen main`、菜单项、全局快捷键 `⌥⌘M`、`vdscreen://main`。
  把虚拟屏设为主屏（菜单栏 / Dock 跟随，分辨率不变），远程时即可看到并操作其他屏上已打开的窗口；
  再触发一次切回第一个其他在线显示器

## [1.2.5]

### 变更
- **Homebrew formula 改为直接安装 Release 预编译包**（签名公证过的 zip），不再本机编译，
  安装不再需要 Xcode / Command Line Tools，也不会再遇到「Command Line Tools are too outdated」
- formula 仅支持 arm64（与预编译包一致；Intel Mac 请从源码构建）

## [1.2.4]

### 修复
- 显示器名字含正则元字符（如 `.` `*`）时 `status` / DPI 核对可能匹配失败：改用字面匹配
- `vdscreen uninstall` 漏删 `~/bin/vdscreen-core`（预编译包安装方式会装这个文件）

## [1.2.3]

### 新增
- 一键安装脚本：`curl -fsSL …/install.sh | zsh`，从最新 Release 安装 App 与命令行，公证校验不通过则中止
- Release 附件新增 DMG（打开后拖入 Applications）

## [1.2.2]

### 变更
- Release 预编译包改为 **Developer ID 签名 + Apple 公证**：解压后可直接打开，无需手动放行。
  未配置签名 Secrets 的 fork 仍为 ad-hoc 签名。从源码构建（含 Homebrew）不受影响

## [1.2.1]

### 修复
- 悬浮提示在浅色外观下白底白字看不清：改用与系统外观无关的深色背景

## [1.2.0]

### 变更
- LaunchAgent 默认标签由 `com.local.vdscreen.ipadmini7` 改为 `io.github.lyondan.vdscreen`，
  App 的 Bundle ID 改为 `io.github.lyondan.vdscreen.bar`（原标签与特定机型绑定，且 `com.local` 是占位前缀）。
  已在运行的旧标签服务会被沿用，直到下一次 `vdscreen off`，无需手动迁移。

## [1.1.0]

### 新增
- 横竖屏切换（`vdscreen rotate`），以最初请求的尺寸为准，可原路返回
- 界面缩放（`vdscreen zoom`）：50%–200%，越过清晰上限时如实标注「非 HiDPI」
- 菜单栏应用：全局快捷键、悬浮提示、URL scheme、可选 Dock 图标、登录时自动启动、界面缩放子菜单
- 菜单栏应用图标
- 单元测试与集成测试，CI 与提交前钩子
- Release 自动发布与 Homebrew formula

### 修复
- 手机尺寸 HiDPI 时有时无：显示器身份改为「名字 + 尺寸 + 是否 HiDPI」
- 已开启状态下更换尺寸不生效（`kickstart` 不会重读 plist）
- 小尺寸拿不到 HiDPI 时界面比例放大一倍：检测后重建为 1:1
- 高度低于 480 的尺寸被系统替换为默认模式：按宽高比放大到高 480
- 核心谎报「HiDPI 已生效」：改为核对实际背板尺寸
- `vdscreen on` 用固定时长等待核心就绪：改为轮询
- 显示器名字含 `& < >` 时 LaunchAgent 的 plist 非法：已转义
- 未开启时执行 `rotate` 会意外开启虚拟屏：现在报错
- `vdscreen set` 会丢失自定义的 `LABEL`
