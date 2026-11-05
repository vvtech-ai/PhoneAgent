#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerCallAssociation : NSObject
- (void)updateEventId:(nullable NSString *)eventId;
- (nullable NSString *)observeUUID:(NSString *)uuid outgoing:(BOOL)outgoing ended:(BOOL)ended;
@end
NS_ASSUME_NONNULL_END
