#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerAuthorizationEvidence.h"

static void expect(NSInteger code, id data, NSString *status, BOOL explicit) {
    NSDictionary *report = [TrustedCallerAuthorizationEvidence reportForCode:code data:data];
    NSCAssert([report[@"status"] isEqual:status], @"Incorrect authorization status");
    NSCAssert([report[@"explicitSdkAuthorization"] boolValue] == explicit, @"Incorrect authorization proof");
    NSCAssert(report.count == 2, @"SDK payload must not escape the evidence boundary");
}

int main(void) {
    @autoreleasepool {
        expect(0, @{@"authorized": @YES}, @"unavailable", NO);
        expect(1, nil, @"readyToConfigure", NO);
        expect(1, @{@"other": @YES}, @"readyToConfigure", NO);
        expect(1, @{@"authorized": @YES}, @"authorized", YES);
        expect(1, @{@"isAuthorized": @0}, @"notAuthorized", YES);
        expect(1, @{@"authStatus": @" YES "}, @"authorized", YES);
        expect(1, @{@"authStatus": @"false"}, @"notAuthorized", YES);
        expect(1, @{@"authorized": @2}, @"readyToConfigure", NO);
        expect(1, @{@"authorized": @"pending"}, @"readyToConfigure", NO);
        expect(1, @{@"authorized": NSNull.null}, @"readyToConfigure", NO);
        expect(1, @{@"authorized": @YES, @"isAuthorized": @NO}, @"readyToConfigure", NO);
        expect(1, @{@"authorized": @YES, @"isAuthorized": @"true"}, @"authorized", YES);
        puts("12 Foundation SDK authorization evidence cases passed; no SDK initialized.");
    }
    return 0;
}
