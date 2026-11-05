#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerPushBindingDriver.h"
int main(void) {
 @autoreleasepool {
    __block NSUInteger starts = 0;
    __block void (^boot)(BOOL);
    __block void (^reply)(BOOL);
    NSMutableArray *actions = [NSMutableArray array];
    TrustedCallerPushBindingDriver *driver = [[TrustedCallerPushBindingDriver alloc]
        initWithBootstrap:^(void (^completion)(BOOL)) { starts++; boot = [completion copy]; }
        action:^(NSDictionary *action, void (^completion)(BOOL)) { [actions addObject:action]; reply = [completion copy]; }];
    NSString *token = [@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0];
    NSDictionary *first = @{@"accountId":@"first", @"phone":@"synthetic", @"loginEpoch":@1, @"environment":@"test"};
    NSDictionary *second = @{@"accountId":@"second", @"phone":@"synthetic", @"loginEpoch":@2, @"environment":@"test"};
    [driver updateOwner:nil deviceToken:token notificationAllowed:YES];
    NSCAssert(starts == 0 && actions.count == 0, @"Token before login cannot initialize or bind SDK");
    [driver updateOwner:first deviceToken:token notificationAllowed:NO];
    NSCAssert(starts == 0 && actions.count == 0, @"No business work before notification permission");
    [driver updateOwner:first deviceToken:token notificationAllowed:YES];
    [driver updateOwner:second deviceToken:token notificationAllowed:YES];
    NSCAssert(starts == 1 && actions.count == 0, @"Bootstrap deduplicated and cannot bind yet");
    NSCAssert([driver.diagnosticCode isEqual:@"IOS_BIND_STATE_INITIALIZING"], @"Initialization differs from binding");
    boot(YES); boot(YES);
    NSCAssert([driver.diagnosticCode isEqual:@"IOS_BIND_STATE_PENDING"], @"Unresolved binding is not success");
    NSCAssert(actions.count == 1 && [actions[0][@"binding"][@"accountId"] isEqual:@"second"], @"Bootstrap must use current owner");
    void (^secondBind)(BOOL) = reply;
    [driver updateOwner:first deviceToken:token notificationAllowed:YES];
    [driver retry];
    NSCAssert(actions.count == 1, @"Unresolved SDK request cannot replay");
    secondBind(YES); secondBind(YES);
    NSCAssert([driver.diagnosticCode isEqual:@"IOS_BIND_STATE_PENDING"], @"Old account success cannot confirm new account");
    NSCAssert(actions.count == 2 && [actions[1][@"operation"] isEqual:@"unbind"], @"Late old success needs exactly one cleanup");
    reply(NO);
    NSCAssert([driver.diagnosticCode isEqual:@"IOS_BIND_STATE_UNCERTAIN"], @"Failed cleanup has unknown remote state");
    NSCAssert(driver.needsRetry && actions.count == 2, @"Failed cleanup blocks binding");
    [driver updateOwner:second deviceToken:token notificationAllowed:YES];
    NSCAssert(actions.count == 2, @"Account update cannot silently retry cleanup");
    [driver retry];
    NSCAssert(actions.count == 3 && [actions[2][@"operation"] isEqual:@"unbind"], @"Explicit retry cleans first");
    reply(YES);
    NSCAssert(actions.count == 4 && [actions[3][@"operation"] isEqual:@"bind"], @"Confirmed cleanup allows current account");
    reply(YES);
    NSCAssert([driver.diagnosticCode isEqual:@"IOS_BIND_STATE_CONFIRMED"], @"Only acknowledged current binding is confirmed");
    for (NSUInteger i = 0; i < 10; i++) (void)driver.diagnosticCode;
    NSCAssert(actions.count == 4, @"Reading diagnostics never repeats SDK operations");
    [driver updateOwner:nil deviceToken:nil notificationAllowed:NO];
    NSCAssert(![driver.diagnosticCode isEqual:@"IOS_BIND_STATE_CONFIRMED"], @"Logout cannot retain confirmed status");
    NSCAssert(actions.count == 5 && [actions[4][@"operation"] isEqual:@"unbind"], @"Logout cleans current registration");
    reply(YES);
    NSCAssert(actions.count == 5 && !driver.needsRetry, @"No signed-out binding");
    [driver updateOwner:nil deviceToken:token notificationAllowed:YES];
    NSCAssert(actions.count == 5 && starts == 1, @"Late token after logout cannot bind old account");
    [driver updateOwner:first deviceToken:nil notificationAllowed:YES];
    NSCAssert(actions.count == 5, @"Login before token cannot bind");
    [driver updateOwner:first deviceToken:token notificationAllowed:YES];
    NSCAssert(actions.count == 6 && [actions[5][@"operation"] isEqual:@"bind"], @"Token arrival binds current login");
    reply(YES);
    [driver updateOwner:first deviceToken:token notificationAllowed:NO];
    NSCAssert(actions.count == 7 && [actions[6][@"operation"] isEqual:@"unbind"], @"Permission revocation cleans binding");
    reply(YES);

    puts("Foundation account binding driver bootstrap/stale/duplicate/uncertain/logout cases passed; no SDK executed.");
 }
 return 0;
}
