#import <Foundation/Foundation.h>

@protocol PACrashMetadataSink <NSObject>
@property(nonatomic, strong) NSData *customData;
@end

// Main-thread-only metadata ownership. No disk IO or SDK calls.
@interface PACrashAccountBinding : NSObject
- (void)bindScope:(NSString *)scope run:(NSString *)runId;
- (void)publish:(id<PACrashMetadataSink>)reporter;
@end
