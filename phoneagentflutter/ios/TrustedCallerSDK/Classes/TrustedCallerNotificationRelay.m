#import "TrustedCallerNotificationRelay.h"
#import "TrustedCallerIncomingDiagnostics.h"
#import "TrustedCallerPlugin.h"
@interface TrustedCallerNotificationRelay ()
@property(nonatomic, strong) TrustedCallerNotificationRouting *routing;
@property(nonatomic, weak) id<UNUserNotificationCenterDelegate> previous;
@end
@implementation TrustedCallerNotificationRelay
+ (instancetype)sharedRelay {
    static TrustedCallerNotificationRelay *relay;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        relay = [TrustedCallerNotificationRelay new];
        relay.routing = [TrustedCallerNotificationRouting new];
    });
    return relay;
}
- (void)attachConsumer:(NSUInteger)consumer receive:(TrustedNotificationReceive)receive {
    [self.routing attachConsumer:consumer receive:receive];
}
- (void)install {
    NSAssert(NSThread.isMainThread, @"Notification delegate installation is serialized");
    if (!self.routing.hasConsumer) return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    if (center.delegate == self) return;
    self.previous = center.delegate;
    center.delegate = self;
}
- (void)detachConsumer:(NSUInteger)consumer {
    if (![self.routing detachConsumer:consumer]) return;
    UNUserNotificationCenter *center = UNUserNotificationCenter.currentNotificationCenter;
    if (center.delegate == self) center.delegate = self.previous;
    self.previous = nil;
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    willPresentNotification:(UNNotification *)notification
    withCompletionHandler:(void (^)(UNNotificationPresentationOptions))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingReceive" code:@"IOS_PUSH_FOREGROUND" result:@"received"];
        id<UNUserNotificationCenterDelegate> previous = self.previous;
        [self.routing routeUserInfo:notification.request.content.userInfo trustedOptions:UNNotificationPresentationOptionSound fallback:^(TrustedNotificationReply reply) {
            if ([previous respondsToSelector:@selector(userNotificationCenter:willPresentNotification:withCompletionHandler:)]) {
                [previous userNotificationCenter:center willPresentNotification:notification withCompletionHandler:reply];
            } else reply(0);
        } completion:completion];
    });
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center
    didReceiveNotificationResponse:(UNNotificationResponse *)response
    withCompletionHandler:(void (^)(void))completion {
    dispatch_async(dispatch_get_main_queue(), ^{
        id<UNUserNotificationCenterDelegate> previous = self.previous;
        // Dismiss/custom actions remain owned by the original notification delegate.
        BOOL open = [response.actionIdentifier isEqual:UNNotificationDefaultActionIdentifier];
        NSDictionary *payload = open ? response.notification.request.content.userInfo : @{};
        if (open) [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingReceive" code:@"IOS_PUSH_CLICK" result:@"received"];
        [self.routing routeUserInfo:payload fallback:^(TrustedNotificationReply reply) {
            if ([previous respondsToSelector:@selector(userNotificationCenter:didReceiveNotificationResponse:withCompletionHandler:)]) {
                [previous userNotificationCenter:center didReceiveNotificationResponse:response withCompletionHandler:^{ reply(0); }];
            } else reply(0);
        } completion:^(NSUInteger options) {
            if (open) [TrustedCallerPlugin reopenIncomingNotification:payload];
            completion();
        }];
    });
}
- (void)userNotificationCenter:(UNUserNotificationCenter *)center openSettingsForNotification:(UNNotification *)notification {
    id<UNUserNotificationCenterDelegate> previous = self.previous;
    if ([previous respondsToSelector:@selector(userNotificationCenter:openSettingsForNotification:)]) {
        [previous userNotificationCenter:center openSettingsForNotification:notification];
    }
}
@end
