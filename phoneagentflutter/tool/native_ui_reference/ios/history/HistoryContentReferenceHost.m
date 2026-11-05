#import <UIKit/UIKit.h>
#import <Masonry/Masonry.h>
#import "GeneratedHistoryPresentation.h"
#import "HistoryFontDiagnostics.h"

/// Presentation assembly only: no original controller lifecycle or audio.
@interface HistoryContentReference : UIViewController
@end
@implementation HistoryContentReference
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:244/255.0 green:247/255.0 blue:251/255.0 alpha:1];
    AIRealtimeTranslationDetail *detail = [AIRealtimeTranslationDetail new];
    detail.targetName = @"合成翻译对象";
    detail.phoneNumber = @"+12025550123";
    detail.connectedAt = @"2026-09-16T11:00:00";
    detail.durationMillis = @12000;
    detail.myLanguage = @"zh-CN";
    HistoryHeaderReference *builder = [HistoryHeaderReference new];
    UIView *header = [builder headerViewForDetail:detail];
    [self.view addSubview:header];
    [header mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(18);
        make.leading.equalTo(self.view).offset(20);
        make.trailing.equalTo(self.view).offset(-20);
    }];
    UIScrollView *scroll = [UIScrollView new];
    scroll.alwaysBounceVertical = YES;
    [self.view addSubview:scroll];
    [scroll mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(header.mas_bottom);
        make.leading.trailing.bottom.equalTo(self.view);
    }];
    UIStackView *stack = [UIStackView new];
    stack.axis = UILayoutConstraintAxisVertical;
    stack.alignment = UIStackViewAlignmentFill;
    stack.spacing = 18;
    [scroll addSubview:stack];
    [stack mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(scroll).offset(18);
        make.leading.equalTo(scroll).offset(20);
        make.trailing.equalTo(scroll).offset(-20);
        make.bottom.equalTo(scroll).offset(-28);
        make.width.equalTo(self.view).offset(-40);
    }];
    NSArray *rows = @[
        @[@"local", @"zh-CN", @"请确认今天的营业时间。", @"en-US", @"Please confirm today’s opening hours."],
        @[@"merchant", @"en-US", @"We are open until eight this evening.", @"zh-CN", @"今天营业到晚上八点。"]
    ];
    BOOL empty = [NSProcessInfo.processInfo.arguments containsObject:@"--history-empty"];
    if (empty) {
        [stack addArrangedSubview:[builder emptySubtitleView]];
        rows = @[];
    }
    for (NSArray *row in rows) {
        AIRealtimeTranslationTranscript *transcript = [AIRealtimeTranslationTranscript new];
        transcript.sourceLeg = row[0]; transcript.sourceLanguage = row[1];
        transcript.sourceText = row[2]; transcript.translatedLanguage = row[3];
        transcript.translatedText = row[4];
        AIRealtimeTranscriptBubble *bubble = [AIRealtimeTranscriptBubble new];
        [bubble configureWithTranscript:transcript myLanguage:detail.myLanguage];
        [stack addArrangedSubview:bubble];
    }
    UIButton *close = [UIButton buttonWithType:UIButtonTypeSystem];
    [close setTitle:@"×" forState:UIControlStateNormal];
    [close setTitleColor:[UIColor colorWithWhite:17/255.0 alpha:1] forState:UIControlStateNormal];
    close.titleLabel.font = [UIFont systemFontOfSize:32 weight:UIFontWeightLight];
    close.accessibilityLabel = @"关闭实时翻译记录";
    [close addTarget:self action:@selector(closeTapped) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:close];
    [close mas_makeConstraints:^(MASConstraintMaker *make) {
        make.top.equalTo(self.view.mas_safeAreaLayoutGuideTop).offset(18);
        make.trailing.equalTo(self.view).offset(-20);
        make.width.height.mas_equalTo(44);
    }];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    HistoryWriteFontDiagnostics(self.view);
}
- (void)closeTapped {
    UILabel *result = [UILabel new];
    result.text = @"合成历史展示已返回";
    result.textAlignment = NSTextAlignmentCenter;
    result.backgroundColor = UIColor.whiteColor;
    self.view = result;
}
@end

// Host callbacks are synthetic, never the original controller's service actions.
@interface HistoryInitialReference : HistoryInitialStateReference
@property(nonatomic, assign) BOOL finished;
@property(nonatomic, assign) BOOL waiting;
@end
@implementation HistoryInitialReference
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = [UIColor colorWithRed:244/255.0 green:247/255.0 blue:251/255.0 alpha:1];
    [self buildBaseLayout];
    __weak typeof(self) weakSelf = self;
    self.closeHandler = ^{
        typeof(self) self = weakSelf;
        if (!self || self.finished) return;
        self.finished = YES;
        UILabel *result = [UILabel new];
        result.text = @"合成历史展示已返回";
        result.textAlignment = NSTextAlignmentCenter;
        result.backgroundColor = UIColor.whiteColor;
        self.view = result;
    };
    self.retryHandler = ^{
        typeof(self) self = weakSelf;
        if (!self || self.finished || self.waiting) return;
        self.waiting = YES;
        [self showLoadingState];
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 2 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            typeof(self) self = weakSelf;
            if (!self || self.finished || !self.view.window) return;
            self.view.window.rootViewController = [HistoryContentReference new];
        });
    };
    NSArray *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--history-initial"];
    if (index != NSNotFound && index + 1 < arguments.count && [arguments[index + 1] isEqualToString:@"error"]) {
        [self showErrorStateWithMessage:@"记录加载失败"];
    } else {
        [self showLoadingState];
    }
}
@end

@interface ReferenceDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ReferenceDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.window.rootViewController = [NSProcessInfo.processInfo.arguments containsObject:@"--history-initial"]
        ? [HistoryInitialReference new] : [HistoryContentReference new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ReferenceDelegate.class)); }
}
