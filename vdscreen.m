// vdscreen - 用私有 CGVirtualDisplay API 创建一块 HiDPI 虚拟显示器
//
// 用法: vdscreen <逻辑宽>x<逻辑高> [名字]
//   例: vdscreen 1133x744 "iPad mini 7"
//       背板 2266x1488、UI 看起来 1133x744（= iPad mini 7 原生像素）
//
// 进程存活期间显示器存在，退出（Ctrl-C / kill）即自动移除。
//
// 关键参数（缺一不可，否则 macOS 不会给出 HiDPI 模式）：
//   1. maxPixels = 逻辑尺寸 × 2
//   2. sizeInMillimeters = 逻辑尺寸 × 0.254  → 约 100 DPI
//   3. modes 同时声明逻辑模式和它的 2× 模式
//   4. hiDPI = 1，且 vendor/product/serial 唯一，避免与其它虚拟屏冲突

#import <Foundation/Foundation.h>
#import <AppKit/AppKit.h>
#import "CGVirtualDisplayShim.h"

static uint32_t serialForName(NSString *name) {
    uint32_t h = 0x811C9DC5;                       // FNV-1a：同名固定身份
    for (const uint8_t *p = (const uint8_t *)name.UTF8String; *p; p++) {
        h = (h ^ *p) * 0x01000193;
    }
    return h;
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

        CGVirtualDisplayDescriptor *desc = [[CGVirtualDisplayDescriptor alloc] init];
        desc.queue = dispatch_get_main_queue();
        desc.name = name;
        desc.maxPixelsWide = (unsigned)(lw * 2);
        desc.maxPixelsHigh = (unsigned)(lh * 2);
        desc.sizeInMillimeters = CGSizeMake(lw * 0.254, lh * 0.254);
        desc.vendorID = 0x1AB2;
        desc.productID = 0x1234;
        desc.serialNum = serialForName(name);
        desc.terminationHandler = ^(id reason, id display) {
            fprintf(stderr, "虚拟屏被系统移除\n");
        };

        CGVirtualDisplaySettings *settings = [[CGVirtualDisplaySettings alloc] init];
        settings.hiDPI = 1;
        settings.modes = @[[[CGVirtualDisplayMode alloc] initWithWidth:(unsigned)lw
                                                                height:(unsigned)lh
                                                           refreshRate:60.0],
                           [[CGVirtualDisplayMode alloc] initWithWidth:(unsigned)(lw * 2)
                                                                height:(unsigned)(lh * 2)
                                                           refreshRate:60.0]];

        CGVirtualDisplay *display = [[CGVirtualDisplay alloc] initWithDescriptor:desc];
        if (![display applySettings:settings]) {
            fprintf(stderr, "创建失败：可能是同身份的虚拟屏已在运行，或系统拒绝了该模式\n");
            return 1;
        }

        printf("已创建虚拟屏 \"%s\"  displayID=%u  背板 %dx%d  UI %dx%d @60Hz\n",
               name.UTF8String, (unsigned)[display displayID], lw * 2, lh * 2, lw, lh);
        fflush(stdout);

        [[NSRunLoop mainRunLoop] run];   // 保持存活，直到被信号终止
    }
    return 0;
}
