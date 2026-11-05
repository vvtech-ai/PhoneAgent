#import <Foundation/Foundation.h>

@interface IdentityCaptureTrace : NSObject
- (instancetype)initWithSession:(NSString *)session actor:(NSString *)actor;
- (void)stop;
@end
