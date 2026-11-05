#import "TrustedCallerIncomingPayload.h"
#import "TrustedCallerPhoneNumber.h"
#import <CoreFoundation/CoreFoundation.h>
#import <math.h>
@interface TrustedCallerIncomingPayload ()
@property(nonatomic, copy) NSDictionary *sdkArguments;
@property(nonatomic, copy) NSDictionary *preview;
@property(nonatomic) BOOL activityFresh;
@property(nonatomic, copy) NSString *avatarURL;
@end
@implementation TrustedCallerIncomingPayload
static NSString *Text(id raw, NSUInteger limit) {
    NSString *value;
    if ([raw isKindOfClass:NSString.class]) value = raw;
    else if ([raw isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)raw) != CFBooleanGetTypeID()) value = [raw stringValue];
    else return @"";
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length > limit || [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return @"";
    return value.copy;
}
static NSTimeInterval Milliseconds(id raw) {
    NSString *text = Text(raw, 20);
    if (text.length == 0 || [text rangeOfCharacterFromSet:
        [[NSCharacterSet characterSetWithCharactersInString:@"0123456789"] invertedSet]].location != NSNotFound) return NAN;
    double number = text.doubleValue;
    if (!isfinite(number) || number <= 0) return NAN;
    return number / 1000.0;
}
+ (instancetype)candidateFromUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now {
    if (![userInfo isKindOfClass:NSDictionary.class]) return nil;
    return [self payloadFromUserInfo:userInfo currentPhone:Text(userInfo[@"targetNumber"], 128) now:now];
}
+ (instancetype)payloadFromUserInfo:(NSDictionary *)userInfo currentPhone:(NSString *)currentPhone now:(NSTimeInterval)now {
    if (![userInfo isKindOfClass:NSDictionary.class]) return nil;
    NSString *token = [userInfo[@"token"] isKindOfClass:NSString.class] ? Text(userInfo[@"token"], 16384) : @"";
    NSString *caller = Text(userInfo[@"phoneno"], 128);
    NSString *called = Text(userInfo[@"targetNumber"], 128);
    NSString *sequence = Text(userInfo[@"sequence"], 1024);
    NSString *ownerNumber = TrustedCallerNormalizedPhone(currentPhone);
    if (token.length == 0 || caller.length == 0 || called.length == 0 || sequence.length == 0 ||
        TrustedCallerNormalizedPhone(caller).length == 0 || ownerNumber.length == 0 ||
        ![TrustedCallerNormalizedPhone(called) isEqual:ownerNumber]) return nil;
    TrustedCallerIncomingPayload *payload = [self new];
    payload.sdkArguments = @{@"token":token, @"caller":caller, @"called":called, @"sequence":sequence};
    NSMutableDictionary *preview = [@{@"phoneno":caller, @"targetNumber":called,
        @"sequence":sequence, @"signStaus":@"pending"} mutableCopy];
    for (NSString *key in @[@"name", @"position", @"showType", @"callTime", @"title", @"job", @"school"]) {
        NSString *value = Text(userInfo[key], 1024);
        if (value.length > 0) preview[key] = value;
    }
    NSDictionary *aliases = @{@"dept":@"deptZh", @"companyName":@"commonName"};
    for (NSString *key in aliases) {
        NSString *value = Text(userInfo[key], 1024);
        if (value.length > 0) preview[aliases[key]] = value;
    }
    // Preview is unverified. No avatar URL or identity proof is trusted here.
    payload.preview = preview.copy;
    payload.avatarURL = Text(userInfo[@"picUrl"], 2048);
    NSTimeInterval timestamp = Milliseconds(userInfo[@"callTime"]);
    NSTimeInterval age = now - timestamp;
    payload.activityFresh = isfinite(now) && isfinite(timestamp) && age >= -60 && age <= 20 * 60;
    return payload;
}
@end
