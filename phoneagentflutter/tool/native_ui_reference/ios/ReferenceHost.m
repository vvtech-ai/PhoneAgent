#import <UIKit/UIKit.h>
#import <CoreText/CoreText.h>
#if REFERENCE_FLUTTER
#import <Flutter/Flutter.h>
#else
#import "AIPureVoiceBubbleView.h"
#if REFERENCE_OPTIONS
#import "AIAgentInteractiveCardView.h"
#endif
#if REFERENCE_BATCH
#import "AIBatchTaskConfirmationCardView.h"
#endif
#if REFERENCE_RESULT
#import "AIBatchCallItemResultView.h"
#endif
#if REFERENCE_DOCUMENT
#import "AILargeTaskDocumentCardView.h"
#endif
#endif

// Simulator-only host. Only pure text rendering; no business SDK or service ports.
#if !REFERENCE_FLUTTER
@interface ReferenceController : UIViewController
@property(nonatomic, strong) CAGradientLayer *background;
#if REFERENCE_OPTIONS
@property(nonatomic, strong) UIView *optionsRow;
@property(nonatomic, strong) UILabel *optionsLabel;
#endif
#if REFERENCE_RESULT
@property(nonatomic, strong) UIView *resultRow;
@property(nonatomic, copy) NSDictionary *resultItem;
@property(nonatomic, assign) BOOL resultExpanded;
#endif
@end
@implementation ReferenceController
- (void)viewDidLoad {
    [super viewDidLoad];
    self.background = [CAGradientLayer layer];
    self.background.colors = @[(id)[UIColor colorWithRed:241.0/255 green:244.0/255 blue:250.0/255 alpha:1].CGColor,
                               (id)[UIColor colorWithRed:232.0/255 green:237.0/255 blue:245.0/255 alpha:1].CGColor];
    [self.view.layer insertSublayer:self.background atIndex:0];
    UIStackView *stack = [[UIStackView alloc] init];
    stack.translatesAutoresizingMaskIntoConstraints = NO;
    stack.axis = UILayoutConstraintAxisVertical;
    stack.spacing = 10; // Effective conversationStackView spacing in the fixed native source.
    [self.view addSubview:stack];
    [NSLayoutConstraint activateConstraints:@[
        [stack.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:18],
        [stack.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-18],
        [stack.topAnchor constraintEqualToAnchor:self.view.safeAreaLayoutGuide.topAnchor constant:200]
    ]];
#if REFERENCE_BATCH
    NSDictionary *confirmation = @{
        @"sections": @[@{@"title": @"任务信息", @"rows": @[@{@"label": @"目的", @"value": @"合成评审"}]}],
        @"rules": @[@{@"label": @"时间", @"value": @"合成时间"}],
        @"decision": @"PENDING",
        @"recipients": @[@{@"targetName": @"合成联系人", @"phoneNumber": @"", @"salutation": @"您好", @"detail": @"MOCK · 不拨号", @"status": @"READY"}],
        @"issues": @[@{@"title": @"合成问题", @"detail": @"未执行"}],
        @"contactSummary": @{@"originalCount": @6, @"callableCount": @5, @"skippedCount": @1}
    };
    AIBatchTaskConfirmationCardView *card = [[AIBatchTaskConfirmationCardView alloc]
        initWithConfirmation:confirmation modelTitle:nil availableBalance:nil
        contactsExpanded:NO onExpandChange:nil];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *row = [UIView new];
    [row addSubview:card];
    [stack addArrangedSubview:row];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
        [card.topAnchor constraintEqualToAnchor:row.topAnchor],
        [card.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
        [card.widthAnchor constraintEqualToConstant:308]
    ]];
#endif
#if REFERENCE_RESULT
    NSDictionary *item = @{
        @"status": @"SUCCESS", @"targetName": @"合成联系人", @"headline": @"合成结果：已完成",
        @"receiptFields": @[@{@"key": @"businessResult", @"label": @"业务结果", @"value": @"确认参加"},
                            @{@"key": @"purpose", @"label": @"事项", @"value": @"合成评审"}]
    };
    NSMutableDictionary *fixture = [item mutableCopy];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--synthetic-transcript"]) {
        fixture[@"transcript"] = @"assistant: 合成询问\ncallee: 合成答复";
    }
    self.resultItem = fixture;
    self.resultRow = [UIView new];
    [stack addArrangedSubview:self.resultRow];
    [self replaceResultCard];
