#import <Foundation/Foundation.h>
NS_ASSUME_NONNULL_BEGIN
/// Main-thread account lifetime rules. Private APNS data never crosses Flutter.
@interface TrustedCallerPushBindingState : NSObject
@property(nonatomic, readonly) BOOL needsRetry;
@property(nonatomic, readonly) BOOL hasWork;
/// Read-only evidence for the current desired identity; never returns private data.
@property(nonatomic, copy, readonly) NSString *diagnosticCode;
- (void)updateOwner:(nullable NSDictionary *)owner
        deviceToken:(nullable NSString *)deviceToken
  notificationAllowed:(BOOL)notificationAllowed
             sdkReady:(BOOL)sdkReady;
/// The caller executes at most this one frozen action. Nil means no work.
- (nullable NSDictionary *)nextAction;
/// Only the active request ID may complete. Failure means remote state uncertain.
- (void)completeRequest:(NSString *)requestId success:(BOOL)success;
- (void)retry;
@end
NS_ASSUME_NONNULL_END
