#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
typedef void (^TrustedPushBootstrap)(void (^completion)(BOOL success));
typedef void (^TrustedPushAction)(NSDictionary *action, void (^completion)(BOOL success));
/// Account consumer; dependencies are injected so tests never initialize SDK.
@interface TrustedCallerPushBindingDriver : NSObject
@property(nonatomic, readonly) BOOL needsRetry;
@property(nonatomic, copy, readonly) NSString *diagnosticCode;
- (instancetype)initWithBootstrap:(TrustedPushBootstrap)bootstrap action:(TrustedPushAction)action;
- (void)updateOwner:(nullable NSDictionary *)owner deviceToken:(nullable NSString *)deviceToken
    notificationAllowed:(BOOL)notificationAllowed;
/// Explicit retry only. Unresolved SDK operations are never replayed.
- (void)retry;
@end
NS_ASSUME_NONNULL_END
