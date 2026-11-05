#import <Foundation/Foundation.h>

// Synthetic DTO only. No native account model/service implementation is linked.
@interface AIOutboundNumberResponse : NSObject
@property(nonatomic, copy) NSString *accountId;
@property(nonatomic, copy) NSString *outboundNumber;
@property(nonatomic, assign) BOOL configured;
@end
