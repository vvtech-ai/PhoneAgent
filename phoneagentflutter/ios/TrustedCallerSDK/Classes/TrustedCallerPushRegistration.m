#import "TrustedCallerPushRegistration.h"
#import "TrustedCallerPushBindingDriver.h"
#import "TrustedCallerSdkClient.h"
#import "TrustedCallerSDKAvailability.h"
#import <UIKit/UIKit.h>
#import "TrustedCallerIncomingDiagnostics.h"
#import <UserNotifications/UserNotifications.h>

@interface TrustedCallerPushRegistration ()
@property(nonatomic, strong) TrustedCallerPushBindingDriver *driver;
@property(nonatomic, copy, nullable) NSDictionary *owner;
@property(nonatomic, copy, nullable) NSString *deviceToken;
@property(nonatomic) NSUInteger consumer;
@property(nonatomic) NSUInteger notificationGeneration;
@property(nonatomic) BOOL notificationAllowed;
@property(nonatomic) BOOL startupAuthorizationRequested;
@property(nonatomic) BOOL awaitingRegistrationCallback;
@property(nonatomic) NSUInteger callbackObservationGeneration;
@property(nonatomic, copy) NSString *lastBindingGate;
@end
@implementation TrustedCallerPushRegistration
+ (instancetype)sharedRegistration {
    static TrustedCallerPushRegistration *registration;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ registration = [TrustedCallerPushRegistration new]; });
    return registration;
}
- (instancetype)init {
    if ((self = [super init])) {
        _driver = [[TrustedCallerPushBindingDriver alloc]
            initWithBootstrap:^(void (^completion)(BOOL)) {
                [TrustedCallerSdkClient.sharedClient initializeWithCompletion:completion];
            } action:^(NSDictionary *action, void (^completion)(BOOL)) {
                [TrustedCallerSdkClient.sharedClient performPushBindingAction:action completion:completion];
            }];
        [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(becameActive:)
            name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}
- (void)requestStartupAuthorization {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self requestStartupAuthorization]; });
        return;
    }
    if (self.startupAuthorizationRequested) return;
    self.startupAuthorizationRequested = YES;
    [UNUserNotificationCenter.currentNotificationCenter
        requestAuthorizationWithOptions:UNAuthorizationOptionAlert | UNAuthorizationOptionBadge | UNAuthorizationOptionSound
        completionHandler:^(BOOL granted, NSError *error) {
            dispatch_async(dispatch_get_main_queue(), ^{ [self synchronizeNotifications]; });
        }];
}
- (NSUInteger)attachConsumer {
    NSAssert(NSThread.isMainThread, @"Account consumer must attach on main thread");
    self.consumer++;
    self.owner = nil;
    [self apply];
    return self.consumer;
}
- (BOOL)isCurrentConsumer:(NSUInteger)consumer { return consumer == self.consumer; }
- (void)updateOwner:(NSDictionary *)owner consumer:(NSUInteger)consumer {
    if (consumer != self.consumer) return;
    if (![self.owner isEqual:owner]) self.notificationAllowed = NO;
    self.owner = owner.copy;
    [self apply];
    [self synchronizeNotifications];
}
- (void)detachConsumer:(NSUInteger)consumer {
    if (consumer != self.consumer) return;
    self.consumer++;
    self.notificationGeneration++;
    self.owner = nil;
    [self apply];
}
- (void)recordBindingSnapshotForConsumer:(NSUInteger)consumer {
    NSAssert(NSThread.isMainThread, @"Binding diagnostics must be read on main thread");
    if (consumer != self.consumer) return;
    NSString *code = !self.owner ? @"IOS_BIND_WAIT_OWNER" :
        !self.notificationAllowed ? @"IOS_BIND_WAIT_PERMISSION" :
        !self.deviceToken ? @"IOS_BIND_WAIT_TOKEN" : self.driver.diagnosticCode;
    // A snapshot is evidence of local acknowledgement, not a fresh server query or delivery receipt.
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding" code:code result:@"received"];
}
- (void)retryForOwner:(NSDictionary *)owner {
    if (!self.owner || !self.driver.needsRetry) return;
    for (NSString *key in @[@"accountId", @"phone", @"loginEpoch", @"environment"]) {
        if (![self.owner[key] isEqual:owner[key]]) return;
    }
    [self.driver retry];
}
- (void)receivedDeviceToken:(NSData *)token {
    if (!NSThread.isMainThread) {
        NSData *frozen = token.copy;
        dispatch_async(dispatch_get_main_queue(), ^{ [self receivedDeviceToken:frozen]; });
        return;
    }
    self.awaitingRegistrationCallback = NO;
    self.callbackObservationGeneration++;
    [self recordRegistration:@"IOS_APNS_TOKEN_CALLBACK" result:@"received"];
    if (![token isKindOfClass:NSData.class] || token.length != 32) {
        [self recordRegistration:@"IOS_APNS_TOKEN_REJECTED" result:@"failed"];
        return;
    }
    const unsigned char *bytes = token.bytes;
    NSMutableString *hex = [NSMutableString stringWithCapacity:64];
    for (NSUInteger index = 0; index < token.length; index++) [hex appendFormat:@"%02x", bytes[index]];
    self.deviceToken = hex.copy;
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushRegistration" code:@"IOS_APNS_TOKEN_RECEIVED" result:@"succeeded"];
    [self apply];
}
- (void)becameActive:(NSNotification *)notification { [self synchronizeNotifications]; }
- (void)synchronizeNotifications {
    NSUInteger generation = ++self.notificationGeneration;
    [UNUserNotificationCenter.currentNotificationCenter getNotificationSettingsWithCompletionHandler:
        ^(UNNotificationSettings *settings) {
        dispatch_async(dispatch_get_main_queue(), ^{
            if (generation != self.notificationGeneration) return;
            UNAuthorizationStatus status = settings.authorizationStatus;
            self.notificationAllowed = status == UNAuthorizationStatusAuthorized ||
                status == UNAuthorizationStatusProvisional || status == UNAuthorizationStatusEphemeral;
            [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushRegistration"
                code:self.notificationAllowed ? @"IOS_APNS_ALLOWED" : @"IOS_APNS_DENIED"
                result:self.notificationAllowed ? @"succeeded" : @"failed"];
            [self apply];
            [self recordBindingSnapshotForConsumer:self.consumer];
            // Read existing user permission only; never prompt from account synchronization.
            if (!self.notificationAllowed) return;
            id environment = [NSBundle.mainBundle objectForInfoDictionaryKey:@"TrustedCallerAPNSEnvironment"];
            if (!environment) {
                [self recordRegistration:@"IOS_APNS_CONFIG_MISSING" result:@"failed"];
                return;
            }
            // APNs follows signing, independently of the business/SDK environment.
            // Final artifact verification checks the plist, entitlement and profile together.
            BOOL valid = [environment isKindOfClass:NSString.class] &&
                ([environment isEqual:@"development"] || [environment isEqual:@"production"]);
            if (!valid) {
                [self recordRegistration:@"IOS_APNS_CONFIG_MISMATCH" result:@"failed"];
                return;
            }
            [self observeRegistrationCallback];
            [self recordRegistration:@"IOS_APNS_REGISTER_REQUESTED" result:@"started"];
            [UIApplication.sharedApplication registerForRemoteNotifications];
            [self recordRegistration:@"IOS_APNS_REGISTER_RETURNED" result:@"received"];
        });
    }];
}
- (void)receivedRegistrationError:(NSError *)error {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self receivedRegistrationError:error]; });
        return;
    }
    self.awaitingRegistrationCallback = NO;
    self.callbackObservationGeneration++;
    [TrustedCallerIncomingDiagnostics.shared recordAPNSRegistrationError:error];
}
- (void)recordRegistration:(NSString *)code result:(NSString *)result {
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushRegistration" code:code result:result];
}
- (void)observeRegistrationCallback {
    if (self.awaitingRegistrationCallback) return;
    self.awaitingRegistrationCallback = YES;
    NSUInteger generation = ++self.callbackObservationGeneration;
    __weak typeof(self) weakSelf = self;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 20 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        typeof(self) strongSelf = weakSelf;
        if (!strongSelf || !strongSelf.awaitingRegistrationCallback ||
            generation != strongSelf.callbackObservationGeneration) return;
        // Observation only: do not retry, invalidate the token or declare registration failure.
        strongSelf.awaitingRegistrationCallback = NO;
        [strongSelf recordRegistration:@"IOS_APNS_CALLBACK_PENDING" result:@"received"];
    });
}
- (void)apply {
    NSString *gate = !self.owner ? @"IOS_BIND_WAIT_OWNER" :
        !self.notificationAllowed ? @"IOS_BIND_WAIT_PERMISSION" :
        !self.deviceToken ? @"IOS_BIND_WAIT_TOKEN" : @"";
    if (![gate isEqual:self.lastBindingGate]) {
        self.lastBindingGate = gate;
        if (gate.length) [TrustedCallerIncomingDiagnostics.shared
            recordStage:@"pushBinding" code:gate result:@"received"];
    }
    [self.driver updateOwner:self.owner deviceToken:self.deviceToken notificationAllowed:self.notificationAllowed];
}
- (void)dealloc { [NSNotificationCenter.defaultCenter removeObserver:self]; }
@end
