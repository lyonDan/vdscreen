// vdscreen-bar — 菜单栏控制 vdscreen 虚拟显示器
//
// 用 AppKit 的 NSStatusItem 实现（而不是 SwiftUI 的 MenuBarExtra）：
// 状态栏图标一定会被创建，菜单在每次展开时重建，状态永远是最新的。
// 实际动作全部交给 vdscreen CLI 执行，这里只是前端。
//
// 入口不止菜单栏图标 —— 竖屏时菜单栏会被挤爆，图标可能不可见，所以另有：
//   · 全局快捷键（⌥⌘0 开关 / ⌥⌘R 横竖切换 / ⌥⌘1…9 选预设 / ⌥⌘= ⌥⌘- 界面缩放 / ⌃⌥⌘V 弹出菜单）
//   · URL scheme（vdscreen://rotate 等，见 handle(url:)）
//   · 可选的 Dock 图标（右键直接出菜单）
//   · 再次打开 App（Spotlight / Launchpad）时在鼠标处弹出菜单
//
// 排查用日志：/tmp/vdscreen-bar.log

import AppKit
import Carbon.HIToolbox
import ServiceManagement

private let logPath = "/tmp/vdscreen-bar.log"

private func log(_ message: String) {
    let line = "\(Date()) \(message)\n"
    if let handle = FileHandle(forWritingAtPath: logPath) {
        handle.seekToEndOfFile()
        handle.write(Data(line.utf8))
        try? handle.close()
    } else {
        try? line.write(toFile: logPath, atomically: true, encoding: .utf8)
    }
}

// MARK: - 调用 vdscreen CLI

enum CLI {
    /// 优先用 App 包内自带的 CLI，找不到再退回 ~/bin/vdscreen
    static let path: String = {
        if let resource = Bundle.main.resourceURL?.appendingPathComponent("vdscreen").path,
           FileManager.default.isExecutableFile(atPath: resource) {
            return resource
        }
        return NSHomeDirectory() + "/bin/vdscreen"
    }()

    @discardableResult
    static func run(_ arguments: [String]) -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        do {
            try process.run()
        } catch {
            log("CLI 启动失败: \(error.localizedDescription) path=\(path)")
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct Preset: Hashable {
    let name: String
    let size: String
}

/// 由 "宽x高" 推断朝向，用于菜单里显示
func orientationLabel(_ size: String) -> String {
    let parts = size.split(separator: "x")
    guard parts.count == 2, let w = Int(parts[0]), let h = Int(parts[1]) else { return "" }
    if w > h { return "横屏" }
    if h > w { return "竖屏" }
    return "方形"
}

// MARK: - 全局快捷键（Carbon，不需要辅助功能权限）

final class HotKeys {
    private var handlers: [UInt32: () -> Void] = [:]
    private var refs: [EventHotKeyRef] = []
    private var nextID: UInt32 = 1

    init() {
        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                 eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, userData in
            guard let event, let userData else { return OSStatus(eventNotHandledErr) }
            var id = EventHotKeyID()
            GetEventParameter(event, EventParamName(kEventParamDirectObject),
                              EventParamType(typeEventHotKeyID), nil,
                              MemoryLayout<EventHotKeyID>.size, nil, &id)
            let me = Unmanaged<HotKeys>.fromOpaque(userData).takeUnretainedValue()
            log("快捷键触发 id=\(id.id)")
            me.handlers[id.id]?()
            return noErr
        }, 1, &spec, Unmanaged.passUnretained(self).toOpaque(), nil)
    }

    func register(keyCode: Int, modifiers: Int, label: String, handler: @escaping () -> Void) {
        let id = nextID
        nextID += 1
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(UInt32(keyCode), UInt32(modifiers),
                                         EventHotKeyID(signature: OSType(0x56444253), id: id),
                                         GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref {
            refs.append(ref)
            handlers[id] = handler
        } else {
            log("快捷键 \(label) 注册失败（status=\(status)，多半被别的程序占用）")
        }
    }
}

// MARK: - 悬浮提示（HUD）
// 用快捷键操作时看不到菜单，需要一个不依赖菜单栏的反馈。

final class HUD {
    private var panel: NSPanel?
    private let label = NSTextField(labelWithString: "")
    private var hideWork: DispatchWorkItem?

