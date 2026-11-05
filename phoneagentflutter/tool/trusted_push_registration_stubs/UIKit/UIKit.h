#import <Foundation/Foundation.h>
extern NSString * const UIApplicationDidBecomeActiveNotification;
@interface UIApplication : NSObject
+ (instancetype)sharedApplication;
- (void)registerForRemoteNotifications;
@end
