#import "PAIdentityTraceScope.h"
#import "PACrashProjection.h"

@implementation PAIdentityTraceScope {
    NSString *_current;
    NSMutableDictionary *_sessions;
}
- (instancetype)init {
    if ((self = [super init])) _sessions = [NSMutableDictionary new];
    return self;
}
+ (NSString *)identityForSession:(NSString *)session {
    if (!session.length) return @"";
    // The production port uses identity-<microseconds>-<sequence>, not UUID.
    // Hash only for diagnostics; never modify the business channel's session.
    NSData *bytes = [[@"identity-trace:" stringByAppendingString:session] dataUsingEncoding:NSUTF8StringEncoding];
    return [PACrashProjection identity:bytes];
}
- (void)bind:(NSString *)scope {
    _current = [PACrashProjection validScope:scope] ? [scope copy] : nil;
}
- (NSString *)resolve:(NSString *)event session:(NSString *)identity {
    if (!identity.length) return _current;
    BOOL starts = [event isEqual:@"prepare.enter"] || [event isEqual:@"preview.prepare"];
    if (starts && !_sessions[identity]) {
        if (_sessions.count >= 128) [_sessions removeObjectForKey:_sessions.allKeys.firstObject];
        _sessions[identity] = _current ?: @"";
    }
    NSString *scope = _sessions[identity];
    return [PACrashProjection validScope:scope] ? scope : nil;
}
@end
