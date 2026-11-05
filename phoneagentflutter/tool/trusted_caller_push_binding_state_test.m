#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerPushBindingState.h"
static NSDictionary *Owner(NSString *account, NSNumber *epoch) {
    return @{@"accountId":account, @"phone":@"synthetic-phone", @"loginEpoch":epoch, @"environment":@"test"};
}
int main(void) {
 @autoreleasepool {
    NSString *token = [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0];
    TrustedCallerPushBindingState *state = [TrustedCallerPushBindingState new];
    [state updateOwner:Owner(@"first", @1) deviceToken:token notificationAllowed:NO sdkReady:YES];
    NSCAssert(state.nextAction == nil, @"Notification denial must refuse binding");
    [state updateOwner:Owner(@"first", @1) deviceToken:token notificationAllowed:YES sdkReady:NO];
    NSCAssert(state.nextAction == nil, @"Initialization required");
    for (NSString *invalid in @[@"", @"short", [token stringByAppendingString:@"a"],
         [@"z" stringByPaddingToLength:64 withString:@"z" startingAtIndex:0]]) {
        [state updateOwner:Owner(@"first", @1) deviceToken:invalid notificationAllowed:YES sdkReady:YES];
        NSCAssert(state.nextAction == nil, @"Malformed token refused");
    }
    [state updateOwner:Owner(@"first", @YES) deviceToken:token notificationAllowed:YES sdkReady:YES];
    NSCAssert(state.nextAction == nil, @"Boolean epoch refused");
    [state updateOwner:Owner(@"first", @1) deviceToken:token notificationAllowed:YES sdkReady:YES];
    NSDictionary *first = state.nextAction;
    NSCAssert([first[@"operation"] isEqual:@"bind"] && state.nextAction == nil, @"No duplicate request");
    [state updateOwner:Owner(@"second", @2) deviceToken:token notificationAllowed:YES sdkReady:YES];
    [state completeRequest:@"stale" success:YES];
    NSCAssert(state.nextAction == nil, @"Foreign completion must not release active request");
    [state completeRequest:first[@"requestId"] success:YES];
    NSDictionary *cleanup = state.nextAction;
    NSCAssert([cleanup[@"operation"] isEqual:@"unbind"] &&
        [cleanup[@"binding"][@"accountId"] isEqual:@"first"], @"Late old success must unbind first");
    [state completeRequest:cleanup[@"requestId"] success:NO];
    NSCAssert(state.needsRetry && state.nextAction == nil, @"Uncertain unbind blocks new account");
    [state retry];
    NSDictionary *retry = state.nextAction;
    NSCAssert([retry[@"operation"] isEqual:@"unbind"], @"Retry cleanup before bind");
    [state completeRequest:cleanup[@"requestId"] success:YES];
    NSCAssert(state.nextAction == nil, @"Late old reply cannot complete retry");
    [state completeRequest:retry[@"requestId"] success:YES];
    NSDictionary *second = state.nextAction;
    NSCAssert([second[@"operation"] isEqual:@"bind"] &&
        [second[@"binding"][@"accountId"] isEqual:@"second"], @"New bind only after confirmed cleanup");
    [state completeRequest:second[@"requestId"] success:YES];
    NSCAssert(state.nextAction == nil, @"Confirmed same owner deduplicated");
    [state updateOwner:nil deviceToken:nil notificationAllowed:NO sdkReady:YES];
    NSDictionary *logout = state.nextAction;
    NSCAssert([logout[@"operation"] isEqual:@"unbind"], @"Logout cleans confirmed account");
    [state completeRequest:logout[@"requestId"] success:YES];
    NSCAssert(state.nextAction == nil, @"Signed out cannot bind");
    [state updateOwner:Owner(@"first", @3) deviceToken:token notificationAllowed:YES sdkReady:YES];
    NSDictionary *uncertainBind = state.nextAction;
    [state completeRequest:uncertainBind[@"requestId"] success:NO];
    NSCAssert(state.nextAction == nil && state.needsRetry, @"Failed bind is not confirmed success");
    [state retry];
    NSDictionary *uncertainCleanup = state.nextAction;
    NSCAssert([uncertainCleanup[@"operation"] isEqual:@"unbind"], @"Uncertain same-owner bind must clean before retry");
    [state completeRequest:uncertainCleanup[@"requestId"] success:YES];
    NSCAssert([state.nextAction[@"operation"] isEqual:@"bind"], @"Current owner retries after cleanup");
    puts("Foundation notification/token gates and serial account binding compensation passed; no SDK or APNS request.");
 }
 return 0;
}
