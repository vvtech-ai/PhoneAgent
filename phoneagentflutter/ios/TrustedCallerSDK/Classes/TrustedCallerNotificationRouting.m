#import "TrustedCallerNotificationRouting.h"
@interface TrustedCallerNotificationReplyOnce : NSObject
@property(nonatomic, copy, nullable) TrustedNotificationReply reply;
- (void)finish:(NSUInteger)options;
@end
@implementation TrustedCallerNotificationReplyOnce
- (void)finish:(NSUInteger)options {
    TrustedNotificationReply reply;
    @synchronized (self) {
        reply = self.reply;
        self.reply = nil;
    }
    if (reply) reply(options);
}
@end
@interface TrustedCallerNotificationRouting ()
@property(nonatomic) NSUInteger consumer;
@property(nonatomic, copy, nullable) TrustedNotificationReceive receive;
@end
@implementation TrustedCallerNotificationRouting
- (BOOL)hasConsumer { return self.receive != nil; }
- (void)attachConsumer:(NSUInteger)consumer receive:(TrustedNotificationReceive)receive {
    NSAssert(NSThread.isMainThread, @"Notification ownership is serialized");
    if (consumer <= self.consumer) return;
    self.consumer = consumer;
    self.receive = receive;
}
- (BOOL)detachConsumer:(NSUInteger)consumer {
    if (consumer != self.consumer) return NO;
    self.receive = nil;
    return YES;
}
- (void)routeUserInfo:(NSDictionary *)userInfo
    fallback:(void (^)(TrustedNotificationReply))fallback completion:(TrustedNotificationReply)completion {
    [self routeUserInfo:userInfo trustedOptions:0 fallback:fallback completion:completion];
}
- (void)routeUserInfo:(NSDictionary *)userInfo trustedOptions:(NSUInteger)options
    fallback:(void (^)(TrustedNotificationReply))fallback completion:(TrustedNotificationReply)completion {
    NSAssert(NSThread.isMainThread, @"Notification dispatch is serialized");
    TrustedCallerNotificationReplyOnce *once = [TrustedCallerNotificationReplyOnce new];
    once.reply = completion;
    TrustedNotificationReply reply = ^(NSUInteger options) { [once finish:options]; };
    TrustedNotificationReceive receive = self.receive;
    if (receive && receive(userInfo)) reply(options);
    else fallback(reply);
}
@end
