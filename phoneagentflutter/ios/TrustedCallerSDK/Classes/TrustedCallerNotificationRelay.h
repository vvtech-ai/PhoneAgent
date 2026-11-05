#import <UserNotifications/UserNotifications.h>
#import "TrustedCallerNotificationRouting.h"
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerNotificationRelay : NSObject <UNUserNotificationCenterDelegate>
+ (instancetype)sharedRelay;
- (void)attachConsumer:(NSUInteger)consumer receive:(TrustedNotificationReceive)receive;
- (void)detachConsumer:(NSUInteger)consumer;
- (void)install;
@end
NS_ASSUME_NONNULL_END
