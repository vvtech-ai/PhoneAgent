#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerPushRegistration : NSObject
+ (instancetype)sharedRegistration;
@property(nonatomic, copy, readonly, nullable) NSString *deviceToken;
- (void)requestStartupAuthorization;
- (NSUInteger)attachConsumer;
- (BOOL)isCurrentConsumer:(NSUInteger)consumer;
- (void)updateOwner:(nullable NSDictionary *)owner consumer:(NSUInteger)consumer;
- (void)detachConsumer:(NSUInteger)consumer;
/// Observation only: no registration, SDK call or retry.
- (void)recordBindingSnapshotForConsumer:(NSUInteger)consumer;
- (void)retryForOwner:(NSDictionary *)owner;
- (void)receivedDeviceToken:(NSData *)token;
- (void)receivedRegistrationError:(NSError *)error;
@end
NS_ASSUME_NONNULL_END
