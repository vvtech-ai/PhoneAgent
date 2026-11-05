#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedIdentityOverlaySurface.m"
NSString *const UIApplicationDidBecomeActiveNotification = @"applicationActive";
static NSMutableDictionary *channels;
static FlutterEngine *lastEngine;
@interface OverlayTransition : NSObject <UIViewControllerTransitionCoordinator>
@property (nonatomic, copy) void (^completion)(id<UIViewControllerTransitionCoordinatorContext>);
@end
@implementation OverlayTransition
- (BOOL)animateAlongsideTransition:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))animation
    completion:(void (^)(id<UIViewControllerTransitionCoordinatorContext>))completion {
    self.completion = completion; return YES;
}
@end
@implementation UIView
@end
@implementation UIApplication
+ (instancetype)sharedApplication { static UIApplication *app; if (!app) app = [self new]; return app; }
@end
@implementation UIViewController
- (instancetype)init { if ((self = [super init])) { _viewIfLoaded = [UIView new]; _viewIfLoaded.window = @YES; } return self; }
- (void)presentViewController:(UIViewController *)controller animated:(BOOL)animated completion:(void (^)(void))completion {
    NSCAssert(!self.presentedViewController, @"must never replace SDK navigation");
    self.presentedViewController = controller; controller.presentingViewController = self;
    self.presentations++; if (completion) completion();
}
- (void)dismissViewControllerAnimated:(BOOL)animated completion:(void (^)(void))completion {
    self.dismissals++; self.presentingViewController.presentedViewController = nil;
    self.presentingViewController = nil; if (completion) completion();
}
@end
@implementation FlutterMethodCall
@end
@implementation FlutterMethodChannel
+ (instancetype)methodChannelWithName:(NSString *)name binaryMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    FlutterMethodChannel *channel = [self new]; channel.sent = [NSMutableArray array]; channels[name] = channel; return channel;
}
- (void)setMethodCallHandler:(void (^)(FlutterMethodCall *, FlutterResult))handler { self.handler = handler; }
- (void)invokeMethod:(NSString *)method arguments:(id)arguments { [self.sent addObject:@{@"method":method, @"arguments":arguments ?: NSNull.null}]; }
@end
@implementation FlutterEngine
- (instancetype)initWithName:(NSString *)name project:(id)project allowHeadlessExecution:(BOOL)allow {
    if ((self = [super init])) { lastEngine = self; NSCAssert(!allow, @"no background SDK engine"); } return self;
}
- (NSObject<FlutterBinaryMessenger> *)binaryMessenger { return self; }
- (BOOL)runWithEntrypoint:(NSString *)entrypoint { self.entrypoint = entrypoint; return YES; }
- (void)destroyContext { self.destroyed = YES; }
@end
@implementation FlutterViewController
- (void)setFlutterViewDidRenderCallback:(void (^)(void))callback { self.firstFrame = callback; }
- (instancetype)initWithEngine:(FlutterEngine *)engine nibName:(NSString *)nib bundle:(id)bundle {
    if ((self = [super init])) engine.viewController = self; return self;
}
@end
static id call(NSString *channelName, NSString *method, id arguments) {
    FlutterMethodCall *request = [FlutterMethodCall new]; request.method = method; request.arguments = arguments;
    __block id result; FlutterMethodChannel *channel = channels[channelName];
    NSCAssert(channel.handler != nil, @"channel must be registered");
    channel.handler(request, ^(id value) { result = value; }); return result;
}
static id synchronizeOverlay(id snapshot) { return call(@"phone_agent/trusted_identity_surface", @"synchronize", snapshot); }
int main(void) { @autoreleasepool {
    channels = [NSMutableDictionary dictionary];
    __block UIViewController *sdk = nil;
    __block BOOL current = YES;
    TrustedIdentityOverlaySurface *surface = [[TrustedIdentityOverlaySurface alloc]
        initWithMessenger:(id)[NSObject new] presenter:^UIViewController * { return sdk; }
        acceptsOwner:^BOOL(NSDictionary *owner) { return current && [owner[@"accountId"] isEqual:@"synthetic"]; }];
    NSDictionary *a = @{@"owner":@{@"accountId":@"synthetic"}, @"presentationId":@"A"};
    NSDictionary *b = @{@"owner":@{@"accountId":@"synthetic"}, @"presentationId":@"B"};
    NSCAssert([synchronizeOverlay(a) isEqual:@"fallback"], @"normal Flutter fallback");
    NSCAssert(!lastEngine, @"normal page must not create engine");
    sdk = [UIViewController new];
    UIApplication.sharedApplication.applicationState = UIApplicationStateBackground;
    NSCAssert([synchronizeOverlay(a) isEqual:@"deferred"], @"background defers");
    NSCAssert(sdk.presentations == 0, @"no background presentation");
    UIApplication.sharedApplication.applicationState = UIApplicationStateActive;
    sdk.isBeingPresented = YES;
    NSCAssert([synchronizeOverlay(a) isEqual:@"deferred"], @"SDK opening defers");
    sdk.isBeingPresented = NO;
    NSCAssert([synchronizeOverlay(a) isEqual:@"overlay"], @"must present above SDK");
    UIViewController *overlay = sdk.presentedViewController;
    FlutterEngine *engine = lastEngine;
    NSCAssert(overlay && sdk.dismissals == 0, @"SDK must remain presented");
    NSCAssert([engine.entrypoint isEqual:@"trustedIdentityOverlayMain"], @"display-only entrypoint");
    FlutterMethodChannel *main = channels[@"phone_agent/trusted_identity_surface"];
    NSCAssert(main.sent.count == 0, @"present alone is not visibility proof");
    call(@"phone_agent/trusted_identity_overlay", @"ready", nil);
    call(@"phone_agent/trusted_identity_overlay", @"rendered", @"A");
    NSCAssert(main.sent.count == 0, @"Dart layout alone is not a native rendered frame");
    ((FlutterViewController *)overlay).firstFrame();
    NSCAssert([main.sent.lastObject[@"method"] isEqual:@"presented"], @"render and present both required");
    sdk.viewIfLoaded.window = nil; // UIKit removes a covered full-screen view.
    NSCAssert([synchronizeOverlay(b) isEqual:@"overlay"], @"new snapshot accepted");
    NSCAssert(sdk.presentedViewController == overlay && lastEngine == engine, @"updates reuse overlay");
    call(@"phone_agent/trusted_identity_overlay", @"dismiss", @"A");
    NSCAssert(sdk.presentedViewController == overlay, @"stale dismiss cannot close B");
    NSUInteger eventsBeforeDismiss = main.sent.count;
    OverlayTransition *transition = [OverlayTransition new];
    overlay.transitionCoordinator = transition;
    call(@"phone_agent/trusted_identity_overlay", @"dismiss", @"B");
    NSCAssert(!engine.destroyed, @"release must wait for presentation transition");
    NSCAssert([synchronizeOverlay(a) isEqual:@"deferred"], @"new event waits while closing");
    transition.completion(nil);
    NSCAssert(main.sent.count == eventsBeforeDismiss + 1, @"user dismiss must not emit retry and reopen itself");
    NSCAssert(!sdk.presentedViewController && engine.destroyed, @"dismiss releases display engine");
    NSCAssert(sdk.dismissals == 0 && sdk.presentations == 1, @"SDK never closed or reopened");
    NSCAssert([main.sent.lastObject[@"arguments"] isEqual:@"B"], @"dismiss refers to latest identity");
    sdk.viewIfLoaded.window = @YES;
    synchronizeOverlay(a); engine = lastEngine; current = NO; synchronizeOverlay(b);
    NSCAssert(!sdk.presentedViewController && engine.destroyed, @"account invalidation clears identity");
    current = YES; synchronizeOverlay(b); engine = lastEngine; synchronizeOverlay(nil);
    NSCAssert(!sdk.presentedViewController && engine.destroyed, @"null clears identity");
    [surface close];
    puts("trusted identity overlay: native coordinator scenarios passed (UIKit/Flutter doubles)");
} return 0; }