#endif
#if REFERENCE_DOCUMENT
    AILargeTaskDocumentCardView *documentCard = [[AILargeTaskDocumentCardView alloc]
        initWithPresentation:@{@"parsing": @NO, @"files": @[
            @{@"fileName": @"合成任务资料.docx", @"charCount": @120},
            @{@"fileName": @"合成迁移演练用联系人与参会时间安排清单.xlsx", @"charCount": @40, @"truncated": @YES}
        ]}];
    documentCard.translatesAutoresizingMaskIntoConstraints = NO;
    UIView *documentRow = [UIView new];
    [documentRow addSubview:documentCard];
    [stack addArrangedSubview:documentRow];
    [NSLayoutConstraint activateConstraints:@[
        [documentCard.trailingAnchor constraintEqualToAnchor:documentRow.trailingAnchor],
        [documentCard.topAnchor constraintEqualToAnchor:documentRow.topAnchor],
        [documentCard.bottomAnchor constraintEqualToAnchor:documentRow.bottomAnchor],
        [documentCard.widthAnchor constraintEqualToConstant:308]
    ]];
#endif
#if REFERENCE_OPTIONS
    self.optionsRow = [UIView new];
    [stack addArrangedSubview:self.optionsRow];
    self.optionsLabel = [UILabel new];
    self.optionsLabel.text = @"合成已选：无";
    self.optionsLabel.font = [UIFont systemFontOfSize:14];
    [stack addArrangedSubview:self.optionsLabel];
    UIButton *reset = [UIButton buttonWithType:UIButtonTypeSystem];
    [reset setTitle:@"重置候选示例" forState:UIControlStateNormal];
    [reset addTarget:self action:@selector(resetOptions) forControlEvents:UIControlEventTouchUpInside];
    [stack addArrangedSubview:reset];
    [self resetOptions];
#endif
    NSMutableString *userText = [[NSProcessInfo.processInfo.arguments containsObject:@"--synthetic-short"] ? @"." : @"明天晚上六点，三个人。" mutableCopy];
    if ([NSProcessInfo.processInfo.arguments containsObject:@"--synthetic-long"]) {
        for (NSUInteger index = 0; index < 12; index++) [userText appendString:@"，合成新增要求"];
    }
#if REFERENCE_RESULT || REFERENCE_DOCUMENT || REFERENCE_OPTIONS
    NSArray<NSString *> *texts = @[];
#elif REFERENCE_BATCH
    NSArray<NSString *> *texts = @[@"合成确认说明", @"."];
#else
    NSArray<NSString *> *texts = @[@"想订演示联系人？告诉我时间和人数就行，有其他要求也可以一起说。", userText];
