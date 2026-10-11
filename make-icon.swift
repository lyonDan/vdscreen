// make-icon.swift — 生成 VDScreenBar 的 App 图标（AppIcon.icns）
//
// 用法: swiftc -O make-icon.swift -o /tmp/make-icon && /tmp/make-icon AppIcon.icns
// 图标 = 深蓝渐变圆角底 + 一块虚线描边的显示器（虚线 = "虚拟"）+ 屏内一个实线的竖屏矩形（手机/平板）。
// 产物 AppIcon.icns 已提交进仓库，build.sh 直接拷贝；改了设计才需要重跑本脚本。

import AppKit

func drawIcon(size: CGFloat) -> NSBitmapImageRep {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let ctx = NSGraphicsContext.current!.cgContext
    let s = size / 1024          // 以 1024 画布为基准

    // 底板：macOS 图标网格（824 内边距 100，圆角约 185）
    let plate = NSRect(x: 100 * s, y: 100 * s, width: 824 * s, height: 824 * s)
    let platePath = NSBezierPath(roundedRect: plate, xRadius: 185 * s, yRadius: 185 * s)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12 * s), blur: 24 * s,
                  color: NSColor.black.withAlphaComponent(0.35).cgColor)
    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.40, alpha: 1).setFill()
    platePath.fill()
    ctx.restoreGState()
    platePath.addClip()
    NSGradient(colors: [NSColor(calibratedRed: 0.20, green: 0.52, blue: 0.98, alpha: 1),
                        NSColor(calibratedRed: 0.10, green: 0.14, blue: 0.42, alpha: 1)])!
        .draw(in: plate, angle: -70)

    // 显示器：虚线描边，表示"虚拟"
    let white = NSColor.white
    let monitor = NSRect(x: 232 * s, y: 380 * s, width: 560 * s, height: 380 * s)
    let monitorPath = NSBezierPath(roundedRect: monitor, xRadius: 48 * s, yRadius: 48 * s)
    white.withAlphaComponent(0.10).setFill()
    monitorPath.fill()
    monitorPath.lineWidth = 26 * s
    monitorPath.lineCapStyle = .round
    monitorPath.setLineDash([52 * s, 40 * s], count: 2, phase: 0)
    white.withAlphaComponent(0.92).setStroke()
    monitorPath.stroke()

    // 底座
    let neck = NSBezierPath(roundedRect: NSRect(x: 478 * s, y: 292 * s, width: 68 * s, height: 70 * s),
                            xRadius: 10 * s, yRadius: 10 * s)
    white.withAlphaComponent(0.92).setFill()
    neck.fill()
    let foot = NSBezierPath(roundedRect: NSRect(x: 370 * s, y: 258 * s, width: 284 * s, height: 44 * s),
                            xRadius: 22 * s, yRadius: 22 * s)
    foot.fill()

    // 屏内的竖屏设备（实线、实心）
    let device = NSRect(x: 452 * s, y: 432 * s, width: 120 * s, height: 256 * s)
    let devicePath = NSBezierPath(roundedRect: device, xRadius: 26 * s, yRadius: 26 * s)
    NSGradient(colors: [NSColor(calibratedRed: 0.55, green: 0.92, blue: 1.0, alpha: 1),
                        NSColor(calibratedRed: 0.25, green: 0.70, blue: 0.98, alpha: 1)])!
        .draw(in: devicePath, angle: -90)

    NSGraphicsContext.restoreGraphicsState()
    return rep
}

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("用法: make-icon <输出.icns>\n".utf8))
    exit(2)
}
let output = CommandLine.arguments[1]
let iconset = NSTemporaryDirectory() + "vdscreen-\(getpid()).iconset"
try FileManager.default.createDirectory(atPath: iconset, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(atPath: iconset) }

for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let rep = drawIcon(size: CGFloat(base * scale))
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: "\(iconset)/\(name)"))
    }
}
// 同时留一张 1024 预览，方便肉眼检查
try drawIcon(size: 1024).representation(using: .png, properties: [:])!
    .write(to: URL(fileURLWithPath: output.replacingOccurrences(of: ".icns", with: "-preview.png")))

let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", iconset, "-o", output]
try task.run()
task.waitUntilExit()
exit(task.terminationStatus)
