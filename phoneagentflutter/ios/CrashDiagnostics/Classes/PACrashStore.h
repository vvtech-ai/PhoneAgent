#import <Foundation/Foundation.h>

// Caller serializes all access. No code from this class runs in a crash handler.
@interface PACrashStore : NSObject
- (instancetype)initWithDirectory:(NSURL *)directory;
- (BOOL)append:(NSDictionary *)row error:(NSError **)error;
- (NSArray<NSDictionary *> *)read:(NSString *)scope error:(NSError **)error;
- (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids error:(NSError **)error;
@end
