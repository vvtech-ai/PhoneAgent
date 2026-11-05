#import <Foundation/Foundation.h>
#import "TrustedCallerIncomingPayload.h"
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerIdentityEvidence : NSObject
+ (NSDictionary *)reportForCode:(NSInteger)code data:(nullable id)data
    payload:(TrustedCallerIncomingPayload *)payload;
@end
NS_ASSUME_NONNULL_END
