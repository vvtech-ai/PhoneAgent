#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIdentityLink.h"
int main(void) {
 @autoreleasepool {
    NSString *event = @"aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee";
    NSString *valid = [@"aiassistanttrustedcall://identity?eventId=" stringByAppendingString:event];
    NSCAssert([TrustedCallerEventIdFromURL([NSURL URLWithString:valid]) isEqual:event], @"Exact current event reference accepted");
    NSArray *invalid = @[
        @"https://identity", @"aiassistanttrustedcall://other", @"aiassistanttrustedcall://identity/",
        @"aiassistanttrustedcall://identity?eventId", @"aiassistanttrustedcall://identity?eventId=arbitrary",
        [valid stringByAppendingString:@"&eventId=other"], [valid stringByAppendingString:@"&name=unverified"],
        [valid stringByAppendingString:@"#fragment"],
        [valid stringByReplacingOccurrencesOfString:@"identity?" withString:@"user@identity?"],
        [valid stringByReplacingOccurrencesOfString:@"identity?" withString:@"identity:123?"],
        [valid stringByReplacingOccurrencesOfString:@"eventId=" withString:@"eventID="]
    ];
    for (NSString *value in invalid) NSCAssert(!TrustedCallerEventIdFromURL([NSURL URLWithString:value]), @"Unexpected URL cannot supply identity or routing data");
    puts("Trusted identity URL whitelist tests passed");
 }
 return 0;
}