#endif
    for (NSUInteger index = 0; index < texts.count; index++) {
        BOOL user = index == 1;
        UIFont *font = [UIFont systemFontOfSize:14];
        CGRect measured = [texts[index] boundingRectWithSize:CGSizeMake(1000, 1000)
            options:NSStringDrawingUsesLineFragmentOrigin | NSStringDrawingUsesFontLeading
            attributes:@{NSFontAttributeName:font} context:nil];
        NSAttributedString *attributed = [[NSAttributedString alloc] initWithString:texts[index] attributes:@{NSFontAttributeName:font}];
        CTLineRef line = CTLineCreateWithAttributedString((__bridge CFAttributedStringRef)attributed);
        NSLog(@"REFERENCE_NATIVE_METRICS font=%@ width=%.2f advance=%.2f", font.fontName,
              measured.size.width, CTLineGetTypographicBounds(line, NULL, NULL, NULL));
        CFArrayRef runs = CTLineGetGlyphRuns(line);
        for (CFIndex runIndex = 0; runIndex < CFArrayGetCount(runs); runIndex++) {
            CTRunRef run = CFArrayGetValueAtIndex(runs, runIndex);
            CTFontRef runFont = CFDictionaryGetValue(CTRunGetAttributes(run), kCTFontAttributeName);
            CFStringRef name = CTFontCopyPostScriptName(runFont);
            NSLog(@"REFERENCE_NATIVE_FONT %@ length=%ld", (__bridge NSString *)name, CTRunGetStringRange(run).length);
            CFRelease(name);
        }
        CFRelease(line);
        UIView *row = [[UIView alloc] init];
        [stack addArrangedSubview:row];
        AIPureVoiceBubbleView *bubble = [[AIPureVoiceBubbleView alloc]
            initWithText:texts[index] user:user error:NO streaming:NO textMode:NO];
        bubble.translatesAutoresizingMaskIntoConstraints = NO;
        [row addSubview:bubble];
        [NSLayoutConstraint activateConstraints:@[
            [bubble.topAnchor constraintEqualToAnchor:row.topAnchor],
            [bubble.bottomAnchor constraintEqualToAnchor:row.bottomAnchor],
            [bubble.widthAnchor constraintLessThanOrEqualToAnchor:row.widthAnchor multiplier:AIPureVoiceBubbleView.maximumBubbleWidthRatio],
            user ? [bubble.trailingAnchor constraintEqualToAnchor:row.trailingAnchor]
                 : [bubble.leadingAnchor constraintEqualToAnchor:row.leadingAnchor],
            user ? [bubble.leadingAnchor constraintGreaterThanOrEqualToAnchor:row.leadingAnchor constant:44]
                 : [bubble.trailingAnchor constraintLessThanOrEqualToAnchor:row.trailingAnchor constant:-44]
        ]];
    }
}
#if REFERENCE_RESULT
- (void)replaceResultCard {
    for (UIView *view in self.resultRow.subviews) [view removeFromSuperview];
    __weak ReferenceController *weakSelf = self;
    AIBatchCallItemResultView *card = [[AIBatchCallItemResultView alloc]
        initWithItem:self.resultItem transcriptExpanded:self.resultExpanded
        transcriptExpandHandler:^(BOOL expanded) {
            weakSelf.resultExpanded = expanded;
            [weakSelf replaceResultCard];
        } recordingControlState:nil recordingHandler:nil];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.resultRow addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.resultRow.leadingAnchor],
        [card.topAnchor constraintEqualToAnchor:self.resultRow.topAnchor constant:12],
        [card.bottomAnchor constraintEqualToAnchor:self.resultRow.bottomAnchor],
        [card.widthAnchor constraintEqualToConstant:308]
    ]];
}
#endif
#if REFERENCE_OPTIONS
- (void)resetOptions {
    for (UIView *view in self.optionsRow.subviews) [view removeFromSuperview];
    self.optionsLabel.text = @"合成已选：无";
    NSDictionary *payload = @{@"title": @"请选择合成候选", @"items": @[
        @{@"id": @"synthetic1", @"label": @"合成餐厅", @"category": @"restaurant",
          @"rating": @4.7, @"averageCostYuan": @88, @"cuisine": @"粤菜",
          @"businessArea": @"合成商圈", @"distanceMeters": @1250,
          @"openingStatus": @"OPEN", @"openingHoursToday": @"10:00–22:00"},
        @{@"id": @"synthetic2", @"label": @"合成未营业餐厅", @"openingStatus": @"CLOSED"}
    ]};
    __weak ReferenceController *weakSelf = self;
    AIAgentInteractiveCardView *card = [AIAgentInteractiveCardView optionsCardWithPayload:payload
        enabled:YES onSelect:^(NSString *optionId) {
            weakSelf.optionsLabel.text = [optionId isEqualToString:@"synthetic1"]
                ? @"合成已选：第 1 个" : @"合成已选：第 2 个";
        }];
    card.translatesAutoresizingMaskIntoConstraints = NO;
    [self.optionsRow addSubview:card];
    [NSLayoutConstraint activateConstraints:@[
        [card.leadingAnchor constraintEqualToAnchor:self.optionsRow.leadingAnchor],
        [card.topAnchor constraintEqualToAnchor:self.optionsRow.topAnchor],
        [card.bottomAnchor constraintEqualToAnchor:self.optionsRow.bottomAnchor],
        [card.widthAnchor constraintEqualToConstant:284]
    ]];
}
#endif
- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.background.frame = self.view.bounds;
}
@end
#endif

@interface ReferenceDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ReferenceDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
#if REFERENCE_FLUTTER
    FlutterDartProject *project = [[FlutterDartProject alloc] initWithPrecompiledDartBundle:NSBundle.mainBundle];
    FlutterViewController *controller = [[FlutterViewController alloc] initWithProject:project nibName:nil bundle:nil];
    Class<FlutterPlugin> paragraph = NSClassFromString(@"PhoneAgentNativeParagraphChannel");
    NSAssert(paragraph != Nil, @"Pure paragraph renderer must be linked");
    [paragraph registerWithRegistrar:[controller registrarForPlugin:@"PhoneAgentNativeParagraph"]];
    self.window.rootViewController = controller;
#else
    self.window.rootViewController = [[ReferenceController alloc] init];
#endif
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(ReferenceDelegate.class));
    }
}
