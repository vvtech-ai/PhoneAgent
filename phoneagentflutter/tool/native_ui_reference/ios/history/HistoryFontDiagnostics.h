// Synthetic reference labels only. No production or account dependency.
#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>

static NSArray *HistoryFontRuns(NSAttributedString *text) {
    CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)text);
    NSMutableArray *result = [NSMutableArray new];
    for (id item in (__bridge NSArray *)CTLineGetGlyphRuns(line)) {
        CTRunRef run = (__bridge CTRunRef)item;
        NSDictionary *attributes = (__bridge NSDictionary *)CTRunGetAttributes(run);
        CTFontRef font = (__bridge CTFontRef)attributes[(id)kCTFontAttributeName];
        CFRange range = CTRunGetStringRange(run);
        NSString *name = CFBridgingRelease(CTFontCopyPostScriptName(font));
        [result addObject:@{@"font": name, @"size": @(CTFontGetSize(font)),
            @"start": @(range.location), @"length": @(range.length),
            @"width": @(CTRunGetTypographicBounds(run, CFRangeMake(0, 0), NULL, NULL, NULL))}];
    }
    CFRelease(line);
    return result;
}

static void HistoryCollectFonts(UIView *view, NSMutableArray *labels) {
    if ([view isKindOfClass:UILabel.class]) {
        UILabel *label = (UILabel *)view;
        NSString *text = label.text ?: @"";
        if (text.length) {
            NSAttributedString *attributed = label.attributedText ?: [[NSAttributedString alloc]
                initWithString:text attributes:@{NSFontAttributeName:label.font}];
            CGRect frame = [label convertRect:label.bounds toView:label.window];
            [labels addObject:@{@"text":text, @"font":label.font.fontName,
                @"size":@(label.font.pointSize), @"lineHeight":@(label.font.lineHeight),
                @"frame":NSStringFromCGRect(frame), @"runs":HistoryFontRuns(attributed)}];
        }
    }
    for (UIView *child in view.subviews) HistoryCollectFonts(child, labels);
}

static void HistoryWriteFontDiagnostics(UIView *view) {
    NSMutableArray *labels = [NSMutableArray new];
    HistoryCollectFonts(view, labels);
    NSDictionary *report = @{@"scope":@"synthetic-history-presentation-only", @"labels":labels};
    NSData *data = [NSJSONSerialization dataWithJSONObject:report options:NSJSONWritingPrettyPrinted error:NULL];
    [data writeToFile:[NSTemporaryDirectory() stringByAppendingPathComponent:@"history-font-diagnostics.json"] atomically:YES];
}
