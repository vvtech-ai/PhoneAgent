#import "TrustedCallerIdentityEvidence.h"
#import <CoreFoundation/CoreFoundation.h>
@implementation TrustedCallerIdentityEvidence
static NSString *Field(id raw) {
    NSString *value;
    if ([raw isKindOfClass:NSString.class]) value = raw;
    else if ([raw isKindOfClass:NSNumber.class] && CFGetTypeID((__bridge CFTypeRef)raw) != CFBooleanGetTypeID()) value = [raw stringValue];
    else return @"";
    value = [value stringByTrimmingCharactersInSet:NSCharacterSet.whitespaceAndNewlineCharacterSet];
    if (value.length > 1024 || [value rangeOfCharacterFromSet:NSCharacterSet.controlCharacterSet].location != NSNotFound) return @"";
    return value.copy;
}
+ (NSDictionary *)reportForCode:(NSInteger)code data:(id)data payload:(TrustedCallerIncomingPayload *)payload {
    NSDictionary *verified;
    if ([data isKindOfClass:NSDictionary.class]) {
        id nested = data[@"data"];
        if (nested) verified = [nested isKindOfClass:NSDictionary.class] ? nested : nil;
        else verified = data;
    }
    BOOL success = code == 1 && verified != nil;
    NSMutableDictionary *report = [NSMutableDictionary dictionary];
    if (success) {
        for (NSString *key in @[@"name", @"userName", @"realName", @"title", @"deptZh", @"dept", @"department",
            @"position", @"job", @"jobTitle", @"commonName", @"companyName", @"organizationName", @"school",
            @"showType", @"identityType", @"serialNumber", @"UniqueID", @"createTime", @"complaintTime", @"caName", @"caType"]) {
            NSString *value = Field(verified[key]);
            if (value.length > 0) report[key] = value;
        }
    }
    if (!success) {
        for (NSString *key in @[@"name", @"title", @"deptZh", @"position", @"commonName", @"showType", @"job", @"school"]) {
            NSString *value = Field(payload.preview[key]);
            if (value.length) report[key] = value;
        }
    }
    for (NSString *key in @[@"phoneno", @"targetNumber", @"sequence", @"callTime"]) {
        NSString *value = payload.preview[key];
        if (value) report[key] = value;
    }
    NSString *showType = report[@"showType"] ?: report[@"identityType"];
    report[@"verification"] = !success ? @"failed" : [showType isEqual:@"6"] ? @"uncertified" : @"verified";
    report[@"signStaus"] = success ? @"1" : @"0";
    id avatar = [data isKindOfClass:NSDictionary.class] ? data[@"avatarData"] : nil;
    if ([avatar isKindOfClass:NSData.class] && [avatar length] > 0 && [avatar length] <= 32768) report[@"avatarData"] = avatar;
    // Neither SDK envelope/status overrides nor tokens, links and raw data escape.
    return report.copy;
}
@end
