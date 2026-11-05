#import "TrustedCallerIncomingDiagnostics.h"
#import <os/log.h>
#import <stdint.h>
@interface TrustedCallerIncomingDiagnostics ()
@property(nonatomic) NSUInteger consumer;
@property(nonatomic, copy) void (^sink)(NSDictionary *);
@property(nonatomic, strong) NSMutableArray<NSDictionary *> *pending;
@end
@implementation TrustedCallerIncomingDiagnostics
+ (instancetype)shared {
    static TrustedCallerIncomingDiagnostics *value;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ value = [self new]; });
    return value;
}
- (instancetype)init { if ((self = [super init])) _pending = [NSMutableArray array]; return self; }
- (void)attachConsumer:(NSUInteger)consumer {
    if (consumer <= self.consumer) return;
    self.consumer = consumer; self.sink = nil; [self.pending removeAllObjects];
}
- (void)listen:(void (^)(NSDictionary *))sink consumer:(NSUInteger)consumer {
    if (consumer != self.consumer) return;
    self.sink = sink;
    NSArray *buffer = self.pending.copy;
    if (sink) [self.pending removeAllObjects];
    for (NSDictionary *event in buffer) {
        if (consumer != self.consumer || !self.sink) break;
        self.sink(event);
    }
}
- (void)recordAPNSRegistrationError:(NSError *)error {
    [self recordStage:@"pushRegistration" code:@"IOS_APNS_REGISTRATION_FAILED" result:@"failed" apnsError:error];
}
- (void)recordStage:(NSString *)stage code:(NSString *)code result:(NSString *)result {
    [self recordStage:stage code:code result:result apnsError:nil];
}
- (void)recordStage:(NSString *)stage code:(NSString *)code result:(NSString *)result apnsError:(NSError *)error {
    NSArray *stages = @[@"incomingReceive", @"incomingPayload", @"incomingCache", @"incomingVerify",
        @"incomingDelivery", @"incomingActivity", @"incomingAvatar", @"pushRegistration", @"pushBinding"];
    NSArray *codes = @[@"IOS_PUSH_FOREGROUND", @"IOS_PUSH_BACKGROUND", @"IOS_PUSH_CLICK", @"IOS_PUSH_COLD",
        @"IOS_PAYLOAD_ACCEPTED", @"IOS_PAYLOAD_REJECTED", @"IOS_OWNER_MISSING", @"IOS_OWNER_STALE",
        @"IOS_CACHE_STORED", @"IOS_CACHE_RECOVERED", @"IOS_CACHE_EXPIRED", @"IOS_CACHE_REJECTED",
        @"IOS_VERIFY_STARTED", @"IOS_VERIFY_SUCCEEDED", @"IOS_VERIFY_FAILED", @"IOS_VERIFY_UNCERTIFIED",
        @"IOS_EVENT_PUBLISHED", @"IOS_EVENT_CLEARED", @"IOS_EVENT_DUPLICATE", @"IOS_EVENT_REOPENED",
        @"IOS_ACTIVITY_STARTED", @"IOS_ACTIVITY_UPDATED", @"IOS_ACTIVITY_ENDED", @"IOS_ACTIVITY_FAILED",
        @"IOS_ACTIVITY_DISABLED", @"IOS_ACTIVITY_BACKGROUND_DEFERRED", @"IOS_ACTIVITY_RETRY_EXHAUSTED",
        @"IOS_ACTIVITY_INELIGIBLE", @"IOS_ACTIVITY_SIZE_REJECTED",
        @"IOS_AVATAR_SUCCEEDED", @"IOS_AVATAR_FALLBACK", @"IOS_APNS_ALLOWED", @"IOS_APNS_DENIED",
        @"IOS_APNS_TOKEN_RECEIVED", @"IOS_APNS_REGISTRATION_FAILED",
        @"IOS_APNS_CONFIG_MISSING", @"IOS_APNS_CONFIG_MISMATCH", @"IOS_APNS_REGISTER_REQUESTED", @"IOS_APNS_REGISTER_RETURNED", @"IOS_APNS_CALLBACK_PENDING", @"IOS_APNS_TOKEN_CALLBACK", @"IOS_APNS_TOKEN_REJECTED", @"IOS_BIND_WAIT_OWNER", @"IOS_BIND_WAIT_PERMISSION", @"IOS_BIND_WAIT_TOKEN", @"IOS_SDK_INIT_STARTED", @"IOS_SDK_INIT_SUCCEEDED", @"IOS_SDK_INIT_FAILED", @"IOS_BIND_WAIT_RETRY", @"IOS_BIND_STARTED",
        @"IOS_BIND_STATE_CONFIRMED", @"IOS_BIND_STATE_PENDING", @"IOS_BIND_STATE_UNCERTAIN", @"IOS_BIND_STATE_UNCONFIRMED", @"IOS_BIND_STATE_INIT_FAILED", @"IOS_BIND_STATE_INITIALIZING", @"IOS_BIND_SUCCEEDED", @"IOS_BIND_FAILED", @"IOS_UNBIND_STARTED", @"IOS_UNBIND_SUCCEEDED", @"IOS_UNBIND_FAILED"];
    if (![stages containsObject:stage] || ![codes containsObject:code] ||
        ![@[@"started", @"succeeded", @"failed", @"received", @"cancelled"] containsObject:result]) return;
    os_log_info(OS_LOG_DEFAULT, "TrustedIncoming stage=%{public}@ code=%{public}@ result=%{public}@", stage, code, result);
    NSMutableDictionary *metadata = [@{@"stage":stage, @"code":code, @"result":result,
        @"timeMs":@((long long)(NSDate.date.timeIntervalSince1970 * 1000))} mutableCopy];
    if (error) {
        NSArray *domains = @[NSCocoaErrorDomain, NSURLErrorDomain, NSPOSIXErrorDomain];
        metadata[@"errorDomain"] = [domains containsObject:error.domain] ? error.domain : @"other";
        if (error.code >= INT32_MIN && error.code <= INT32_MAX) metadata[@"errorCode"] = @(error.code);
    }
    NSDictionary *event = @{@"diagnostic":metadata.copy};
    if (self.sink) self.sink(event);
    else { if (self.pending.count >= 64) [self.pending removeObjectAtIndex:0]; [self.pending addObject:event]; }
}
@end
