#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingDriver.h"
int main(void) {
 @autoreleasepool {
    NSMutableArray *reports = [NSMutableArray array], *parses = [NSMutableArray array];
    __block void (^boot)(BOOL);
    __block NSUInteger starts = 0;
    TrustedCallerIncomingDriver *driver = [[TrustedCallerIncomingDriver alloc]
        initWithBootstrap:^(void (^completion)(BOOL)) { starts++; boot = [completion copy]; }
        parse:^(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger, id)) { [parses addObject:[completion copy]]; }
        report:^(NSDictionary *report) { [reports addObject:report ?: NSNull.null]; }];
    NSDictionary *first = @{@"accountId":@"first", @"phone":@"13800000000", @"loginEpoch":@1, @"environment":@"test"};
    NSDictionary *second = @{@"accountId":@"second", @"phone":@"13800000000", @"loginEpoch":@2, @"environment":@"test"};
    NSMutableDictionary *incoming = [@{@"token":@"synthetic-opaque", @"phoneno":@"12025550100", @"targetNumber":@"13800000000",
        @"sequence":@"one", @"callTime":@1700000000000} mutableCopy];
    NSCAssert(![driver receiveUserInfo:incoming now:1700000000] && starts == 0, @"Signed out refuses SDK work");
    [driver updateOwner:first];
    [driver receiveUserInfo:incoming now:1700000000];
    [driver receiveUserInfo:incoming now:1700000000];
    NSCAssert(starts == 1 && [reports.lastObject[@"identity"][@"verification"] isEqual:@"pending"], @"Duplicate push deduplicated and cannot preverify");
    boot(YES); boot(YES);
    NSCAssert(parses.count == 1, @"Bootstrap duplicate cannot parse twice");
    void (^oldParse)(NSInteger, id) = parses[0];
    [driver updateOwner:second];
    NSUInteger afterOwner = reports.count;
    oldParse(1, @{@"name":@"old-synthetic"});
    NSCAssert(reports.count == afterOwner, @"Late old-account success cannot publish");
    [driver receiveUserInfo:incoming now:1700000000]; boot(YES);
    void (^endedParse)(NSInteger, id) = parses[1];
    [driver endIncoming]; NSUInteger afterEnd = reports.count;
    endedParse(1, @{@"name":@"ended"});
    NSCAssert(reports.count == afterEnd, @"Ended call rejects late success");
    [driver receiveUserInfo:incoming now:1700000000]; boot(YES);
    void (^replacedParse)(NSInteger, id) = parses[2];
    incoming[@"sequence"] = @"two";
    [driver receiveUserInfo:incoming now:1700000000]; boot(YES);
    NSUInteger afterReplacement = reports.count;
    replacedParse(1, @{@"name":@"replaced"});
    NSCAssert(reports.count == afterReplacement, @"New event rejects old parse");
    void (^currentParse)(NSInteger, id) = parses[3];
    currentParse(1, @{@"name":@"current-synthetic"});
    currentParse(1, @{@"name":@"duplicate"});
    NSCAssert(reports.count == afterReplacement + 1 &&
        [reports.lastObject[@"identity"][@"verification"] isEqual:@"verified"] &&
        [reports.lastObject[@"activityFresh"] boolValue], @"Current SDK confirmation publishes once and permits fresh activity");
    NSCAssert(reports.lastObject[@"identity"][@"token"] == nil, @"Opaque token never in UI report");
    [driver updateOwner:nil];
    NSCAssert(reports.lastObject == NSNull.null, @"Logout clears visible identity");
    NSMutableDictionary *invalidOwner = first.mutableCopy;
    invalidOwner[@"loginEpoch"] = @YES;
    [driver updateOwner:invalidOwner];
    NSUInteger beforeInvalid = starts;
    NSCAssert(![driver receiveUserInfo:incoming now:1700000000] && starts == beforeInvalid, @"Malformed epoch refuses SDK work");
    puts("Foundation incoming account/event/end/duplicate/late verification cases passed; no SDK requests.");
 }
 return 0;
}
