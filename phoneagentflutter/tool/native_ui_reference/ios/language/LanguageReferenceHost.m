#import <UIKit/UIKit.h>
#import "AITranslationLanguagePickerViewController.h"
#import "AITranslationDialPresetPolicy.h"

/// Fixed production picker; selection lives only in this independent host.
@interface LanguageRoot : UIViewController
@property(nonatomic, strong) UILabel *result;
@property(nonatomic, copy) NSString *code;
@property(nonatomic) BOOL presented;
@end
@implementation LanguageRoot
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    self.code = @"zh";
    self.result = [[UILabel alloc] initWithFrame:CGRectZero];
    self.result.text = @"合成语种已返回：未选择";
    self.result.textAlignment = NSTextAlignmentCenter;
    self.result.translatesAutoresizingMaskIntoConstraints = NO;
    UIButton *again = [UIButton buttonWithType:UIButtonTypeSystem];
    [again setTitle:@"重新选择语言" forState:UIControlStateNormal];
    [again addTarget:self action:@selector(openPicker) forControlEvents:UIControlEventTouchUpInside];
    again.translatesAutoresizingMaskIntoConstraints = NO;
    [self.view addSubview:self.result];
    [self.view addSubview:again];
    [NSLayoutConstraint activateConstraints:@[
        [self.result.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.result.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [again.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [again.topAnchor constraintEqualToAnchor:self.result.bottomAnchor constant:20]
    ]];
}
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (!self.presented) { self.presented = YES; [self openPicker]; }
}
- (void)openPicker {
    if (self.presentedViewController) return;
    AITranslationLanguagePickerViewController *picker = [[AITranslationLanguagePickerViewController alloc] initWithTitle:@"我的语言" selectedCode:self.code];
    __weak LanguageRoot *weakRoot = self;
    picker.onSelectLanguage = ^(AITranslationDialLanguageOption *option) {
        weakRoot.code = option.code;
        weakRoot.result.text = [@"合成语种已返回：" stringByAppendingString:option.code];
    };
    [self presentViewController:picker animated:NO completion:nil];
}
@end

@interface ReferenceDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation ReferenceDelegate
- (BOOL)application:(UIApplication *)app didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    self.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    self.window.rootViewController = [LanguageRoot new];
    [self.window makeKeyAndVisible];
    return YES;
}
@end
int main(int argc, char *argv[]) {
    @autoreleasepool { return UIApplicationMain(argc, argv, nil, NSStringFromClass(ReferenceDelegate.class)); }
}
