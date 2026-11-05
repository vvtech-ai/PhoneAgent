#import <Foundation/Foundation.h>

// Low-frequency, read-only boundary observations. Never call from a signal handler.
@interface PAIdentityTrace : NSObject
+ (NSString *)runId;
+ (void)bind:(NSString *)scope;
+ (void)record:(NSString *)event session:(NSString *)session actor:(NSString *)actor
         flags:(NSUInteger)flags code:(NSInteger)code;
+ (NSArray<NSDictionary *> *)read:(NSString *)scope;
+ (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids;
@end
