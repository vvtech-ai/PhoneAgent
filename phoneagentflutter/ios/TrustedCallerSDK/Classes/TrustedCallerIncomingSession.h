#import <Foundation/Foundation.h>
#import "TrustedCallerIncomingDriver.h"
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerIncomingSession : NSObject
- (instancetype)initWithBootstrap:(TrustedIncomingBootstrap)bootstrap parse:(TrustedIncomingParse)parse;
- (void)attachConsumer:(NSUInteger)consumer;
- (void)updateOwner:(nullable NSDictionary *)owner consumer:(NSUInteger)consumer;
- (void)updateOwner:(nullable NSDictionary *)owner consumer:(NSUInteger)consumer now:(NSTimeInterval)now;
- (void)listen:(TrustedIncomingReport)report consumer:(NSUInteger)consumer;
- (void)cancelListener:(NSUInteger)consumer;
- (BOOL)receiveUserInfo:(NSDictionary *)userInfo now:(NSTimeInterval)now
    consumer:(NSUInteger)consumer completion:(void (^)(BOOL verified))completion;
- (BOOL)reopenNotification:(NSDictionary *)userInfo consumer:(NSUInteger)consumer;
- (void)endIncoming:(NSUInteger)consumer;
@property(nonatomic, copy, nullable) TrustedIncomingReport lifecycleReport;
- (void)endEventId:(NSString *)eventId consumer:(NSUInteger)consumer;
- (void)setLifecycleListener:(nullable TrustedIncomingReport)listener forKey:(NSString *)key consumer:(NSUInteger)consumer;
- (BOOL)requestPresentationForEventId:(NSString *)eventId consumer:(NSUInteger)consumer now:(NSTimeInterval)now;
@end
NS_ASSUME_NONNULL_END
