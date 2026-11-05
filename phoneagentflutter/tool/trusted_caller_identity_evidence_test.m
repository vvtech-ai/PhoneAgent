#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIdentityEvidence.h"
int main(void) {
 @autoreleasepool {
    NSDictionary *incoming = @{@"token":@"synthetic-opaque", @"phoneno":@"12025550100", @"targetNumber":@"13800000000",
        @"sequence":@"synthetic-sequence", @"name":@"unverified-preview"};
    TrustedCallerIncomingPayload *payload = [TrustedCallerIncomingPayload payloadFromUserInfo:incoming currentPhone:@"13800000000" now:1700000000];
    NSDictionary *raw = @{@"name":@"verified-synthetic", @"phoneno":@"override", @"sequence":@"override",
        @"verification":@"verified", @"token":@"sensitive", @"avatarUrl":@"https://synthetic.invalid", @"appSecret":@"synthetic-secret"};
    NSDictionary *failed = [TrustedCallerIdentityEvidence reportForCode:0 data:raw payload:payload];
    NSCAssert([failed[@"verification"] isEqual:@"failed"] && [failed[@"name"] isEqual:@"unverified-preview"], @"Failure retains preview and never uses claimed SDK fields as verified");
    for (id invalid in @[NSNull.null, @"not-a-dictionary", @{@"data":NSNull.null}]) {
        NSCAssert([[TrustedCallerIdentityEvidence reportForCode:1 data:invalid payload:payload][@"verification"] isEqual:@"failed"], @"Malformed response cannot verify");
    }
    NSDictionary *verified = [TrustedCallerIdentityEvidence reportForCode:1 data:@{@"data":raw} payload:payload];
    NSCAssert([verified[@"verification"] isEqual:@"verified"] && [verified[@"name"] isEqual:@"verified-synthetic"], @"Explicit success accepts whitelisted identity");
    NSCAssert([verified[@"phoneno"] isEqual:@"12025550100"] && [verified[@"sequence"] isEqual:@"synthetic-sequence"], @"SDK cannot override frozen event");
    NSCAssert(verified[@"token"] == nil && verified[@"appSecret"] == nil && verified[@"avatarUrl"] == nil && verified[@"data"] == nil, @"No secrets/raw envelope/links in display projection");
    NSDictionary *unknown = [TrustedCallerIdentityEvidence reportForCode:1 data:@{} payload:payload];
    NSCAssert(unknown[@"name"] == nil, @"No unverified preview fallback after validation");
    NSDictionary *uncertified = [TrustedCallerIdentityEvidence reportForCode:1 data:@{@"showType":@6} payload:payload];
    NSCAssert([uncertified[@"verification"] isEqual:@"uncertified"], @"Type six must not display certified identity");
    NSDictionary *malformedFields = [TrustedCallerIdentityEvidence reportForCode:1 data:@{@"name":@YES, @"title":@"control\ninside", @"caName":@[@"nested"]} payload:payload];
    NSCAssert(malformedFields[@"name"] == nil && malformedFields[@"title"] == nil && malformedFields[@"caName"] == nil, @"Invalid display values dropped");
    puts("Foundation SDK identity evidence failure/whitelist/frozen event/uncertified cases passed; no SDK initialized.");
 }
 return 0;
}
