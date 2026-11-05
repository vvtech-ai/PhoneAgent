#import "TrustedIdentityOverlaySurface.h"

@interface TrustedIdentityOverlaySurface ()
@property (nonatomic, strong) FlutterMethodChannel *mainChannel;
@property (nonatomic, strong, nullable) FlutterMethodChannel *displayChannel;
@property (nonatomic, strong, nullable) FlutterEngine *engine;
@property (nonatomic, strong, nullable) FlutterViewController *controller;
@property (nonatomic, copy) UIViewController *(^presenter)(void);
@property (nonatomic, copy) BOOL (^acceptsOwner)(NSDictionary *);
@property (nonatomic, copy, nullable) NSDictionary *snapshot;
@property (nonatomic, copy, nullable) NSString *renderedId;
@property (nonatomic, copy, nullable) NSString *reportedId;
@property (nonatomic) BOOL ready;
@property (nonatomic) BOOL presented;
@property (nonatomic) BOOL hasFrame;
@property (nonatomic) BOOL closing;
@end

@implementation TrustedIdentityOverlaySurface
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger
    presenter:(UIViewController *(^)(void))presenter
    acceptsOwner:(BOOL (^)(NSDictionary *))acceptsOwner {
    if ((self = [super init])) {
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(applicationBecameActive:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
        _presenter = [presenter copy];
        _acceptsOwner = [acceptsOwner copy];
        _mainChannel = [FlutterMethodChannel methodChannelWithName:@"phone_agent/trusted_identity_surface"
            binaryMessenger:messenger];
        __weak typeof(self) weakSelf = self;
        [_mainChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult result) {
            TrustedIdentityOverlaySurface *surface = weakSelf;
            if (!surface) { result(@"deferred"); return; }
            if (![call.method isEqual:@"synchronize"]) { result(FlutterMethodNotImplemented); return; }
            [surface synchronize:call.arguments result:result];
        }];
    }
    return self;
}
- (void)synchronize:(id)value result:(FlutterResult)result {
    if (!value || value == NSNull.null) { [self closeWithRetry:NO]; result(@"fallback"); return; }
    if (![value isKindOfClass:NSDictionary.class]) { result(@"deferred"); return; }
    NSDictionary *snapshot = value;
    NSDictionary *owner = snapshot[@"owner"];
    NSString *identifier = snapshot[@"presentationId"];
    if (![owner isKindOfClass:NSDictionary.class] ||
        ![identifier isKindOfClass:NSString.class] || identifier.length == 0 ||
        !self.acceptsOwner(owner)) {
        [self closeWithRetry:NO]; result(@"deferred"); return;
    }
    UIViewController *presenter = self.presenter();
    if (!presenter) { [self closeWithRetry:NO]; result(@"fallback"); return; }
    if (self.closing || UIApplication.sharedApplication.applicationState != UIApplicationStateActive) {
        result(@"deferred"); return;
    }
    // Full-screen presentation removes the SDK view from its window. Updates must
    // use our overlay's ownership, not require the covered SDK view to be visible.
    if (self.controller && self.controller.presentingViewController == presenter) {
        self.snapshot = snapshot;
        [self sendSnapshot];
        [self reportVisible];
        result(@"overlay"); return;
    }
    if (presenter.isBeingPresented || presenter.isBeingDismissed || presenter.transitionCoordinator ||
        !presenter.viewIfLoaded.window ||
        (presenter.presentedViewController && presenter.presentedViewController != self.controller)) {
        result(@"deferred"); return;
    }
    self.snapshot = snapshot;
    FlutterEngine *engine = [[FlutterEngine alloc] initWithName:@"trusted-identity-display"
        project:nil allowHeadlessExecution:NO];
    if (![engine runWithEntrypoint:@"trustedIdentityOverlayMain"]) {
        self.snapshot = nil;
        [engine destroyContext];
        result(@"deferred");
        return;
    }
    self.engine = engine;
    self.ready = NO;
    self.presented = NO;
    self.displayChannel = [FlutterMethodChannel methodChannelWithName:@"phone_agent/trusted_identity_overlay"
        binaryMessenger:engine.binaryMessenger];
    __weak typeof(self) weakSelf = self;
    __weak FlutterEngine *weakEngine = engine;
    [self.displayChannel setMethodCallHandler:^(FlutterMethodCall *call, FlutterResult reply) {
        TrustedIdentityOverlaySurface *surface = weakSelf;
        if (!surface || !weakEngine || surface.engine != weakEngine) { reply(nil); return; }
        if ([call.method isEqual:@"ready"]) {
            surface.ready = YES;
            reply(nil);
            [surface sendSnapshot];
        } else if ([call.method isEqual:@"rendered"]) {
            if ([call.arguments isKindOfClass:NSString.class] &&
                [call.arguments isEqual:surface.snapshot[@"presentationId"]]) {
                surface.renderedId = call.arguments;
                [surface reportVisible];
            }
            reply(nil);
        } else if ([call.method isEqual:@"dismiss"]) {
            NSString *current = surface.snapshot[@"presentationId"];
            BOOL matches = [call.arguments isKindOfClass:NSString.class] &&
                [current isEqual:call.arguments];
            reply(nil);
            if (matches) {
                [surface closeWithRetry:NO];
                [surface.mainChannel invokeMethod:@"dismissed" arguments:current];
            }
        } else reply(FlutterMethodNotImplemented);
    }];
    FlutterViewController *controller = [[FlutterViewController alloc] initWithEngine:engine
        nibName:nil bundle:nil];
    controller.modalPresentationStyle = UIModalPresentationFullScreen;
    controller.modalInPresentation = YES;
    self.controller = controller;
    [controller setFlutterViewDidRenderCallback:^{
        TrustedIdentityOverlaySurface *surface = weakSelf;
        if (surface.engine != weakEngine) return;
        surface.hasFrame = YES;
        [surface reportVisible];
    }];
    [presenter presentViewController:controller animated:YES completion:^{
        TrustedIdentityOverlaySurface *surface = weakSelf;
        if (surface.controller != controller) return;
        surface.presented = YES;
        [surface reportVisible];
    }];
    result(@"overlay");
}
- (void)sendSnapshot {
    if (self.ready && self.snapshot) [self.displayChannel invokeMethod:@"update" arguments:self.snapshot];
}
- (void)reportVisible {
    NSString *identifier = self.snapshot[@"presentationId"];
    if (!self.presented || !self.hasFrame || ![self.renderedId isEqual:identifier] ||
        [self.reportedId isEqual:identifier] || !self.controller.viewIfLoaded.window ||
        self.controller.presentedViewController ||
        UIApplication.sharedApplication.applicationState != UIApplicationStateActive) return;
    self.reportedId = identifier;
    [self.mainChannel invokeMethod:@"presented" arguments:identifier];
}
- (void)close { [self closeWithRetry:YES]; }
- (void)closeWithRetry:(BOOL)retry {
    self.snapshot = nil;
    self.renderedId = nil;
    self.reportedId = nil;
    self.ready = NO;
    self.presented = NO;
    self.hasFrame = NO;
    FlutterViewController *controller = self.controller;
    FlutterEngine *engine = self.engine;
    [self.displayChannel setMethodCallHandler:nil];
    self.displayChannel = nil;
    self.controller = nil;
    self.engine = nil;
    if (!engine) return;
    self.closing = YES;
    __weak typeof(self) weakSelf = self;
    void (^finish)(void) = ^{
        engine.viewController = nil;
        [engine destroyContext];
        TrustedIdentityOverlaySurface *surface = weakSelf;
        surface.closing = NO;
        if (retry) [surface.mainChannel invokeMethod:@"retry" arguments:@""];
    };
    void (^dismiss)(void) = ^{
        if (controller.presentingViewController) [controller dismissViewControllerAnimated:NO completion:finish];
        else finish();
    };
    id<UIViewControllerTransitionCoordinator> transition = controller.transitionCoordinator;
    if (transition) {
        [transition animateAlongsideTransition:nil completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
            dismiss();
        }];
    } else dismiss();
}
- (void)applicationBecameActive:(NSNotification *)notification {
    [self reportVisible];
    [self.mainChannel invokeMethod:@"retry" arguments:@""];
}
- (void)dealloc {
    [NSNotificationCenter.defaultCenter removeObserver:self];
    [_mainChannel setMethodCallHandler:nil];
    [_displayChannel setMethodCallHandler:nil];
    [_engine destroyContext];
}
@end
