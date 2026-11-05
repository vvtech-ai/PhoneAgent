#import "TrustedCallerSurfaceRequest.h"

@interface TrustedCallerSurfaceRequest ()
@property (nonatomic, copy, nullable) TrustedCallerSurfaceReply reply;
@end
@implementation TrustedCallerSurfaceRequest
- (instancetype)initWithOwner:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    if ((self = [super init])) { _owner = owner; _reply = [reply copy]; }
    return self;
}
- (void)finishWithFields:(NSDictionary<NSString *, id> *)fields errorCode:(NSString *)error {
    if (self.completed) return;
    _completed = YES;
    NSDictionary *report = error ? nil : [self.owner reportWithFields:fields ?: @{}];
    TrustedCallerSurfaceReply reply = self.reply;
    _owner = nil;
    self.reply = nil;
    if (reply) reply(report, error);
}
@end
