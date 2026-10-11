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
// 但 macOS 只会为"足够大"的虚拟屏提供 HiDPI 模式（实测逻辑宽度 ≳ 900 才行；
// 手机尺寸如 402x874 拿不到）。此时若仍按 2× 申请，系统会退回 1:1，
// 结果是 UI 比例被放大一倍、字变得极小。因此这里会在创建后核对实际模式，
// 拿不到 HiDPI 就重建为 1:1 —— 比例正确、画面略软，而不是比例错误。

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CGVirtualDisplayShim.h"

static uint32_t serialForName(NSString *name) {
    uint32_t h = 0x811C9DC5;                       // FNV-1a：同名固定身份，便于系统记住布局
    for (const uint8_t *p = (const uint8_t *)name.UTF8String; *p; p++) {
        h = (h ^ *p) * 0x01000193;
    }
    return h;
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
    desc.serialNum = serialForName(name);
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

/// 读回系统实际选用的模式
static BOOL currentUISizeMatches(CGVirtualDisplay *display, int w, int h) {
    CGDisplayModeRef mode = CGDisplayCopyDisplayMode((CGDirectDisplayID)[display displayID]);
    if (!mode) return NO;
    BOOL ok = (int)CGDisplayModeGetWidth(mode) == w && (int)CGDisplayModeGetHeight(mode) == h;
    CFRelease(mode);
    return ok;
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

        __block CGVirtualDisplay *display = makeDisplay(name, lw, lh, YES);
        if (!display) {
            fprintf(stderr, "创建失败：可能是同身份的虚拟屏已在运行，或系统拒绝了该模式\n");
            return 1;
        }
        printf("已创建虚拟屏 \"%s\"  displayID=%u  背板 %dx%d  UI %dx%d @60Hz\n",
               name.UTF8String, (unsigned)[display displayID], lw * 2, lh * 2, lw, lh);
        fflush(stdout);

        // 等系统把模式定下来，核对是否真的拿到了 HiDPI
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC),
                       dispatch_get_main_queue(), ^{
            if (currentUISizeMatches(display, lw, lh)) {
                printf("HiDPI 已生效：背板 %dx%d / UI %dx%d\n", lw * 2, lh * 2, lw, lh);
                fflush(stdout);
                return;
            }
            printf("系统未提供 %dx%d 的 HiDPI 模式（小尺寸虚拟屏常见），改用 1:1\n", lw, lh);
            fflush(stdout);
            display = nil;                       // 释放即移除旧显示器
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC),
                           dispatch_get_main_queue(), ^{
                display = makeDisplay(name, lw, lh, NO);
                if (display) {
                    printf("已就绪：背板 %dx%d / UI %dx%d（1:1，画面略软）\n", lw, lh, lw, lh);
                } else {
                    fprintf(stderr, "以 1:1 重建失败\n");
                }
                fflush(stdout);
            });
        });

        [[NSRunLoop mainRunLoop] run];   // 保持存活，直到被信号终止
    }
    return 0;
}
