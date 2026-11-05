#import <UIKit/UIKit.h>
#import "GeneratedOriginalAudioPresentation.h"

// Standalone simulator navigation only; no SDK, account or device audio ports.
@interface OriginalAudioReferenceRoot : UIViewController
@end
@implementation OriginalAudioReferenceRoot
- (void)viewDidLoad {
    [super viewDidLoad];
    self.view.backgroundColor = UIColor.whiteColor;
    UIButton *open = [UIButton buttonWithType:UIButtonTypeSystem];
    [open setTitle:@"查看原音设置（纯内存）" forState:UIControlStateNormal];
    open.translatesAutoresizingMaskIntoConstraints = NO;
    [open addTarget:self action:@selector(openAudio) forControlEvents:UIControlEventTouchUpInside];
    [self.view addSubview:open];
    [NSLayoutConstraint activateConstraints:@[
        [open.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [open.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor],
        [open.heightAnchor constraintGreaterThanOrEqualToConstant:48]
    ]];
}
- (void)openAudio {
    [self.navigationController pushViewController:[AISettingsOriginalAudioViewController new] animated:YES];
}
@end

@interface OriginalAudioReferenceApp : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end
@implementation OriginalAudioReferenceApp
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UINavigationController *navigation = [[UINavigationController alloc]
        initWithRootViewController:[OriginalAudioReferenceRoot new]];
    navigation.navigationBarHidden = YES;
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(OriginalAudioReferenceApp.class));
    }
}
