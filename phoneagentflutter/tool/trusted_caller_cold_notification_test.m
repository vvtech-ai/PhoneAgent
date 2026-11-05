#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingSession.h"
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerIncomingPayload.h"

static NSDictionary *Owner(NSString *phone) {
    return @{ @"accountId":@"synthetic", @"phone":phone, @"loginEpoch":@1, @"environment":@"test" };
}
static NSDictionary *Payload(NSString *sequence) {
    return @{ @"token":@"synthetic-opaque", @"phoneno":@"12025550100", @"targetNumber":@"13800000000",
        @"sequence":sequence, @"callTime":@"1700000000000", @"name":@"合成姓名",
        @"dept":@"合成部门", @"companyName":@"合成企业", @"authorized":@YES,
        @"avatarUrl":@"https://invalid.example/avatar", @"extra":@"untrusted" };
}
int main(void) {
    @autoreleasepool {
        for (NSUInteger scenario = 0; scenario < 7; scenario++) {
            __block NSUInteger boots = 0, parses = 0, completions = 0;
            __block NSString *parsedSequence;
            TrustedCallerIncomingSession *session = [[TrustedCallerIncomingSession alloc]
                initWithBootstrap:^(void (^completion)(BOOL)) { boots++; completion(YES); }
                parse:^(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger, id)) {
                    parses++; parsedSequence = payload.sdkArguments[@"sequence"];
                    NSCAssert(payload.sdkArguments.count == 4, @"Only SDK's four opaque request fields");
                    NSCAssert(!payload.preview[@"authorized"] && !payload.preview[@"avatarUrl"] && !payload.preview[@"extra"], @"No untrusted proof or arbitrary fields");
                    NSCAssert([payload.preview[@"deptZh"] isEqual:@"合成部门"] &&
                        [payload.preview[@"commonName"] isEqual:@"合成企业"], @"Whitelisted aliases survive recovery");
                    completion(1, @{ @"name":@"合成姓名" });
                }];
            [session attachConsumer:1];
            NSCAssert(![session receiveUserInfo:(id)@"malformed" now:1700000000 consumer:1 completion:^(BOOL value) {}], @"Malformed notification rejected before subscripting");
            NSCAssert([session receiveUserInfo:Payload(@"stale") now:1700001201 consumer:1 completion:^(BOOL value) {}], @"Activity freshness does not reject credential candidate");
            NSCAssert([session receiveUserInfo:Payload(@"first") now:1700000000 consumer:1 completion:^(BOOL verified) {
                completions++; NSCAssert(!verified, @"Cache never confirms verification");
            }], @"Fresh structured notification accepted before first account");
            NSCAssert(boots == 0 && parses == 0 && completions == 1, @"No SDK work or delayed system callback during recovery");
            if (scenario == 1) {
                [session updateOwner:nil consumer:1 now:1700000001];
                NSCAssert(![session receiveUserInfo:Payload(@"signed-out") now:1700000001 consumer:1 completion:^(BOOL value) {}], @"First nil permanently closes recovery window");
            }
            if (scenario == 2) [session updateOwner:Owner(@"13900000000") consumer:1 now:1700000001];
            if (scenario == 3) [session attachConsumer:2];
            if (scenario == 4) [session endIncoming:1];
            if (scenario == 6) {
                NSCAssert([session receiveUserInfo:Payload(@"latest") now:1700000001 consumer:1 completion:^(BOOL value) {}], @"Latest replaces one cache");
                [session updateOwner:nil consumer:0 now:1700000002];
            }
            [session updateOwner:Owner(@"13800000000") consumer:(scenario == 3 ? 2 : 1)
                now:(scenario == 5 ? 1700000026 : 1700000002)];
            BOOL accepted = scenario == 0 || scenario == 6;
            NSCAssert(boots == (accepted ? 1 : 0) && parses == (accepted ? 1 : 0), @"Nil/wrong phone/replacement/end/expiry discard; matching owner consumes once");
            if (accepted) NSCAssert([parsedSequence isEqual:scenario == 6 ? @"latest" : @"first"], @"Only newest cached event");
            [session updateOwner:Owner(@"13800000000") consumer:(scenario == 3 ? 2 : 1) now:1700000003];
            NSCAssert(boots == (accepted ? 1 : 0), @"Consumed notification is not replayed by repeated owner");
        }
        __block NSUInteger numericBoots = 0, numericParses = 0;
        TrustedCallerIncomingSession *numeric = [[TrustedCallerIncomingSession alloc]
            initWithBootstrap:^(void (^completion)(BOOL)) { numericBoots++; completion(YES); }
            parse:^(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger, id)) {
                numericParses++;
                NSCAssert([payload.sdkArguments[@"called"] isEqual:@"13800000000"], @"Numeric target becomes the existing string request field");
                completion(0, nil);
            }];
        [numeric attachConsumer:1];
        NSMutableDictionary *numericPayload = Payload(@"numeric").mutableCopy;
        numericPayload[@"targetNumber"] = @13800000000LL;
        NSCAssert([numeric receiveUserInfo:numericPayload now:1700000000 consumer:1 completion:^(BOOL value) {
            NSCAssert(!value, @"Structural numeric candidate is not verification");
        }], @"Existing non-boolean numeric target accepted before owner recovery");
        NSCAssert(numericBoots == 0, @"Numeric candidate never starts SDK before owner");
        [numeric updateOwner:Owner(@"13800000000") consumer:1 now:1700000001];
        NSCAssert(numericBoots == 1 && numericParses == 1, @"Recovered matching owner consumes numeric target once");
        numericPayload[@"targetNumber"] = @YES;
        NSCAssert(![TrustedCallerIncomingPayload candidateFromUserInfo:numericPayload now:1700000000], @"Boolean is never a phone number");
        __block NSUInteger withoutTimeParses = 0;
        TrustedCallerIncomingSession *withoutTime = [[TrustedCallerIncomingSession alloc]
            initWithBootstrap:^(void (^done)(BOOL)) { done(YES); }
            parse:^(TrustedCallerIncomingPayload *payload, void (^done)(NSInteger, id)) {
                withoutTimeParses++;
                NSCAssert(!payload.activityFresh, @"Missing time forbids Activity only");
                done(0, nil);
            }];
        [withoutTime attachConsumer:1];
        NSMutableDictionary *missingTime = Payload(@"without-time").mutableCopy;
        [missingTime removeObjectForKey:@"callTime"];
        NSCAssert([withoutTime receiveUserInfo:missingTime now:1700000000 consumer:1 completion:^(BOOL value) {}], @"Cold credentials do not require Activity timestamp");
        [withoutTime updateOwner:Owner(@"13800000000") consumer:1 now:1700000002];
        NSCAssert(withoutTimeParses == 1, @"Matching restored owner validates candidate");
        NSCAssert([withoutTime reopenNotification:missingTime consumer:1], @"Explicit click can reopen failed current credential");
        [withoutTime endIncoming:1];
        NSCAssert(![withoutTime reopenNotification:missingTime consumer:1], @"Ended event cannot reopen");
        puts("Cold notification recovery and numeric/boolean target scenarios passed; synthetic SDK dependencies only.");
    }
    return 0;
}
