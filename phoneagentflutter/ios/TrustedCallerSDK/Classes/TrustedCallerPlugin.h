#import <Flutter/Flutter.h>

NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerPlugin : NSObject <FlutterPlugin>
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar host:(nullable UIViewController *)host;
+ (void)installNotificationRelay;
+ (void)setActivityReportObserver:(nullable void (^)(NSDictionary * _Nullable report))observer;
+ (void)recordIncomingStage:(NSString *)stage code:(NSString *)code result:(NSString *)result;
+ (BOOL)reopenIncomingNotification:(NSDictionary *)userInfo;
+ (BOOL)handleTrustedIdentityURL:(NSURL *)url;
@end
NS_ASSUME_NONNULL_END
