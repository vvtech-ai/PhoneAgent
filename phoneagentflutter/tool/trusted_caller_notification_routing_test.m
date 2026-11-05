#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerNotificationRouting.h"
int main(void) {
 @autoreleasepool {
    TrustedCallerNotificationRouting *routing = [TrustedCallerNotificationRouting new];
    __block NSUInteger oldReceives = 0, newReceives = 0, forwards = 0, replies = 0, options = 99;
    [routing attachConsumer:1 receive:^BOOL(NSDictionary *payload) { oldReceives++; return YES; }];
    [routing attachConsumer:2 receive:^BOOL(NSDictionary *payload) {
        newReceives++; return [payload[@"trusted"] isEqual:@YES];
    }];
    NSCAssert(![routing detachConsumer:1], @"Old engine cannot detach current consumer");
    void (^fallback)(TrustedNotificationReply) = ^(TrustedNotificationReply reply) {
        forwards++; reply(7); reply(8);
    };
    TrustedNotificationReply completion = ^(NSUInteger value) { replies++; options = value; };
    [routing routeUserInfo:@{@"trusted":@YES} fallback:fallback completion:completion];
    NSCAssert(newReceives == 1 && oldReceives == 0 && forwards == 0 && replies == 1 && options == 0,
        @"Current trusted event consumes once without presenting an unverified native banner");
    __block NSUInteger soundReplies = 0;
    [routing routeUserInfo:@{@"trusted":@YES} trustedOptions:1 fallback:fallback completion:^(NSUInteger value) {
        soundReplies++; NSCAssert(value == 1, @"Foreground preserves requested sound without a banner");
    }];
    NSCAssert(soundReplies == 1 && forwards == 0, @"Trusted sound is delivered once without forwarding");
    [routing routeUserInfo:@{@"other":@YES} fallback:fallback completion:completion];
    NSCAssert(forwards == 1 && replies == 2 && options == 7, @"Unknown notification preserves first original options");
    NSCAssert([routing detachConsumer:2] && !routing.hasConsumer, @"Current detach releases handler");
    __block TrustedNotificationReply delayed;
    [routing routeUserInfo:@{} fallback:^(TrustedNotificationReply reply) { delayed = [reply copy]; }
        completion:completion];
    NSCAssert(replies == 2, @"Original asynchronous delegate retains completion");
    delayed(3); delayed(4);
    NSCAssert(replies == 3 && options == 3, @"Asynchronous duplicate completion ignored");
    [routing attachConsumer:1 receive:^BOOL(NSDictionary *payload) { oldReceives++; return YES; }];
    NSCAssert(!routing.hasConsumer, @"Old attach cannot revive cleared consumer");
    NSLog(@"Notification routing ownership and completion tests passed");
 }
 return 0;
}
