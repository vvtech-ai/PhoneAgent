#import <UIKit/UIKit.h>
#import "AISettingsOutboundNumberViewController.h"
#import "AIAccountSettingsService.h"

@implementation AIOutboundNumberResponse
@end

static NSString *ReferenceState(void) {
    NSArray<NSString *> *arguments = NSProcessInfo.processInfo.arguments;
    NSUInteger index = [arguments indexOfObject:@"--outbound-state"];
    return index != NSNotFound && index + 1 < arguments.count ? arguments[index + 1] : @"saved";
}

static AIOutboundNumberResponse *ReferenceResponse(void) {
    AIOutboundNumberResponse *response = [AIOutboundNumberResponse new];
    response.accountId = @"synthetic-ui-only";
    response.outboundNumber = [ReferenceState() isEqualToString:@"empty"] ? @"" : @"13800000000";
    response.configured = response.outboundNumber.length > 0;
    return response;
}

static NSError *ReferenceError(NSString *message) {
    return [NSError errorWithDomain:@"SyntheticOutboundReference" code:1
                          userInfo:@{NSLocalizedDescriptionKey:message}];
}

@implementation AIAccountSettingsService
+ (instancetype)sharedService {
    static AIAccountSettingsService *service;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ service = [AIAccountSettingsService new]; });
    return service;
}
- (void)fetchOutboundNumberWithCompletion:(ReferenceOutboundCompletion)completion {
    if ([ReferenceState() isEqualToString:@"loading"]) return;
    if ([ReferenceState() isEqualToString:@"error"]) {
        completion(nil, ReferenceError(@"合成读取失败"));
    } else {
        completion(ReferenceResponse(), nil);
    }
}
- (void)updateOutboundNumber:(NSString *)number completion:(ReferenceOutboundCompletion)completion {
    completion(nil, ReferenceError(@"MOCK · 不保存真实配置"));
}
- (void)deleteOutboundNumberWithCompletion:(ReferenceOutboundCompletion)completion {
    completion(nil, ReferenceError(@"MOCK · 不删除真实配置"));
}
@end

@interface OutboundReferenceDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation OutboundReferenceDelegate
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)options {
    self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
    UIViewController *root = [UIViewController new];
    root.view.backgroundColor = [UIColor colorWithRed:248.0/255.0 green:249.0/255.0 blue:252.0/255.0 alpha:1];
    UILabel *notice = [UILabel new];
    notice.text = @"合成外呼配置已返回";
    notice.accessibilityIdentifier = @"synthetic-outbound-return";
    notice.numberOfLines = 0;
    notice.translatesAutoresizingMaskIntoConstraints = NO;
    [root.view addSubview:notice];
    [NSLayoutConstraint activateConstraints:@[
        [notice.centerXAnchor constraintEqualToAnchor:root.view.centerXAnchor],
        [notice.centerYAnchor constraintEqualToAnchor:root.view.centerYAnchor],
        [notice.widthAnchor constraintLessThanOrEqualToAnchor:root.view.widthAnchor constant:-40]
    ]];
    UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
    self.window.rootViewController = navigation;
    [self.window makeKeyAndVisible];
    AISettingsOutboundNumberViewController *page = [AISettingsOutboundNumberViewController new];
    page.initialResponse = ReferenceResponse();
    [navigation pushViewController:page animated:NO];
    return YES;
}
@end

int main(int argc, char *argv[]) {
    @autoreleasepool {
        return UIApplicationMain(argc, argv, nil, NSStringFromClass(OutboundReferenceDelegate.class));
    }
}
