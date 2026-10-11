// vdscreen-bar — 菜单栏控制 vdscreen 虚拟显示器
//
// 只做一件事：把 vdscreen CLI 的能力放进菜单栏，一格点选即可开关 / 换分辨率。
// 所有实际工作仍由 vdscreen CLI 完成（含 LaunchAgent 托管），这里只是前端。

import SwiftUI
import AppKit
import Foundation

// MARK: - 调用 vdscreen CLI

enum CLI {
    /// 优先用 App 包内自带的 CLI，找不到再退回 ~/bin/vdscreen
    static let path: String = {
        if let res = Bundle.main.resourceURL?.appendingPathComponent("vdscreen").path,
           FileManager.default.isExecutableFile(atPath: res) {
            return res
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
            return ""
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return String(data: data, encoding: .utf8) ?? ""
    }
}

struct Preset: Identifiable, Hashable {
    let name: String
    let size: String
    var id: String { "\(name)|\(size)" }
}

// MARK: - 状态

final class Model: ObservableObject {
    @Published private(set) var isOn = false
    @Published private(set) var currentName = ""
    @Published private(set) var currentSize = ""
    @Published private(set) var presets: [Preset] = []
    @Published var busy = false

    private var timer: Timer?

    init() {
        reloadPresets()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.refresh()
        }
    }

    /// 向 CLI 询问当前状态： "on <名字> <宽x高>" 或 "off"
    func refresh() {
        let output = CLI.run(["state"]).trimmingCharacters(in: .whitespacesAndNewlines)
        guard output.hasPrefix("on ") else {
            isOn = false
            return
        }
        let parts = output.split(separator: " ")
        isOn = true
        currentSize = parts.last.map(String.init) ?? ""
        currentName = parts.dropFirst().dropLast().joined(separator: " ")
    }

    func reloadPresets() {
        let output = CLI.run(["presets"])
        presets = output.split(separator: "\n").compactMap { raw in
            let line = raw.trimmingCharacters(in: .whitespaces)
            guard !line.isEmpty, !line.hasPrefix("#"), let eq = line.firstIndex(of: "=") else { return nil }
            let name = String(line[..<eq]).trimmingCharacters(in: .whitespaces)
            let size = String(line[line.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            guard !name.isEmpty, size.contains("x") else { return nil }
            return Preset(name: name, size: size)
        }
    }

    func apply(preset: Preset) {
        background(["on", preset.size, preset.name])
    }

    func turnOff() {
        background(["off"])
    }

    /// 任意分辨率：接受 1280x800 / 1280×800 两种写法
    func applyCustom(size rawValue: String, name: String) {
        let size = rawValue
            .replacingOccurrences(of: "×", with: "x")
            .replacingOccurrences(of: " ", with: "")
            .lowercased()
        let fields = size.split(separator: "x")
        guard fields.count == 2,
              let width = Int(fields[0]), let height = Int(fields[1]),
              width >= 320, height >= 240, width <= 8192, height <= 8192 else { return }
        background(["on", "\(width)x\(height)", name.isEmpty ? "自定义 \(width)x\(height)" : name])
    }

    private func background(_ arguments: [String]) {
        busy = true
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            _ = CLI.run(arguments)
            DispatchQueue.main.async {
                self?.refresh()
                self?.busy = false
            }
        }
    }

    func openConfigFolder() {
        let folder = NSHomeDirectory() + "/.config/vdscreen"
        try? FileManager.default.createDirectory(atPath: folder, withIntermediateDirectories: true)
        NSWorkspace.shared.open(URL(fileURLWithPath: folder))
    }

    /// 弹窗输入任意分辨率
    func promptCustomResolution() {
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
        let entered = field.stringValue
        guard !entered.isEmpty else { return }
        applyCustom(size: entered, name: "")
    }

    func currentMatches(_ preset: Preset) -> Bool {
        isOn && currentName == preset.name && currentSize == preset.size
    }
}

// MARK: - 菜单内容

struct MenuContent: View {
    @ObservedObject var model: Model

    var body: some View {
        if model.isOn {
            Text("已开启：" + model.currentName + "　" + model.currentSize)
            Button("关闭虚拟屏") { model.turnOff() }
        } else {
            Text("虚拟屏未开启")
        }

        Divider()

        Text("预设分辨率")
        ForEach(model.presets) { preset in
            Button {
                model.apply(preset: preset)
            } label: {
                Text((model.currentMatches(preset) ? "✓ " : "    ") + preset.name + "　" + preset.size)
            }
        }

        Divider()

        Button("自定义分辨率…") { model.promptCustomResolution() }

        Divider()

        Button("重新载入预设") { model.reloadPresets() }
        Button("打开配置目录") { model.openConfigFolder() }

        Divider()

        Button("退出 vdscreen-bar") { NSApp.terminate(nil) }
    }
}

// MARK: - 入口

@main
struct VDScreenBarApp: App {
    @StateObject private var model = Model()

    var body: some Scene {
        MenuBarExtra {
            MenuContent(model: model)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: model.isOn ? "display" : "display.slash")
                if model.isOn, !model.currentSize.isEmpty {
                    Text(model.currentSize)
                }
            }
        }
        .menuBarExtraStyle(.menu)
    }
}
