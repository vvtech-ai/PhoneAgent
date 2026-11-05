#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerAvatarLoader : NSObject
+ (void)loadValue:(nullable id)value completion:(void (^)(NSData * _Nullable))completion;
@end
NS_ASSUME_NONNULL_END
