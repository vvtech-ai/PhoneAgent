#import <Foundation/Foundation.h>
typedef NS_ENUM(NSInteger, UNAuthorizationStatus) {
    UNAuthorizationStatusNotDetermined, UNAuthorizationStatusDenied,
    UNAuthorizationStatusAuthorized, UNAuthorizationStatusProvisional, UNAuthorizationStatusEphemeral
};
enum { UNAuthorizationOptionAlert = 1, UNAuthorizationOptionBadge = 2, UNAuthorizationOptionSound = 4 };
@interface UNNotificationSettings : NSObject
@property(nonatomic) UNAuthorizationStatus authorizationStatus;
@end
@interface UNUserNotificationCenter : NSObject
+ (instancetype)currentNotificationCenter;
- (void)requestAuthorizationWithOptions:(NSUInteger)options completionHandler:(void (^)(BOOL, NSError *))handler;
- (void)getNotificationSettingsWithCompletionHandler:(void (^)(UNNotificationSettings *))handler;
@end