    func show(_ text: String, duration: TimeInterval = 2.5) {
        let panel = self.panel ?? makePanel()
        self.panel = panel

        label.stringValue = text
        label.sizeToFit()
        let size = NSSize(width: max(label.frame.width + 44, 160), height: label.frame.height + 28)
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens[0]
        let area = screen.visibleFrame
        panel.setFrame(NSRect(x: area.midX - size.width / 2, y: area.minY + area.height * 0.18,
                              width: size.width, height: size.height), display: true)
        label.frame = NSRect(x: 22, y: 14, width: size.width - 44, height: label.frame.height)

        hideWork?.cancel()
        panel.alphaValue = 1
        panel.orderFrontRegardless()
        let work = DispatchWorkItem { [weak panel] in
            NSAnimationContext.runAnimationGroup({ $0.duration = 0.3; panel?.animator().alphaValue = 0 },
                                                 completionHandler: { panel?.orderOut(nil) })
        }
        hideWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered, defer: false)
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.level = .statusBar
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        let blur = NSVisualEffectView()
        blur.material = .hudWindow
        blur.state = .active
        blur.wantsLayer = true
        blur.layer?.cornerRadius = 14
        blur.layer?.masksToBounds = true

        label.font = .systemFont(ofSize: 16, weight: .medium)
        label.textColor = .white
        label.alignment = .center
        label.maximumNumberOfLines = 3
        blur.addSubview(label)
        panel.contentView = blur
        return panel
    }
}

