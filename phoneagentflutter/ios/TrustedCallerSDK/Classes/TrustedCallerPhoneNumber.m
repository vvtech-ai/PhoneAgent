#import "TrustedCallerPhoneNumber.h"
NSString *TrustedCallerNormalizedPhone(NSString *raw) {
    if (![raw isKindOfClass:NSString.class]) return @"";
    NSMutableString *digits = [NSMutableString string];
    for (NSUInteger index = 0; index < raw.length; index++) {
        unichar character = [raw characterAtIndex:index];
        if ([NSCharacterSet.decimalDigitCharacterSet characterIsMember:character])
            [digits appendFormat:@"%C", character];
    }
    if ([digits hasPrefix:@"86"] && digits.length == 13) return [digits substringFromIndex:2];
    return digits.copy;
}
