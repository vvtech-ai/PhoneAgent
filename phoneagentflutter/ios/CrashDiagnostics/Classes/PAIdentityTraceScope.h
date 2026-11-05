#import <Foundation/Foundation.h>

// Serial trace-queue ownership only; independent of business session state.
@interface PAIdentityTraceScope : NSObject
+ (NSString *)identityForSession:(NSString *)session;
- (void)bind:(NSString *)scope;
- (NSString *)resolve:(NSString *)event session:(NSString *)identity;
@end
