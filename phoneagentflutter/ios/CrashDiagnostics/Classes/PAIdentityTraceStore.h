#import <Foundation/Foundation.h>

// All methods run on the trace serial queue. Acknowledgement uses read watermarks.
@interface PAIdentityTraceStore : NSObject
- (instancetype)initWithDirectory:(NSURL *)directory;
- (BOOL)append:(NSDictionary *)event context:(NSDictionary *)context scope:(NSString *)scope;
- (NSArray<NSDictionary *> *)read:(NSString *)scope;
- (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids;
@end
