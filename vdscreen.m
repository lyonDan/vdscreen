// vdscreen - 用私有 CGVirtualDisplay API 创建一块虚拟显示器
//
// 用法: vdscreen <逻辑宽>x<逻辑高> [名字]
//   例: vdscreen 1133x744 "iPad mini 7"
//       得到背板 2266x1488、UI 看起来 1133x744（= iPad mini 7 原生像素）
//
// 进程存活期间显示器存在，退出（Ctrl-C / kill）即自动移除。
//
// ── 关于 HiDPI ──────────────────────────────────────────────────────────
// 申请 HiDPI 需要同时满足：
//   1. maxPixels = 逻辑尺寸 × 2
//   2. sizeInMillimeters = 逻辑尺寸 × 0.254（按 ~100 DPI 折算）
//   3. modes 同时声明逻辑模式和它的 2× 模式
//   4. hiDPI = 1，且 vendor/product/serial 唯一
//
// 但 macOS 只会为"足够大"的虚拟屏提供 HiDPI 模式（实测宽 ≳ 660、高 ≳ 600 才行；
// 窄屏如 402x874、600x800 拿不到）。此时若仍按 2× 申请，系统会退回 1:1，
// 结果是 UI 比例被放大一倍、字变得极小。因此这里会在创建后核对实际模式，
// 拿不到 HiDPI 就重建为 1:1 —— 比例正确、画面略软，而不是比例错误。

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CGVirtualDisplayShim.h"

/// 身份由"名字 + 尺寸 + 是否 HiDPI"共同决定（FNV-1a）。
/// 为什么不只用名字：macOS 会按身份记住上次的模式，若某名字曾被以 LoDPI 使用过，
/// 之后即使系统本来能给 HiDPI，它的模式表也会缺少 HiDPI 变体 —— 无法挽回。
/// 尺寸也参与身份后，每个尺寸都是独立身份，能拿 HiDPI 的尺寸不会被他人的偏好污染。
/// hiDPI 标志也参与：退化为 1:1 的重建用另一个身份，不会把"申请 HiDPI"的身份写成 LoDPI。
static uint32_t serialFor(NSString *name, int w, int h, BOOL hiDPI) {
    uint32_t h_ = 0x811C9DC5;
    NSString *seed = [NSString stringWithFormat:@"%@|%dx%d|%d", name, w, h, hiDPI ? 2 : 1];
    for (const uint8_t *p = (const uint8_t *)seed.UTF8String; *p; p++) {
        h_ = (h_ ^ *p) * 0x01000193;
    }
    return h_;
}

/// hiDPI=YES：申请 2× 背板；hiDPI=NO：1:1（背板 = 逻辑尺寸）
static CGVirtualDisplay *makeDisplay(NSString *name, int w, int h, BOOL hiDPI) {
    CGVirtualDisplayDescriptor *desc = [[CGVirtualDisplayDescriptor alloc] init];
    desc.queue = dispatch_get_main_queue();
    desc.name = name;
    desc.maxPixelsWide = (unsigned)(hiDPI ? w * 2 : w);
    desc.maxPixelsHigh = (unsigned)(hiDPI ? h * 2 : h);
    desc.sizeInMillimeters = CGSizeMake(w * 0.254, h * 0.254);
    desc.vendorID = 0x1AB2;
    desc.productID = 0x1234;
    desc.serialNum = serialFor(name, w, h, hiDPI);
    desc.terminationHandler = ^(id reason, id display) {
        fprintf(stderr, "虚拟屏被系统移除\n");
    };

    CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
    settings.hiDPI = hiDPI ? 1 : 0;
    CGVirtualDisplayMode *base =
        [[CGVirtualDisplayMode alloc] initWithWidth:(unsigned)w height:(unsigned)h refreshRate:60.0];
    if (hiDPI) {
        settings.modes = @[base,
                           [[CGVirtualDisplayMode alloc] initWithWidth:(unsigned)(w * 2)
                                                                height:(unsigned)(h * 2)
                                                           refreshRate:60.0]];
    } else {
        settings.modes = @[base];
    }

    CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:desc];
    return [display applySettings:settings] ? display : nil;
}

/// 读回系统实际选用的模式。CGDisplayModeGetPixelWidth 对虚拟屏是可信的，
/// 所以能同时确认"逻辑尺寸正确"与"确实是 2× 背板"。
static BOOL modeMatches(CGVirtualDisplay *display, int w, int h, BOOL requireHiDPI) {
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode((CGDirectDisplayID)[display displayID]);
    if (!mode) return NO;
    BOOL sizeOK = (int)CGDisplayModeGetWidth(mode) == w && (int)CGDisplayModeGetHeight(mode) == h;
    BOOL hidpiOK = !requireHiDPI || (int)CGDisplayModeGetPixelWidth(mode) == w * 2;
    CFRelease(mode);
    return sizeOK && hidpiOK;
}

