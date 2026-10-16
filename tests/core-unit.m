// 加载核心函数，但不调用创建显示器的 main。
#define main vdscreen_core_main
#import "../vdscreen.m"
#undef main
#include <assert.h>

int main(void) {
    @autoreleasepool {
        NSString *identity = @"io.github.lyondan.vdscreen.integration";
        CGVirtualDisplayDescriptor *landscape = makeDescriptor(@"iPad", 1133, 744, YES, identity);
        CGVirtualDisplayDescriptor *portrait = makeDescriptor(@"iPhone", 804, 1748, YES, identity);
        CGVirtualDisplayDescriptor *fallback = makeDescriptor(@"small", 402, 874, NO, identity);
        CGVirtualDisplayDescriptor *restored = makeDescriptor(@"renamed", 1133, 744, YES, identity);
        CGVirtualDisplayDescriptor *other = makeDescriptor(@"iPad", 1133, 744, YES, @"another.service");

        // 固定已使用的序列号，防止以后改哈希算法又产生一批新 ICC。
        assert(landscape.serialNum == 0x95104477);
        assert(portrait.serialNum == landscape.serialNum);
        assert(fallback.serialNum == landscape.serialNum);
        assert(restored.serialNum == landscape.serialNum);
        assert(other.serialNum != landscape.serialNum);
        assert(portrait.vendorID == landscape.vendorID && portrait.productID == landscape.productID);
        assert(fallback.vendorID == landscape.vendorID && fallback.productID == landscape.productID);
        assert(landscape.maxPixelsWide == 2266 && landscape.maxPixelsHigh == 1488);
        assert(fallback.maxPixelsWide == 402 && fallback.maxPixelsHigh == 874);
        puts("核心: 稳定身份、独立服务与 HiDPI 描述符检查通过（未创建显示器）");
    }
    return 0;
}
