#import "TrustedCallerAuthorizationEvidence.h"

@implementation TrustedCallerAuthorizationEvidence
+ (NSDictionary<NSString *, id> *)reportForCode:(NSInteger)code data:(id)data {
    if (code != 1) return @{@"status": @"unavailable", @"explicitSdkAuthorization": @NO};
    NSDictionary *payload = [data isKindOfClass:NSDictionary.class] ? data : @{};
    NSNumber *confirmed = nil;
    BOOL invalid = NO;
    for (NSString *key in @[@"authorized", @"isAuthorized", @"authStatus"]) {
        id raw = payload[key];
        if (!raw) continue;
        NSNumber *value = nil;
        if ([raw isKindOfClass:NSNumber.class]) {
            if ([raw isEqual:@0]) value = @NO;
            else if ([raw isEqual:@1]) value = @YES;
        } else if ([raw isKindOfClass:NSString.class]) {
            NSString *normalized = [[raw stringByTrimmingCharactersInSet:
                NSCharacterSet.whitespaceAndNewlineCharacterSet] lowercaseString];
            if ([@[@"1", @"true", @"yes"] containsObject:normalized]) value = @YES;
            else if ([@[@"0", @"false", @"no"] containsObject:normalized]) value = @NO;
        }
        if (!value || (confirmed && ![confirmed isEqual:value])) invalid = YES;
        if (value) confirmed = value;
    }
    if (!confirmed || invalid) return @{@"status": @"readyToConfigure", @"explicitSdkAuthorization": @NO};
    return @{@"status": confirmed.boolValue ? @"authorized" : @"notAuthorized",
             @"explicitSdkAuthorization": @YES};
}
@end
