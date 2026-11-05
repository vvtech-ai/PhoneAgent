#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingDiagnostics.h"
int main(void) {
 @autoreleasepool {
    TrustedCallerIncomingDiagnostics *trace = [TrustedCallerIncomingDiagnostics new];
    [trace attachConsumer:1];
    for (NSUInteger i = 0; i < 70; i++) [trace recordStage:@"incomingReceive" code:@"IOS_PUSH_COLD" result:@"received"];
    NSMutableArray *events = [NSMutableArray array];
    [trace listen:^(NSDictionary *event) { [events addObject:event]; } consumer:1];
    NSCAssert(events.count == 64, @"Bounded oldest-first buffer");
    [trace recordStage:@"incomingReceive" code:@"private-data" result:@"received"];
    [trace recordStage:@"private-stage" code:@"IOS_PUSH_COLD" result:@"received"];
    [trace recordStage:@"incomingReceive" code:@"IOS_PUSH_COLD" result:@"private-result"];
    NSCAssert(events.count == 64, @"Reject arbitrary strings");
    NSDictionary *metadata = events.lastObject[@"diagnostic"];
    NSCAssert(metadata.count == 4 && metadata[@"timeMs"], @"Only stage/code/result/time");
    [trace attachConsumer:2];
    [trace listen:^(NSDictionary *event) { [events addObject:event]; } consumer:1];
    [trace recordStage:@"incomingDelivery" code:@"IOS_EVENT_CLEARED" result:@"cancelled"];
    NSCAssert(events.count == 64, @"Old consumer cannot receive new events");
    [trace listen:^(NSDictionary *event) { [events addObject:event]; } consumer:2];
    NSCAssert(events.count == 65, @"Current consumer recovers once");
    NSError *failure = [NSError errorWithDomain:NSCocoaErrorDomain code:3000
        userInfo:@{NSLocalizedDescriptionKey:@"synthetic-private", @"token":@"synthetic-private"}];
    [trace recordAPNSRegistrationError:failure];
    NSDictionary *error = events.lastObject[@"diagnostic"];
    NSCAssert([error[@"code"] isEqual:@"IOS_APNS_REGISTRATION_FAILED"] &&
        [error[@"result"] isEqual:@"failed"], @"Preserve actual failure");
    NSCAssert([error[@"errorDomain"] isEqual:NSCocoaErrorDomain] &&
        [error[@"errorCode"] isEqual:@3000], @"Keep safe system evidence");
    NSCAssert(error.count == 6 && ![error.description containsString:@"synthetic-private"], @"No raw error body");
    [trace recordAPNSRegistrationError:[NSError errorWithDomain:@"synthetic-private" code:-1 userInfo:nil]];
    NSCAssert([events.lastObject[@"diagnostic"][@"errorDomain"] isEqual:@"other"], @"Unknown domains are redacted");
    [trace recordAPNSRegistrationError:[NSError errorWithDomain:NSURLErrorDomain code:NSURLErrorNotConnectedToInternet userInfo:nil]];
    NSCAssert([events.lastObject[@"diagnostic"][@"errorCode"] isEqual:@(NSURLErrorNotConnectedToInternet)], @"Negative codes preserved");
    [trace recordAPNSRegistrationError:[NSError errorWithDomain:NSPOSIXErrorDomain code:NSIntegerMax userInfo:nil]];
    NSCAssert(events.lastObject[@"diagnostic"][@"errorCode"] == nil, @"Reject out of range codes");
    puts("Incoming diagnostic whitelist, bounded buffer and consumer isolation passed");
 }
}
