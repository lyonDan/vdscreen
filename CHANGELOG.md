# Changelog

格式参考 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/)，版本号遵循 [SemVer](https://semver.org/lang/zh-CN/)。

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
