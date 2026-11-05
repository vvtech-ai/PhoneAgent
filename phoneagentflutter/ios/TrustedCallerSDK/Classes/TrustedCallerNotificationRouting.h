#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^TrustedNotificationReply)(NSUInteger options);
typedef BOOL (^TrustedNotificationReceive)(NSDictionary *userInfo);
@interface TrustedCallerNotificationRouting : NSObject
- (void)attachConsumer:(NSUInteger)consumer receive:(TrustedNotificationReceive)receive;
- (BOOL)detachConsumer:(NSUInteger)consumer;
- (void)routeUserInfo:(NSDictionary *)userInfo
    fallback:(void (^)(TrustedNotificationReply reply))fallback
    completion:(TrustedNotificationReply)completion;
- (void)routeUserInfo:(NSDictionary *)userInfo trustedOptions:(NSUInteger)options
    fallback:(void (^)(TrustedNotificationReply reply))fallback
    completion:(TrustedNotificationReply)completion;
@property(nonatomic, readonly) BOOL hasConsumer;
@end
NS_ASSUME_NONNULL_END
