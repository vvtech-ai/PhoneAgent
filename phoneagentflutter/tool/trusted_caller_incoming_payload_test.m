#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingPayload.h"
int main(void) {
 @autoreleasepool {
    NSMutableString *token = [@"synthetic-opaque-token" mutableCopy];
    NSMutableDictionary *info = [@{@"token":token, @"phoneno":@"12025550100", @"targetNumber":@"+86 13800000000",
        @"sequence":@"synthetic-sequence", @"callTime":@1700000000000,
        @"name":@"合成来电身份", @"companyName":@"合成企业", @"signStaus":@"1",
        @"authorized":@YES, @"picUrl":@"https://synthetic.invalid/private"} mutableCopy];
    TrustedCallerIncomingPayload *payload = [TrustedCallerIncomingPayload payloadFromUserInfo:info currentPhone:@"13800000000" now:1700000000];
    NSCAssert(payload && payload.activityFresh, @"Valid exact payload accepted");
    [token appendString:@"mutated"];
    NSCAssert([payload.sdkArguments[@"token"] isEqual:@"synthetic-opaque-token"], @"Mutable token must freeze");
    NSCAssert(payload.preview[@"token"] == nil && payload.preview[@"authorized"] == nil &&
        payload.preview[@"picUrl"] == nil && [payload.preview[@"signStaus"] isEqual:@"pending"], @"Preview cannot leak token or claim verification");
    for (NSString *key in @[@"token", @"phoneno", @"targetNumber", @"sequence"]) {
        NSMutableDictionary *missing = info.mutableCopy; [missing removeObjectForKey:key];
        NSCAssert([TrustedCallerIncomingPayload payloadFromUserInfo:missing currentPhone:@"13800000000" now:1700000000] == nil, @"Every exact required field mandatory");
    }
    NSCAssert([TrustedCallerIncomingPayload payloadFromUserInfo:info currentPhone:@"13900000000" now:1700000000] == nil, @"Other called account refused");
    NSCAssert([TrustedCallerIncomingPayload payloadFromUserInfo:@{@"data":info} currentPhone:@"13800000000" now:1700000000] == nil, @"Do not guess nested payload");
    for (id invalid in @[@YES, @42, @"inside\ncontrol", [@"a" stringByPaddingToLength:16385 withString:@"a" startingAtIndex:0]]) {
        NSMutableDictionary *bad = info.mutableCopy; bad[@"token"] = invalid;
        NSCAssert([TrustedCallerIncomingPayload payloadFromUserInfo:bad currentPhone:@"13800000000" now:1700000000] == nil, @"Opaque token type/control/size refused");
    }
    for (id timestamp in @[@0, @YES, @"invalid", @1699998799000, @1700000061000]) {
        info[@"callTime"] = timestamp;
        TrustedCallerIncomingPayload *stale = [TrustedCallerIncomingPayload payloadFromUserInfo:info currentPhone:@"13800000000" now:1700000000];
        NSCAssert(stale && !stale.activityFresh, @"Unknown/stale/future time must not create activity");
    }
    for (NSNumber *timestamp in @[@1699998800000, @1700000060000]) {
        info[@"callTime"] = timestamp;
        NSCAssert([TrustedCallerIncomingPayload payloadFromUserInfo:info currentPhone:@"13800000000" now:1700000000].activityFresh, @"Inclusive twenty-minute/skew boundary");
    }
    puts("Foundation incoming exact fields, called owner, token freeze/whitelist and freshness boundaries passed; no SDK request.");
 }
 return 0;
}
