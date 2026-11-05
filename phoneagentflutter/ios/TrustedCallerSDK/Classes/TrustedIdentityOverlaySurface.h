#import <Flutter/Flutter.h>
#import <UIKit/UIKit.h>
NS_ASSUME_NONNULL_BEGIN
/// Owns only the identity overlay; never dismisses or recreates the SDK surface.
@interface TrustedIdentityOverlaySurface : NSObject
- (instancetype)initWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger
    presenter:(UIViewController * _Nullable (^)(void))presenter
    acceptsOwner:(BOOL (^)(NSDictionary *owner))acceptsOwner;
- (void)close;
@end
NS_ASSUME_NONNULL_END
