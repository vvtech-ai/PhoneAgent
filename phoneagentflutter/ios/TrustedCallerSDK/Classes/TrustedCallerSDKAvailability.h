#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Build facts only. This class never initializes or authorizes the SDK.
@interface TrustedCallerSDKAvailability : NSObject
+ (BOOL)isDeviceSDKLinked;
+ (NSString *)sdkEnvironment;
+ (NSString *)sdkVersion;
@end

NS_ASSUME_NONNULL_END
