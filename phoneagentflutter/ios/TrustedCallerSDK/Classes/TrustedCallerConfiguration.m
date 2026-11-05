#import "TrustedCallerConfiguration.h"
#if __has_include("../Generated/TrustedCallerLocalCredentials.h")
#import "../Generated/TrustedCallerLocalCredentials.h"
#define PHONEAGENT_HAS_LOCAL_TRUSTED_CONFIG 1
#endif

@implementation TrustedCallerConfiguration
+ (NSDictionary<NSString *, NSString *> *)credentials {
#if PHONEAGENT_HAS_LOCAL_TRUSTED_CONFIG && defined(PHONEAGENT_TRUSTED_SDK_TEST) && \
    (PHONEAGENT_TRUSTED_SDK_TEST == 0 || PHONEAGENT_TRUSTED_SDK_TEST == 1)
    NSString *key = TrustedCallerLocalCredentials.appKey;
    NSString *secret = TrustedCallerLocalCredentials.appSecret;
    if (key.length > 0 && secret.length > 0) {
        return @{@"appKey": key, @"appSecret": secret};
    }
#endif
    return nil;
}
@end
