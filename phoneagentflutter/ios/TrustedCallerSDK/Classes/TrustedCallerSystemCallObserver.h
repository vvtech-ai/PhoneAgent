#import <Foundation/Foundation.h>
#import "TrustedCallerIncomingSession.h"
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerSystemCallObserver : NSObject
- (instancetype)initWithSession:(TrustedCallerIncomingSession *)session consumer:(NSUInteger)consumer;
- (void)stop;
@end
NS_ASSUME_NONNULL_END
