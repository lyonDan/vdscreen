// vdscreen-bar — 菜单栏控制 vdscreen 虚拟显示器
//
// 用 AppKit 的 NSStatusItem 实现（而不是 SwiftUI 的 MenuBarExtra）：
// 状态栏图标一定会被创建，菜单在每次展开时重建，状态永远是最新的。
// 实际动作全部交给 vdscreen CLI 执行，这里只是前端。
//
// 排查用日志：/tmp/vdscreen-bar.log

import AppKit
import Foundation

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

// MARK: - 主逻辑

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var statusItem: NSStatusItem!
    private var presets: [Preset] = []
    private var isOn = false
    private var currentName = ""
    private var currentSize = ""

    func applicationDidFinishLaunching(_ notification: Notification) {
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

        log("launched, CLI=\(CLI.path)")
        log("statusItem visible=\(statusItem.isVisible) button=\(statusItem.button != nil)")

        reloadPresets()
        refreshState()
    }

    // MARK: 状态

    private func refreshState() {
        let output = CLI.run(["state"]).trimmingCharacters(in: .whitespacesAndNewlines)
        if output.hasPrefix("on ") {
            let parts = output.split(separator: " ")
            isOn = true
            currentSize = parts.last.map(String.init) ?? ""
            currentName = parts.dropFirst().dropLast().joined(separator: " ")
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

    // MARK: 菜单

    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshState()
        menu.removeAllItems()

        let header = NSMenuItem(
            title: isOn ? "已开启：\(currentName)　\(currentSize)" : "虚拟屏未开启",
            action: nil, keyEquivalent: "")
        header.isEnabled = false
        menu.addItem(header)

        if isOn {
            add(to: menu, title: "关闭虚拟屏", action: #selector(turnOff))
        }

        menu.addItem(.separator())

        let header2 = NSMenuItem(title: "预设分辨率", action: nil, keyEquivalent: "")
        header2.isEnabled = false
        menu.addItem(header2)

        for preset in presets {
            let item = add(to: menu, title: "\(preset.name)　\(preset.size)",
                           action: #selector(applyPreset(_:)))
            item.representedObject = preset
            item.state = (isOn && currentName == preset.name && currentSize == preset.size) ? .on : .off
        }

        menu.addItem(.separator())
        add(to: menu, title: "自定义分辨率…", action: #selector(promptCustom))
        add(to: menu, title: "重新载入预设", action: #selector(reloadPresetsAction))
        add(to: menu, title: "打开配置目录", action: #selector(openConfigFolder))

        menu.addItem(.separator())
        // terminate 要发给 NSApp，不能发给 self
        let quit = NSMenuItem(title: "退出 vdscreen-bar",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "")
        quit.target = NSApp
        menu.addItem(quit)
    }

    @discardableResult
    private func add(to menu: NSMenu, title: String, action: Selector) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
        return item
    }

    // MARK: 动作

    @objc private func turnOff() {
        log("动作: off")
        run(["off"])
    }

    @objc private func applyPreset(_ sender: NSMenuItem) {
        guard let preset = sender.representedObject as? Preset else { return }
        log("动作: on \(preset.size) \"\(preset.name)\"")
        run(["on", preset.size, preset.name])
    }

    @objc private func reloadPresetsAction() {
        reloadPresets()
    }

    @objc private func openConfigFolder() {
        let folder = NSHomeDirectory() + "/.config/vdscreen"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: folder))
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
        let size = field.stringValue
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let fields = size.split(separator: "x")
        guard fields.count == 2,
              let width = Int(fields[0]), let height = Int(fields[1]),
              width >= 320, height >= 240, width <= 8192, height <= 8192 else {
            log("自定义分辨率非法: \(field.stringValue)")
            return
        }
        log("动作: on \(width)x\(height) 自定义")
        run(["on", "\(width)x\(height)", "自定义 \(width)x\(height)"])
    }

    /// 跑 CLI 不阻塞菜单交互
    private func run(_ arguments: [String]) {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = CLI.run(arguments)
            DispatchQueue.main.async { self?.refreshState() }
        }
    }
}

// MARK: - 启动

let application = NSApplication.shared
let delegate = AppDelegate()
application.delegate = delegate
application.setActivationPolicy(.accessory)
application.run()
