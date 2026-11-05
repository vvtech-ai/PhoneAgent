#import "TrustedCallerPushBindingState.h"
#import <CoreFoundation/CoreFoundation.h>

@interface TrustedCallerPushBindingState ()
@property(nonatomic, strong, nullable) NSDictionary *desired;
@property(nonatomic, strong, nullable) NSDictionary *confirmed;
@property(nonatomic, strong, nullable) NSDictionary *pending;
@property(nonatomic) BOOL needsRetry;
@property(nonatomic) BOOL sdkReady;
@property(nonatomic) BOOL cleanupRequired;
@end

@implementation TrustedCallerPushBindingState
static BOOL ValidText(id value) {
    return [value isKindOfClass:NSString.class] &&
        [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet].length > 0 &&
        [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location == NSNotFound;
}
static NSDictionary *FrozenBinding(NSDictionary *owner, NSString *token) {
    if (![owner isKindOfClass:NSDictionary.class] || ![token isKindOfClass:NSString.class]) return nil;
    id account = owner[@"accountId"], phone = owner[@"phone"], epoch = owner[@"loginEpoch"], environment = owner[@"environment"];
    if (!ValidText(account) || !ValidText(phone) ||
        ![epoch isKindOfClass:NSNumber.class] || CFGetTypeID((__bridge CFTypeRef)epoch) == CFBooleanGetTypeID() ||
        strchr("cislqCISLQ", [epoch objCType][0]) == NULL || [epoch longLongValue] < 0 ||
        !([environment isEqual:@"test"] || [environment isEqual:@"pro"])) return nil;
    NSString *normalized = token.lowercaseString;
    NSCharacterSet *nonHex = [[NSCharacterSet characterSetWithCharactersInString:@"0123456789abcdef"] invertedSet];
    if (normalized.length != 64 || [normalized rangeOfCharacterFromSet:nonHex].location != NSNotFound) return nil;
    return @{@"accountId": [account copy], @"phone": [phone copy], @"loginEpoch": epoch,
        @"environment": [environment copy], @"deviceToken": [normalized copy]};
}
- (void)updateOwner:(NSDictionary *)owner deviceToken:(NSString *)deviceToken
    notificationAllowed:(BOOL)notificationAllowed sdkReady:(BOOL)sdkReady {
    NSAssert(NSThread.isMainThread, @"Account binding must be serialized on main thread");
    self.sdkReady = sdkReady;
    self.desired = notificationAllowed ? FrozenBinding(owner, deviceToken) : nil;
}
- (NSString *)diagnosticCode {
    NSAssert(NSThread.isMainThread, @"Binding diagnostics must be read on main thread");
    if (self.needsRetry) return @"IOS_BIND_STATE_UNCERTAIN";
    if (self.pending) return @"IOS_BIND_STATE_PENDING";
    if (self.desired && [self.confirmed isEqual:self.desired] && !self.cleanupRequired)
        return @"IOS_BIND_STATE_CONFIRMED";
    return @"IOS_BIND_STATE_UNCONFIRMED";
}
- (BOOL)hasWork { return self.desired != nil || self.confirmed != nil || self.pending != nil; }
- (NSDictionary *)nextAction {
    NSAssert(NSThread.isMainThread, @"Account binding must be serialized on main thread");
    if (!self.sdkReady || self.pending || self.needsRetry) return nil;
    NSString *operation;
    NSDictionary *binding;
    if (self.confirmed && (self.cleanupRequired || ![self.confirmed isEqual:self.desired])) {
        operation = @"unbind";
        binding = self.confirmed;
    } else if (!self.confirmed && self.desired) {
        operation = @"bind";
        binding = self.desired;
    } else {
        return nil;
    }
    self.pending = @{@"operation": operation, @"binding": binding,
        @"requestId": NSUUID.UUID.UUIDString};
    return self.pending;
}
- (void)completeRequest:(NSString *)requestId success:(BOOL)success {
    NSAssert(NSThread.isMainThread, @"Account binding must be serialized on main thread");
    if (![requestId isKindOfClass:NSString.class] ||
        ![self.pending[@"requestId"] isEqual:requestId]) return;
    NSDictionary *action = self.pending;
    self.pending = nil;
    BOOL binding = [action[@"operation"] isEqual:@"bind"];
    if (!success) {
        // A transport failure cannot prove the remote bind did not happen.
        if (binding) self.confirmed = action[@"binding"];
        self.cleanupRequired = YES;
        self.needsRetry = YES;
        return;
    }
    self.confirmed = binding ? action[@"binding"] : nil;
    self.cleanupRequired = NO;
}
- (void)retry {
    NSAssert(NSThread.isMainThread, @"Account binding must be serialized on main thread");
    self.needsRetry = NO;
}
@end
