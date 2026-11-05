#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Native-memory-only request. Never forward sdkArguments to Flutter or logs.
@interface TrustedCallerIncomingPayload : NSObject
@property(nonatomic, copy, readonly) NSDictionary *sdkArguments;
@property(nonatomic, copy, readonly) NSDictionary *preview;
@property(nonatomic, readonly) BOOL activityFresh;
@property(nonatomic, copy, readonly) NSString *avatarURL;
/// Structural candidate only; recovery must revalidate against the real owner.
+ (nullable instancetype)candidateFromUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now;
+ (nullable instancetype)payloadFromUserInfo:(NSDictionary *)userInfo
    currentPhone:(NSString *)currentPhone now:(NSTimeInterval)now;
@end
NS_ASSUME_NONNULL_END
