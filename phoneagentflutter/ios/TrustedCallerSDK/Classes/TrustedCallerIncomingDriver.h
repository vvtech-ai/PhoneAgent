#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@class TrustedCallerIncomingPayload;
typedef void (^TrustedIncomingBootstrap)(void (^completion)(BOOL success));
typedef void (^TrustedIncomingParse)(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger code, id _Nullable data));
typedef void (^TrustedIncomingReport)(NSDictionary * _Nullable report);
@interface TrustedCallerIncomingDriver : NSObject
- (instancetype)initWithBootstrap:(TrustedIncomingBootstrap)bootstrap
    parse:(TrustedIncomingParse)parse report:(TrustedIncomingReport)report;
- (void)updateOwner:(nullable NSDictionary *)owner;
- (BOOL)receiveUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now;
- (void)endIncoming;
@end
NS_ASSUME_NONNULL_END
