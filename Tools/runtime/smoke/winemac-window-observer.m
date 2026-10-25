/* Developer-only logging inside outRage's own Wine process.
 * No input, titles, pixels, accessibility APIs or other applications are read.
 * No Wine/Cocoa methods are replaced. Loaded only by a separate test runtime.
 */
#import <AppKit/AppKit.h>
#import <QuartzCore/QuartzCore.h>
#import <objc/message.h>
#include <mach-o/dyld.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>

static BOOL wine_bool(id object, const char *name) {
    SEL sel = sel_registerName(name);
    return [object respondsToSelector:sel] ? ((BOOL (*)(id, SEL))objc_msgSend)(object, sel) : NO;
}

static void sample_windows(unsigned int second) {
    Class wine = NSClassFromString(@"WineWindow");
    unsigned int count = 0;
    for (NSWindow *window in NSApp.windows) {
        if (!wine || ![window isKindOfClass:wine]) continue;
        NSRect f = window.frame;
        fprintf(stderr, "OUTRAGE_WINDOW_SAMPLE t=%u pid=%ld number=%ld "
                "frame=%.1f,%.1f,%.1f,%.1f visible=%d mini=%d activeSpace=%d "
                "occluded=%d alpha=%.3f opaque=%d emptyShape=%d drawn=%d "
                "appHidden=%d appActive=%d level=%ld layerHidden=%d\n",
                second, (long)getpid(), (long)window.windowNumber,
                f.origin.x, f.origin.y, f.size.width, f.size.height,
                window.isVisible, window.isMiniaturized, window.isOnActiveSpace,
                !(window.occlusionState & NSWindowOcclusionStateVisible), window.alphaValue,
                window.isOpaque, wine_bool(window, "isEmptyShaped"), wine_bool(window, "drawnSinceShown"),
                NSApp.isHidden, NSApp.isActive, (long)window.level, window.contentView.layer.isHidden);
        count++;
    }
    fprintf(stderr, "OUTRAGE_WINDOW_SAMPLE_SUMMARY t=%u pid=%ld app=%d wineClass=%d count=%u\n",
            second, (long)getpid(), NSApp != nil, wine != Nil, count);
    fflush(stderr);
}

static void image_added(const struct mach_header *header, intptr_t slide) {
    static BOOL scheduled;
    (void)slide;
    if (scheduled) return;
    for (uint32_t i = 0; i < _dyld_image_count(); i++) {
        if (_dyld_get_image_header(i) != header) continue;
        const char *name = _dyld_get_image_name(i);
        if (!name || !strstr(name, "/winemac.so")) return;
        scheduled = YES;
        for (unsigned int second = 1; second <= 61; second += 10) {
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)second * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
                sample_windows(second);
            });
        }
        return;
    }
}

__attribute__((constructor)) static void start_window_observer(void) {
    _dyld_register_func_for_add_image(image_added);
}
