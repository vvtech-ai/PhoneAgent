#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
/// Private native configuration. Never return these values through Flutter.
@interface TrustedCallerConfiguration : NSObject
+ (nullable NSDictionary<NSString *, NSString *> *)credentials;
@end
NS_ASSUME_NONNULL_END
