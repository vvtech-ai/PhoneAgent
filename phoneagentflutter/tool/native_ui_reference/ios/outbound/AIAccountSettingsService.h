#import <Foundation/Foundation.h>
#import "AISettingsModels.h"

typedef void (^ReferenceOutboundCompletion)(AIOutboundNumberResponse *, NSError *);

// Minimal selectors used by the fixed UI. All implementation is synthetic.
@interface AIAccountSettingsService : NSObject
+ (instancetype)sharedService;
- (void)fetchOutboundNumberWithCompletion:(ReferenceOutboundCompletion)completion;
- (void)updateOutboundNumber:(NSString *)number completion:(ReferenceOutboundCompletion)completion;
- (void)deleteOutboundNumberWithCompletion:(ReferenceOutboundCompletion)completion;
@end
