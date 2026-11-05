#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN
@class TrustedCallerIncomingPayload;
/// App-level SDK bootstrap; independent of account and settings presentation.
@interface TrustedCallerSdkClient : NSObject
+ (instancetype)sharedClient;
- (void)initializeWithCompletion:(void (^)(BOOL success))completion;
- (void)verifyIncomingPayload:(TrustedCallerIncomingPayload *)payload
    completion:(void (^)(NSInteger code, NSDictionary * _Nullable evidence))completion;
- (void)performPushBindingAction:(NSDictionary *)action completion:(void (^)(BOOL success))completion;
- (void)readAuthorization:(void (^)(NSDictionary<NSString *, id> *report))completion;
@end
NS_ASSUME_NONNULL_END
