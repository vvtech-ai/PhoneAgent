#import "TrustedCallerSDKAvailability.h"
#import <TargetConditionals.h>

#if !TARGET_OS_SIMULATOR
#import <KXSDK/ChakenSdk.h>
#import <KXSDK/KXSSDK-Swift.h>
#endif

@implementation TrustedCallerSDKAvailability

+ (BOOL)isDeviceSDKLinked {
#if TARGET_OS_SIMULATOR
    return NO;
#else
    return NSClassFromString(@"ChakenSdk") != Nil &&
           NSClassFromString(@"KXSDK.KXSetViewController") != Nil;
#endif
}

+ (NSString *)sdkEnvironment {
#if defined(PHONEAGENT_TRUSTED_SDK_TEST) && PHONEAGENT_TRUSTED_SDK_TEST == 1
    return @"test";
#elif defined(PHONEAGENT_TRUSTED_SDK_TEST) && PHONEAGENT_TRUSTED_SDK_TEST == 0
    return @"pro";
#else
    return @"unavailable";
#endif
}

+ (NSString *)sdkVersion {
    return @"1.8.0";
}

@end
