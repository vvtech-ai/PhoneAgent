#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerSurfaceRequest.h"

int main(void) {
    @autoreleasepool {
        NSDictionary *args = @{@"surfaceToken": @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            @"accountId": @"synthetic", @"phone": @"synthetic-phone", @"loginEpoch": @1,
            @"environment": @"test"};
        TrustedCallerSurfaceOwner *owner = [TrustedCallerSurfaceOwner ownerFromArguments:args];
        __block NSUInteger cancelledReplies = 0, successReplies = 0;
        TrustedCallerSurfaceRequest *cancelled = [[TrustedCallerSurfaceRequest alloc] initWithOwner:owner
            reply:^(NSDictionary *report, NSString *error) {
                cancelledReplies++;
                NSCAssert(report == nil && [error isEqual:@"SDK_SURFACE_CLOSED"], @"Cancellation must not report authorization");
            }];
        [cancelled finishWithFields:nil errorCode:@"SDK_SURFACE_CLOSED"];
        [cancelled finishWithFields:@{@"status": @"authorized", @"explicitSdkAuthorization": @YES} errorCode:nil];
        NSCAssert(cancelledReplies == 1 && cancelled.completed && cancelled.owner == nil, @"Late SDK callback must not reply or retain old identity");
        __block TrustedCallerSurfaceRequest *success;
        success = [[TrustedCallerSurfaceRequest alloc] initWithOwner:owner reply:^(NSDictionary *report, NSString *error) {
            successReplies++;
            NSCAssert(error == nil && [report[@"accountId"] isEqual:@"synthetic"], @"Current report must keep owner");
            [success finishWithFields:nil errorCode:@"SDK_SURFACE_CLOSED"];
        }];
        [success finishWithFields:@{@"status": @"readyToConfigure"} errorCode:nil];
        NSCAssert(successReplies == 1 && success.owner == nil, @"Reply must be one-shot before reentry");
        success = nil;
        puts("Foundation cancelled/late/reentrant SDK requests passed; no SDK initialized.");
    }
    return 0;
}