/// 跑一会儿主 runloop，让系统把显示器初始化/定模式
static void pumpRunLoop(double seconds) {
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:seconds];
    while ([deadline timeIntervalSinceNow] > 0) {
        [[NSRunLoop currentRunLoop] runMode:NSDefaultRunLoopMode
                                 beforeDate:[NSDate dateWithTimeIntervalSinceNow:0.05]];
    }
}

static BOOL modeIsHiDPI(CGVirtualDisplay *display, int w, int h) {
    return modeMatches(display, w, h, YES);
}

/// macOS 会按"显示器身份"记住上次用过的模式：同一个名字若曾以 LoDPI 使用过，
/// 之后重建时可能仍被套用 LoDPI。这里显式切到 HiDPI 变体（若系统提供了）。
static BOOL selectHiDPIMode(CGVirtualDisplay *display, int w, int h) {
    CGDirectDisplayID did = (CGDirectDisplayID)[display displayID];
    CFArrayRef modes = CGDisplayCopyAllDisplayModes(did, NULL);
    if (!modes) return NO;

    BOOL done = NO;
    for (CFIndex i = 0; i < CFArrayGetCount(modes) && !done; i++) {
        CGDisplayModeRef m = (CGDisplayModeRef)CFArrayGetValueAtIndex(modes, i);
        if ((int)CGDisplayModeGetWidth(m) != w || (int)CGDisplayModeGetHeight(m) != h) continue;
        if ((int)CGDisplayModeGetPixelWidth(m) != w * 2) continue;

        CGDisplayConfigRef cfg = NULL;
        if (CGBeginDisplayConfiguration(&cfg) == kCGErrorSuccess) {
            CGConfigureDisplayWithDisplayMode(cfg, did, m, NULL);
            if (CGCompleteDisplayConfiguration(cfg, kCGConfigureForSession) == kCGErrorSuccess) {
                pumpRunLoop(0.8);
                done = modeIsHiDPI(display, w, h);
            }
        }
        if (!done) {                        // 换另一种 API 再试
            CGDisplaySetDisplayMode(did, m, NULL);
            pumpRunLoop(0.8);
            done = modeIsHiDPI(display, w, h);
        }
    }
    CFRelease(modes);
    return done;
}

int main(int argc, char *argv[]) {
    @autoreleasepool {
        if (argc < 2) {
            fprintf(stderr, "用法: %s <逻辑宽>x<逻辑高> [名字]\n例: %s 1133x744 \"iPad mini 7\"\n",
                    argv[0], argv[0]);
            return 2;
        }

        int lw = 0, lh = 0;
        if (sscanf(argv[1], "%dx%d", &lw, &lh) != 2 || lw <= 0 || lh <= 0) {
            fprintf(stderr, "尺寸格式错误: %s（应形如 1133x744）\n", argv[1]);
            return 2;
        }
        NSString *name = argc > 2 ? [NSString stringWithUTF8String:argv[2]] : @"Virtual Display";

        // 1) 申请 HiDPI
        // 2) 若系统给了 LoDPI（它可能按显示器身份复用了旧偏好），显式切到 HiDPI 变体
        // 3) 系统确实没有 HiDPI 变体时，才退化为 1:1（比例正确、画面略软）
        CGVirtualDisplay *display = makeDisplay(name, lw, lh, YES);
        BOOL gotHiDPI = NO;
        if (display) {
            pumpRunLoop(1.8);
            gotHiDPI = modeIsHiDPI(display, lw, lh);
            if (!gotHiDPI) {
                gotHiDPI = selectHiDPIMode(display, lw, lh);
            }
        }
        if (display && !gotHiDPI) {
            printf("系统没有提供 %dx%d 的 HiDPI 变体，退化为 1:1（比例正确、画面略软）\n", lw, lh);
            fflush(stdout);
            display = nil;
            pumpRunLoop(0.6);
            display = makeDisplay(name, lw, lh, NO);
            pumpRunLoop(1.8);
        }
        if (!display) {
            fprintf(stderr, "创建失败：可能是同身份的虚拟屏已在运行，或系统拒绝了该模式\n");
            return 1;
        }

        {
            // 1:1 的背板按构造就等于逻辑尺寸（刚重建时模式往往还读不到，会得到 0x0）；
            // HiDPI 才需要读回实际模式，且此前 modeIsHiDPI 已确认读得到。
            int pw = lw, ph = lh;
            if (gotHiDPI) {
                CGDisplayModeRef mode = CGDisplayCopyDisplayMode((CGDirectDisplayID)[display displayID]);
                if (mode) {
                    pw = (int)CGDisplayModeGetPixelWidth(mode);
                    ph = (int)CGDisplayModeGetPixelHeight(mode);
                    CFRelease(mode);
                }
            }
            printf("已就绪：\"%s\"  displayID=%u  UI %dx%d  背板 %dx%d  %s\n",
                   name.UTF8String, (unsigned)[display displayID], lw, lh, pw, ph,
                   gotHiDPI ? "HiDPI" : "非 HiDPI（1:1，画面略软）");
            fflush(stdout);
        }

        [[NSRunLoop mainRunLoop] run];   // 保持存活，直到被信号终止
    }
    return 0;
}
