#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingSession.h"
int main(void) {
 @autoreleasepool {
    __block void (^boot)(BOOL);
    __block void (^parsed)(NSInteger, id);
    TrustedCallerIncomingSession *session = [[TrustedCallerIncomingSession alloc]
        initWithBootstrap:^(void (^completion)(BOOL)) { boot = [completion copy]; }
        parse:^(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger, id)) { parsed = [completion copy]; }];
    NSDictionary *owner = @{@"accountId":@"synthetic", @"phone":@"13800000000", @"loginEpoch":@1, @"environment":@"test"};
    NSDictionary *payload = @{@"token":@"synthetic-opaque", @"phoneno":@"12025550100", @"targetNumber":@"13800000000", @"sequence":@"synthetic-sequence", @"callTime":@"1700000000000"};
    [session attachConsumer:1]; [session updateOwner:owner consumer:1];
    NSMutableArray *events = [NSMutableArray array];
    [session listen:^(NSDictionary *report) { [events addObject:report ?: NSNull.null]; } consumer:1];
    __block NSUInteger replies = 0; __block BOOL verified = NO;
    NSCAssert([session receiveUserInfo:payload now:1700000000 consumer:1 completion:^(BOOL value) { replies++; verified = value; }], @"Current event handled");
    NSCAssert(replies == 0 && [events.lastObject[@"identity"][@"verification"] isEqual:@"pending"], @"Pending is not background verification success");
    boot(YES); parsed(1, @{@"name":@"合成身份"}); parsed(1, @{});
    NSCAssert(replies == 1 && verified, @"SDK verification finishes background callback once");
    NSString *verifiedEventId = events.lastObject[@"eventId"];
    NSCAssert(![session requestPresentationForEventId:verifiedEventId consumer:1 now:1700001201], @"Expired activity cannot reopen identity");
    NSCAssert(![session requestPresentationForEventId:verifiedEventId consumer:1 now:1699999939], @"Future activity beyond tolerance cannot reopen identity");
    NSCAssert(![session requestPresentationForEventId:@"old-event" consumer:1 now:1700000000], @"Old activity cannot reopen new event");
    NSCAssert(![session requestPresentationForEventId:verifiedEventId consumer:0 now:1700000000], @"Old engine cannot request presentation");
    __block NSUInteger observerCalls = 0;
    [session setLifecycleListener:^(NSDictionary *report) { observerCalls++; }
        forKey:@"synthetic-activity" consumer:1];
    NSCAssert([session requestPresentationForEventId:verifiedEventId consumer:1 now:1700000000], @"Current verified activity requests explicit presentation");
    NSCAssert([events.lastObject[@"presentationRevision"] isEqual:@1] && observerCalls == 2,
        @"Presentation changes revision without changing verification event or replacing Flutter listener");
    NSUInteger beforeWrongEnd = events.count;
    NSString *currentEventId = events.lastObject[@"eventId"];
    [session endEventId:@"old-event" consumer:1];
    [session endEventId:currentEventId consumer:0];
    NSCAssert(events.count == beforeWrongEnd, @"Old call event or consumer cannot end current identity");
    __block NSUInteger lifecycleEnds = 0;
    session.lifecycleReport = ^(NSDictionary *report) { if (!report) lifecycleEnds++; };
    [session endEventId:currentEventId consumer:1];
    NSCAssert(events.lastObject == NSNull.null && lifecycleEnds == 1,
        @"Matched call ends the lifecycle observer and Flutter report once");
    NSMutableArray *newEvents = [NSMutableArray array];
    [session attachConsumer:2]; [session updateOwner:owner consumer:2];
    [session listen:^(NSDictionary *report) { [newEvents addObject:report ?: NSNull.null]; } consumer:2];
    [session cancelListener:1]; [session updateOwner:nil consumer:1]; [session endIncoming:1];
    NSCAssert(![session receiveUserInfo:payload now:1700000000 consumer:1 completion:^(BOOL value) { replies++; }], @"Old engine cannot consume new account event");
    NSCAssert([session receiveUserInfo:payload now:1700000000 consumer:2 completion:^(BOOL value) { replies++; verified = value; }], @"New engine event accepted");
    boot(YES);
    void (^late)(NSInteger, id) = parsed;
    [session endIncoming:2];
    NSCAssert(replies == 2 && !verified && newEvents.lastObject == NSNull.null, @"Call end cancels background completion and visible identity");
    NSUInteger afterEnd = newEvents.count;
    late(1, @{@"name":@"late"});
    NSCAssert(replies == 2 && newEvents.count == afterEnd, @"Late SDK result cannot republish or complete twice");
    NSCAssert([session receiveUserInfo:payload now:1700000000 consumer:2 completion:^(BOOL value) { replies++; verified = value; }], @"Pre-restart event accepted");
    boot(YES);
    void (^preRestart)(NSInteger, id) = parsed;
    [session attachConsumer:3];
    NSCAssert(replies == 3 && !verified, @"Engine replacement completes previous background request once");
    NSMutableArray *replacementEvents = [NSMutableArray array];
    [session updateOwner:owner consumer:3];
    [session listen:^(NSDictionary *report) { [replacementEvents addObject:report ?: NSNull.null]; } consumer:3];
    [session cancelListener:2];
    NSUInteger beforeLate = replacementEvents.count;
    preRestart(1, @{@"name":@"old-engine"});
    NSCAssert(replacementEvents.count == beforeLate && replies == 3, @"Old engine result/cancel cannot affect replacement listener");
    puts("Foundation incoming stream consumer and background completion isolation passed; no SDK executed.");
 }
 return 0;
}
