#import "IdentityCaptureSDKInitialization.h"

// Independent of plugin/session lifetime. All callers stay on the existing main queue.
static BOOL initialized;

@implementation IdentityCaptureSDKInitialization
+ (void)ensureInitialized:(void (NS_NOESCAPE ^)(void))initializer {
    NSAssert(NSThread.isMainThread, @"Identity SDK initialization must stay on main");
    if (initialized) return;
    initializer();
    // Keep exceptions retryable through the plugin's existing error path.
    initialized = YES;
}
@end
