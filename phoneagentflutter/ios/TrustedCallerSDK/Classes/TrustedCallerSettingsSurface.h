#import <UIKit/UIKit.h>
#import <Flutter/Flutter.h>
#import "TrustedCallerSurfaceOwner.h"
#import "TrustedCallerSurfaceRequest.h"

NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerSettingsSurface : NSObject
- (instancetype)initWithHost:(nullable UIViewController *)host;
- (void)configureIdentityOverlayWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger;
- (void)updateAccount:(nullable NSDictionary *)account;
- (void)prepare:(TrustedCallerSurfaceOwner *)owner linked:(BOOL)linked reply:(TrustedCallerSurfaceReply)reply;
- (void)readStatus:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply;
- (void)markIntroductionSeen:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply;
- (void)openSettings:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply;
- (void)releaseSurface:(TrustedCallerSurfaceOwner *)owner;
- (void)close;
@end
NS_ASSUME_NONNULL_END