// MARK: - 主逻辑

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private let hotKeys = HotKeys()
    private let hud = HUD()
    private var presets: [Preset] = []
    private var isOn = false
    private var busy = false
    private var currentName = ""
    private var currentSize = ""
    private var zoom = 1.0          // 当前界面缩放（1.25 = 125%）
    private var sharpMax = 1.0      // 超过它 macOS 不再给 HiDPI，画面会略软
    private static let zoomLevels: [Double] = [0.5, 0.67, 0.75, 0.9, 1.0, 1.1, 1.25, 1.5, 1.75, 2.0]

    private static let showDockKey = "showDockIcon"
    private var showDock: Bool {
        get { UserDefaults.standard.bool(forKey: Self.showDockKey) }
        set { UserDefaults.standard.set(newValue, forKey: Self.showDockKey) }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            // "display" 是确认存在的 SF Symbol；不存在时退回纯文字，保证一定看得见
            if let image = NSImage(systemSymbolName: "display", accessibilityDescription: "vdscreen") {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
                log("状态栏图标已创建（SF Symbol: display）")
            } else {
                button.title = "VDS"
                log("SF Symbol 不可用，退回文字标题")
            }
            button.toolTip = "vdscreen 虚拟显示器"
        }

        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu

        log("launched, CLI=\(CLI.path) dock=\(showDock)")
        log("statusItem visible=\(statusItem.isVisible) button=\(statusItem.button != nil)")

        reloadPresets()
        refreshState()
        registerHotKeys()
        log("快捷键已注册")
    }

    // MARK: 状态

    private func refreshState() {
        let output = CLI.run(["state"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("on ") {
            let parts = output.split(separator: " ")
            isOn = true
            currentSize = parts.last.map(String.init) ?? ""
            currentName = parts.dropFirst().dropLast().joined(separator: " ")
            let zoomInfo = CLI.run(["zoominfo"]).split(separator: " ").compactMap { Double($0) }
            if zoomInfo.count == 2 { zoom = zoomInfo[0]; sharpMax = zoomInfo[1] }
        } else {
            isOn = false
        }
        statusItem?.button?.toolTip = isOn
            ? "vdscreen：\(currentName) \(currentSize)"
            : "vdscreen：未开启"
    }

    private func reloadPresets() {
        let output = CLI.run(["presets"])
        presets = output.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { return nil }
            let name = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let size = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, size.contains("x") else { return nil }
            return Preset(name: name, size: size)
        }
        log("载入 \(presets.count) 条预设")
    }

    // MARK: 入口：快捷键 / URL / Dock / 重新打开

    private func registerHotKeys() {
        let mods = optionKey | cmdKey
        hotKeys.register(keyCode: kVK_ANSI_0, modifiers: mods, label: "⌥⌘0") { [weak self] in self?.toggle() }
        hotKeys.register(keyCode: kVK_ANSI_R, modifiers: mods, label: "⌥⌘R") { [weak self] in self?.rotate() }
        hotKeys.register(keyCode: kVK_ANSI_Equal, modifiers: mods, label: "⌥⌘=") { [weak self] in self?.zoomStep("in") }
        hotKeys.register(keyCode: kVK_ANSI_Minus, modifiers: mods, label: "⌥⌘-") { [weak self] in self?.zoomStep("out") }
        hotKeys.register(keyCode: kVK_ANSI_V, modifiers: mods | controlKey, label: "⌃⌥⌘V") { [weak self] in
            self?.popUpMenuAtMouse()
        }
        let digits = [kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
                      kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9]
        for (index, code) in digits.enumerated() {
            hotKeys.register(keyCode: code, modifiers: mods, label: "⌥⌘\(index + 1)") { [weak self] in
                guard let self, index < self.presets.count else { return }
                self.apply(self.presets[index])
            }
        }
    }

    /// vdscreen://on | off | toggle | rotate | preset/<名字> | size/<宽x高>
    func application(_ application: NSApplication, open urls: [URL]) {
        urls.forEach(handle(url:))
    }

    private func handle(url: URL) {
        guard url.scheme == "vdscreen", let command = url.host else { return }
        let argument = url.pathComponents.dropFirst().joined(separator: "/")
        log("URL: \(url.absoluteString)")
        switch command {
        case "on":      turnOn()
        case "off":     turnOff()
        case "toggle":  toggle()
        case "rotate":  rotate()
        case "menu":    popUpMenuAtMouse()
        case "zoom":
            // in | out | max | reset | 125 | 125% | 1.25（没有 shell，参数不会被注入；这里仍只放行合法形式）
            if argument.range(of: #"^(in|out|max|reset|[0-9]+(\.[0-9]+)?%?)$"#, options: .regularExpression) != nil {
                zoomTo(argument)
            } else {
                hud.show("缩放参数不对：\(argument)")
            }
        case "preset":
            if let preset = presets.first(where: { $0.name == argument }) {
                apply(preset)
            } else {
                hud.show("找不到预设「\(argument)」")
            }
        case "size":
            if let size = Self.parseSize(argument) { applyCustom(size) }
            else { hud.show("尺寸格式错误：\(argument)") }
        default:
            hud.show("未知命令：\(command)")
        }
    }

    /// 点 Dock 图标 / 在 Spotlight 里再次打开：在鼠标处弹出菜单，菜单栏挤爆时的兜底
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        DispatchQueue.main.async { self.popUpMenuAtMouse() }
        return false
    }

    /// Dock 图标右键菜单
    func applicationDockMenu(_ sender: NSApplication) -> NSMenu? {
        refreshState()
        let menu = NSMenu()
        fill(menu)
        return menu
    }

    private func popUpMenuAtMouse() {
        refreshState()
        let menu = NSMenu()
        fill(menu)
        NSApp.activate(ignoringOtherApps: true)
        menu.popUp(positioning: nil, at: NSEvent.mouseLocation, in: nil)
    }

    // MARK: 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshState()
        fill(menu)
    }

    private func fill(_ menu: NSMenu) {
        menu.removeAllItems()

        let header = NSMenuItem(
            title: isOn
                ? "已开启：\(currentName)　\(currentSize)（\(orientationLabel(currentSize))）"
                : "虚拟屏未开启",
            action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if isOn {
            add(to: menu, title: "关闭虚拟屏", action: #selector(turnOffAction), key: "0")
            add(to: menu, title: "横竖切换", action: #selector(rotateAction), key: "r")

            let zoomItem = NSMenuItem(title: "界面缩放（\(Self.percent(zoom))）", action: nil, keyEquivalent: "")
            let zoomMenu = NSMenu()
            for level in Self.zoomLevels {
                let soft = level > sharpMax + 0.005
                let item = add(to: zoomMenu, title: Self.percent(level) + (soft ? "　略软" : ""),
                               action: #selector(applyZoomLevel(_:)))
                item.representedObject = level
                item.state = abs(level - zoom) < 0.005 ? .on : .off
            }
            zoomMenu.addItem(.separator())
            add(to: zoomMenu, title: "最大清晰缩放（\(Self.percent(sharpMax))）", action: #selector(zoomMaxAction))
            add(to: zoomMenu, title: "放大", action: #selector(zoomInAction), key: "=")
            add(to: zoomMenu, title: "缩小", action: #selector(zoomOutAction), key: "-")
            zoomItem.submenu = zoomMenu
            menu.addItem(zoomItem)
        } else {
            add(to: menu, title: "开启虚拟屏（默认配置）", action: #selector(turnOnAction), key: "0")
        }

        menu.addItem(.separator())

        let header2 = NSMenuItem(title: "预设分辨率", action: nil, keyEquivalent: "")
        header2.isEnabled = false
        menu.addItem(header2)

        for (index, preset) in presets.enumerated() {
            let item = add(to: menu, title: "\(preset.name)　\(preset.size)",
                           action: #selector(applyPreset(_:)), key: index < 9 ? "\(index + 1)" : "")
            item.representedObject = preset
            item.state = (isOn && currentName == preset.name && currentSize == preset.size) ? .on : .off
        }

        menu.addItem(.separator())
        add(to: menu, title: "自定义分辨率…", action: #selector(promptCustom))
        add(to: menu, title: "重新载入预设", action: #selector(reloadPresetsAction))
        add(to: menu, title: "打开配置目录", action: #selector(openConfigFolder))

        menu.addItem(.separator())
        let dock = add(to: menu, title: "在 Dock 显示图标（菜单栏被挤掉时的备用入口）", action: #selector(toggleDock))
        dock.state = showDock ? .on : .off
        let login = add(to: menu, title: "登录时自动启动", action: #selector(toggleLoginItem))
        login.state = SMAppService.mainApp.status == .enabled ? .on : .off

        menu.addItem(.separator())
        // terminate 要发给 NSApp，不能发给 self
        let quit = NSMenuItem(title: "退出 vdscreen-bar",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
    }

    /// key 非空时只是在菜单里显示全局快捷键 ⌥⌘key（真正的监听在 registerHotKeys）
    @discardableResult
    private func add(to menu: NSMenu, title: String, action: Selector, key: String = "") -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        if !key.isEmpty { item.keyEquivalentModifierMask = [.option, .command] }
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: 动作

    @objc private func turnOffAction() { turnOff() }
    @objc private func turnOnAction() { turnOn() }
    @objc private func rotateAction() { rotate() }

    private func turnOn() {
        perform(["on"], title: "正在开启虚拟屏…")
    }

    private func turnOff() {
        perform(["off"], title: "正在关闭虚拟屏…")
    }

    private func toggle() {
        refreshState()
        isOn ? turnOff() : turnOn()
    }

    private func rotate() {
        refreshState()
        guard isOn else { hud.show("虚拟屏未开启"); return }
        perform(["rotate"], title: "正在横竖切换…")
    }

    static func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }

    private func zoomTo(_ argument: String) {
        refreshState()
        guard isOn else { hud.show("虚拟屏未开启"); return }
        perform(["zoom", argument], title: "正在调整界面缩放…")
    }

    private func zoomStep(_ direction: String) { zoomTo(direction) }

    @objc private func zoomInAction() { zoomStep("in") }
    @objc private func zoomOutAction() { zoomStep("out") }
    @objc private func zoomMaxAction() { zoomTo("max") }

    @objc private func applyZoomLevel(_ sender: NSMenuItem) {
        guard let level = sender.representedObject as? Double else { return }
        zoomTo(String(level))
    }

    private func apply(_ preset: Preset) {
        perform(["on", preset.size, preset.name], title: "正在切换到 \(preset.name)…")
    }

    private func applyCustom(_ size: String) {
        perform(["on", size, "自定义 \(size)"], title: "正在切换到 \(size)…")
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? Preset else { return }
        apply(preset)
    }

    @objc private func reloadPresetsAction() {
        reloadPresets()
    }

    @objc private func openConfigFolder() {
        let folder = NSHomeDirectory() + "/.config/vdscreen"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: folder))
    }

    @objc private func toggleDock() {
        showDock.toggle()
        NSApp.setActivationPolicy(showDock ? .regular : .accessory)
        log("Dock 图标: \(showDock)")
    }

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            log("登录自启: \(SMAppService.mainApp.status == .enabled)")
        } catch {
            log("登录自启切换失败: \(error.localizedDescription)")
            hud.show("登录自启设置失败：\(error.localizedDescription)", duration: 4)
        }
    }

    static func parseSize(_ raw: String) -> String? {
        let size = raw
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let fields = size.split(separator: "x")
        guard fields.count == 2,
              let width = Int(fields[0]), let height = Int(fields[1]),
              width >= 320, height >= 240, width <= 8192, height <= 8192 else { return nil }
        return "\(width)x\(height)"
    }

    @objc private func promptCustom() {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "自定义分辨率"
        alert.informativeText = "输入逻辑尺寸，例如 1280x800。程序会按 2× 创建背板（即 2560x1600）。"
        alert.addButton(withTitle: "应用")
        alert.addButton(withTitle: "取消")

        let field = NSTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        field.placeholderString = "1280x800"
        alert.accessoryView = field
        alert.window.initialFirstResponder = field

        guard alert.runModal() == .alertFirstButtonReturn else { return }
        guard let size = Self.parseSize(field.stringValue) else {
            log("自定义分辨率非法: \(field.stringValue)")
            hud.show("分辨率格式不对：\(field.stringValue)")
            return
        }
        applyCustom(size)
    }

    /// 跑 CLI 不阻塞界面；同一时刻只允许一个动作，避免快捷键连按时 on/off 互相打架。
    private func perform(_ arguments: [String], title: String) {
        guard !busy else {
            hud.show("上一个操作还在进行，请稍候")
            return
        }
        busy = true
        log("动作: \(arguments.joined(separator: " "))")
        hud.show(title, duration: 30)
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            // 把 CLI 的回显也记进日志，失败时才能远程定位
            let output = CLI.run(arguments).trimmingCharacters(in: .whitespacesAndNewlines)
            log("CLI 返回: \(output.replacingOccurrences(of: "\n", with: " | "))")
            DispatchQueue.main.async {
                guard let self else { return }
                self.busy = false
                self.refreshState()
                self.hud.show(self.summary(of: output, command: arguments.first ?? ""))
            }
        }
    }

    /// 根据 CLI 回显生成结果提示（"HiDPI"/"非 HiDPI" 来自 CLI 对 system_profiler 的核对）
    private func summary(of output: String, command: String) -> String {
        if command == "off" { return "虚拟屏已关闭" }
        guard isOn else { return "✗ 虚拟屏没有起来，详见 /tmp/vdscreen-bar.log" }
        let quality = output.contains("非 HiDPI") ? "非 HiDPI（画面略软）"
            : output.contains("HiDPI") ? "HiDPI" : ""
        let zoomText = abs(zoom - 1) > 0.005 ? "缩放 \(Self.percent(zoom))" : ""
        let detail = [currentSize, orientationLabel(currentSize), zoomText, quality].filter { !$0.isEmpty }
        return "✓ \(currentName)\n" + detail.joined(separator: " · ")
    }
}

// MARK: - 启动

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.run()
