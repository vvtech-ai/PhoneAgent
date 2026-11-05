// Executes production registration logic with in-memory OS/SDK substitutes; no APNs or SDK access.
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import "TrustedCallerIncomingDiagnostics.h"
#import "TrustedCallerSdkClient.h"
#import "TrustedCallerSDKAvailability.h"
static NSMutableArray *timers, *events;
static NSUInteger registrations, bootstraps, bindings;
static id configuredEnvironment = @"development";
static UNAuthorizationStatus authorization = UNAuthorizationStatusAuthorized;
static void ObserveAfter(dispatch_time_t when, dispatch_queue_t queue, dispatch_block_t block) {
    [timers addObject:[block copy]];
}
#define dispatch_after ObserveAfter
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerPushRegistration.m"
#undef dispatch_after
NSString * const UIApplicationDidBecomeActiveNotification = @"TestActive";
@implementation UIApplication
+ (instancetype)sharedApplication { static id app; if (!app) app = [self new]; return app; }
- (void)registerForRemoteNotifications { registrations++; }
@end
@implementation UNNotificationSettings
@end
@implementation UNUserNotificationCenter
+ (instancetype)currentNotificationCenter { static id center; if (!center) center = [self new]; return center; }
- (void)requestAuthorizationWithOptions:(NSUInteger)options completionHandler:(void (^)(BOOL, NSError *))handler {
    handler(YES, nil);
}
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))handler {
    UNNotificationSettings *settings = [UNNotificationSettings new];
    settings.authorizationStatus = authorization;
    handler(settings);
}
@end
@implementation TrustedCallerSDKAvailability
+ (NSString *)sdkEnvironment { return @"test"; }
@end
@implementation TrustedCallerSdkClient
+ (instancetype)sharedClient { static id client; if (!client) client = [self new]; return client; }
- (void)initializeWithCompletion:(void (^)(BOOL))completion { bootstraps++; completion(YES); }
- (void)performPushBindingAction:(NSDictionary *)action completion:(void (^)(BOOL))completion {
    bindings++; completion(YES);
}
@end
static id Environment(id object, SEL selector, NSString *key) { return configuredEnvironment; }
static NSUInteger Count(NSString *code) {
    NSUInteger count = 0;
    for (NSDictionary *event in events) if ([event[@"diagnostic"][@"code"] isEqual:code]) count++;
    return count;
}
static void Drain(void) {
    // Let the real dispatch-to-main settings callbacks execute.
    NSDate *deadline = [NSDate dateWithTimeIntervalSinceNow:0.02];
    while (deadline.timeIntervalSinceNow > 0) [NSRunLoop.currentRunLoop runUntilDate:deadline];
}
int main(void) { @autoreleasepool {
    timers = [NSMutableArray new]; events = [NSMutableArray new];
    class_replaceMethod(NSBundle.class, @selector(objectForInfoDictionaryKey:), (IMP)Environment, "@@:@");
    [TrustedCallerIncomingDiagnostics.shared attachConsumer:1];
    [TrustedCallerIncomingDiagnostics.shared listen:^(NSDictionary *e) { [events addObject:e]; } consumer:1];
    TrustedCallerPushRegistration *registration = [TrustedCallerPushRegistration new];
    NSUInteger consumer = [registration attachConsumer];
    [registration synchronizeNotifications]; Drain();
    NSCAssert(registrations == 1 && Count(@"IOS_APNS_REGISTER_REQUESTED") == 1 &&
        Count(@"IOS_APNS_REGISTER_RETURNED") == 1, @"Actual invocation must be observable");
    [registration synchronizeNotifications]; Drain();
    NSCAssert(timers.count == 1 && registrations == 2, @"Observation must coalesce, not change registration");
    ((dispatch_block_t)timers[0])(); ((dispatch_block_t)timers[0])();
    NSCAssert(Count(@"IOS_APNS_CALLBACK_PENDING") == 1 && registrations == 2, @"Observation cannot retry");
    [registration synchronizeNotifications]; Drain();
    [registration receivedRegistrationError:[NSError errorWithDomain:NSCocoaErrorDomain code:3000 userInfo:nil]];
    ((dispatch_block_t)timers.lastObject)();
    NSCAssert(Count(@"IOS_APNS_REGISTRATION_FAILED") == 1 && Count(@"IOS_APNS_CALLBACK_PENDING") == 1,
        @"Failure callback must end the current wait");
    configuredEnvironment = nil; [registration synchronizeNotifications]; Drain();
    NSCAssert(Count(@"IOS_APNS_CONFIG_MISSING") == 1 && registrations == 3, @"Missing config must remain blocked");
    configuredEnvironment = @"production"; [registration synchronizeNotifications]; Drain();
    NSCAssert(Count(@"IOS_APNS_CONFIG_MISMATCH") == 0 && registrations == 4,
        @"APNs production is independent of the test SDK; signed delivery policy is checked separately");
    for (id invalid in @[@"test", @42]) {
        configuredEnvironment = invalid; [registration synchronizeNotifications]; Drain();
    }
    NSCAssert(Count(@"IOS_APNS_CONFIG_MISMATCH") == 2 && registrations == 4,
        @"Unknown APNs names and non-string values must remain blocked");
    configuredEnvironment = @"development";
    NSDictionary *owner = @{@"accountId":@"synthetic", @"phone":@"13800138000", @"loginEpoch":@1, @"environment":@"test"};
    [registration updateOwner:owner consumer:consumer]; Drain();
    NSCAssert(Count(@"IOS_BIND_WAIT_TOKEN") >= 1 && bootstraps == 0, @"Token is required before SDK bootstrap");
    [registration receivedDeviceToken:[NSMutableData dataWithLength:31]];
    NSCAssert(Count(@"IOS_APNS_TOKEN_REJECTED") == 1 && !registration.deviceToken && bootstraps == 0,
        @"Invalid token must be observed without changing existing validation");
    [registration synchronizeNotifications]; Drain();
    dispatch_block_t oldTimer = timers.lastObject;
    [registration receivedDeviceToken:[NSMutableData dataWithLength:32]];
    oldTimer();
    NSCAssert(Count(@"IOS_APNS_TOKEN_CALLBACK") == 2 && Count(@"IOS_APNS_TOKEN_RECEIVED") == 1 &&
        bootstraps == 1 && bindings == 1 && Count(@"IOS_APNS_CALLBACK_PENDING") == 1,
        @"Valid callback must bind once and cancel its observation");
    [registration synchronizeNotifications]; Drain();
    oldTimer();
    NSCAssert(Count(@"IOS_APNS_CALLBACK_PENDING") == 1, @"Old observer must not affect a new wait");
    ((dispatch_block_t)timers.lastObject)();
    NSCAssert(Count(@"IOS_APNS_CALLBACK_PENDING") == 2, @"New wait has independent identity");
    NSUInteger bindingsBeforeSnapshot = bindings;
    [registration recordBindingSnapshotForConsumer:consumer];
    NSCAssert(Count(@"IOS_BIND_STATE_CONFIRMED") > 0 && bindings == bindingsBeforeSnapshot,
        @"Late listener can observe current acknowledgement without rebinding");
    NSUInteger snapshots = events.count;
    [registration recordBindingSnapshotForConsumer:consumer + 1];
    NSCAssert(events.count == snapshots, @"Stale consumer cannot observe binding state");
    [registration detachConsumer:consumer];
    NSUInteger before = registrations;
    [registration updateOwner:owner consumer:consumer]; Drain();
    NSCAssert(registrations == before && bindings == 2, @"Stale consumer must stay isolated; logout unbind remains");
    authorization = UNAuthorizationStatusDenied;
    [registration synchronizeNotifications]; Drain();
    NSCAssert(registrations == before && Count(@"IOS_APNS_DENIED") == 1, @"Denied permission cannot register");
    NSCAssert(Count(@"IOS_SDK_INIT_STARTED") == 1 && Count(@"IOS_SDK_INIT_SUCCEEDED") == 1,
        @"SDK bootstrap must be independently observable");
    TrustedCallerPushBindingDriver *failed = [[TrustedCallerPushBindingDriver alloc]
        initWithBootstrap:^(void (^completion)(BOOL)) { completion(NO); }
        action:^(NSDictionary *action, void (^completion)(BOOL)) { NSCAssert(NO, @"Failed init cannot bind"); }];
    [failed updateOwner:owner deviceToken:registration.deviceToken notificationAllowed:YES];
    [failed updateOwner:owner deviceToken:registration.deviceToken notificationAllowed:YES];
    NSCAssert(failed.needsRetry && Count(@"IOS_SDK_INIT_FAILED") == 1 && Count(@"IOS_BIND_WAIT_RETRY") == 1,
        @"SDK failure must be observable without automatic retry");
    NSCAssert([failed.diagnosticCode isEqual:@"IOS_BIND_STATE_INIT_FAILED"], @"Initialization failure is not binding success");
    for (NSDictionary *event in events) NSCAssert([event[@"diagnostic"] count] <= 6, @"Only safe bounded metadata");
    puts("push registration diagnostics passed");
} return 0; }
