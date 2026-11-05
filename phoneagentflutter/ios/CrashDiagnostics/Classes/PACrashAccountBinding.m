#import "PACrashAccountBinding.h"
#import "PACrashProjection.h"

@implementation PACrashAccountBinding {
    NSData *_latest;
    id<PACrashMetadataSink> _ready;
}
- (void)bindScope:(NSString *)scope run:(NSString *)runId {
    NSData *next = nil;
    if ([PACrashProjection validScope:scope] && [[NSUUID alloc] initWithUUIDString:runId ?: @""]) {
        next = [NSJSONSerialization dataWithJSONObject:@{@"scope":scope, @"runId":runId} options:0 error:nil];
    }
    _latest = next;
    _ready.customData = next;
}
- (void)publish:(id<PACrashMetadataSink>)reporter {
    if (_ready || !reporter) return;
    // Called only after background initialization/recovery/enable completes.
    _ready = reporter;
    _ready.customData = _latest;
}
@end
