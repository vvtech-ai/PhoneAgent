#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerPhoneNumber.h"
int main(void) {
 @autoreleasepool {
    NSCAssert([TrustedCallerNormalizedPhone(@"+86 138-0000-0000") isEqual:@"13800000000"], @"China prefix follows fixed native rule");
    NSCAssert([TrustedCallerNormalizedPhone(@"13800000000") isEqual:@"13800000000"], @"Plain phone retained");
    NSCAssert([TrustedCallerNormalizedPhone(@"+1 (202) 555-0100") isEqual:@"12025550100"], @"Other prefix retained");
    NSCAssert([TrustedCallerNormalizedPhone(@"86123") isEqual:@"86123"], @"No arbitrary prefix stripping");
    NSCAssert([TrustedCallerNormalizedPhone(@"invalid") isEqual:@""], @"No invented fallback phone");
    puts("5 Foundation fixed-native phone boundary cases passed; no SDK called.");
 }
 return 0;
}
