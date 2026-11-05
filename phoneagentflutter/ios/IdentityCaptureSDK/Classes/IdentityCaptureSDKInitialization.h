#import <Foundation/Foundation.h>

/// Process-scoped initialization only. Call on the existing main-thread path.
/// No account, capture session, MetaInfo or audio state is retained here.
@interface IdentityCaptureSDKInitialization : NSObject
+ (void)ensureInitialized:(void (NS_NOESCAPE ^)(void))initializer;
@end
