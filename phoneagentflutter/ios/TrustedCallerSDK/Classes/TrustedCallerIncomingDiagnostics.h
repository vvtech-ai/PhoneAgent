#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
@interface TrustedCallerIncomingDiagnostics : NSObject
+ (instancetype)shared;
- (void)attachConsumer:(NSUInteger)consumer;
- (void)listen:(nullable void (^)(NSDictionary *))sink consumer:(NSUInteger)consumer;
- (void)recordAPNSRegistrationError:(NSError *)error;
- (void)recordStage:(NSString *)stage code:(NSString *)code result:(NSString *)result;
@end
NS_ASSUME_NONNULL_END
