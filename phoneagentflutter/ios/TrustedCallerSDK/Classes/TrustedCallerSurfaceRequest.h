#import <Foundation/Foundation.h>
#import "TrustedCallerSurfaceOwner.h"

NS_ASSUME_NONNULL_BEGIN
typedef void (^TrustedCallerSurfaceReply)(NSDictionary<NSString *, id> * _Nullable report,
                                         NSString * _Nullable errorCode);
@interface TrustedCallerSurfaceRequest : NSObject
@property (nonatomic, strong, readonly, nullable) TrustedCallerSurfaceOwner *owner;
@property (nonatomic, readonly) BOOL completed;
- (instancetype)initWithOwner:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply;
- (void)finishWithFields:(nullable NSDictionary<NSString *, id> *)fields errorCode:(nullable NSString *)error;
@end
NS_ASSUME_NONNULL_END
