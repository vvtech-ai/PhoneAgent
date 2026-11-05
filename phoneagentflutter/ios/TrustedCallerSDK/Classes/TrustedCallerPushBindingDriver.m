#import "TrustedCallerPushBindingDriver.h"
#import "TrustedCallerPushBindingState.h"
#import "TrustedCallerIncomingDiagnostics.h"
@interface TrustedCallerPushBindingDriver ()
@property(nonatomic, strong) TrustedCallerPushBindingState *state;
@property(nonatomic, copy) TrustedPushBootstrap bootstrap;
@property(nonatomic, copy) TrustedPushAction action;
@property(nonatomic, copy, nullable) NSDictionary *owner;
@property(nonatomic, copy, nullable) NSString *deviceToken;
@property(nonatomic) BOOL notificationAllowed;
@property(nonatomic) BOOL ready;
@property(nonatomic) BOOL bootstrapping;
@property(nonatomic) BOOL bootstrapFailed;
@end
@implementation TrustedCallerPushBindingDriver
- (instancetype)initWithBootstrap:(TrustedPushBootstrap)bootstrap action:(TrustedPushAction)action {
    if ((self = [super init])) {
        _state = [TrustedCallerPushBindingState new];
        _bootstrap = [bootstrap copy];
        _action = [action copy];
    }
    return self;
}
- (NSString *)diagnosticCode {
    if (self.bootstrapFailed) return @"IOS_BIND_STATE_INIT_FAILED";
    if (self.bootstrapping) return @"IOS_BIND_STATE_INITIALIZING";
    return self.state.diagnosticCode;
}
- (BOOL)needsRetry { return self.bootstrapFailed || self.state.needsRetry; }
- (void)updateOwner:(NSDictionary *)owner deviceToken:(NSString *)deviceToken
    notificationAllowed:(BOOL)notificationAllowed {
    NSAssert(NSThread.isMainThread, @"Account binding must be serialized on main thread");
    // Freeze mutable owner strings as well as the dictionary itself.
    NSMutableDictionary *frozen = [NSMutableDictionary dictionary];
    for (NSString *key in @[@"accountId", @"phone", @"loginEpoch", @"environment"]) {
        id value = owner[key];
        if ([value isKindOfClass:NSString.class] || [value isKindOfClass:NSNumber.class]) frozen[key] = [value copy];
    }
    self.owner = frozen.copy;
    self.deviceToken = [deviceToken isKindOfClass:NSString.class] ? deviceToken.copy : nil;
    self.notificationAllowed = notificationAllowed;
    [self advance];
}
- (void)advance {
    [self.state updateOwner:self.owner deviceToken:self.deviceToken
        notificationAllowed:self.notificationAllowed sdkReady:self.ready];
    if (self.needsRetry) return;
    if (!self.ready) {
        if (self.bootstrapping || !self.state.hasWork) return;
        self.bootstrapping = YES;
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding"
            code:@"IOS_SDK_INIT_STARTED" result:@"started"];
        __weak typeof(self) weakSelf = self;
        __block BOOL replied = NO;
        self.bootstrap(^(BOOL success) {
            NSAssert(NSThread.isMainThread, @"SDK bootstrap completion must be on main thread");
            if (replied) return;
            replied = YES;
            typeof(self) strongSelf = weakSelf;
            if (!strongSelf) return;
            strongSelf.bootstrapping = NO;
            strongSelf.ready = success;
            strongSelf.bootstrapFailed = !success;
            [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding"
                code:success ? @"IOS_SDK_INIT_SUCCEEDED" : @"IOS_SDK_INIT_FAILED"
                result:success ? @"succeeded" : @"failed"];
            if (!success) [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding"
                code:@"IOS_BIND_WAIT_RETRY" result:@"received"];
            if (success) [strongSelf advance];
        });
        return;
    }
    NSDictionary *action = self.state.nextAction;
    if (!action) return;
    __weak typeof(self) weakSelf = self;
    __block BOOL replied = NO;
    self.action(action, ^(BOOL success) {
        NSAssert(NSThread.isMainThread, @"SDK binding completion must be on main thread");
        if (replied) return;
        replied = YES;
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf) return;
        [strongSelf.state completeRequest:action[@"requestId"] success:success];
        if (!success) [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding"
            code:@"IOS_BIND_WAIT_RETRY" result:@"received"];
        [strongSelf advance];
    });
}
- (void)retry {
    if (self.bootstrapping) return;
    self.bootstrapFailed = NO;
    [self.state retry];
    [self advance];
}
@end
