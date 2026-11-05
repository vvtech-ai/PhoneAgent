#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerAuthorizationEvidence : NSObject
+ (NSDictionary<NSString *, id> *)reportForCode:(NSInteger)code data:(nullable id)data;
@end
NS_ASSUME_NONNULL_END
