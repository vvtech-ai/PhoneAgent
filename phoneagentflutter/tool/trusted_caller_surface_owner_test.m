#import <Foundation/Foundation.h>
#import "../ios/TrustedCallerSDK/Classes/TrustedCallerSurfaceOwner.h"

int main(void) {
    @autoreleasepool {
        NSMutableString *phone = [@"synthetic-phone" mutableCopy];
        NSDictionary *arguments = @{@"surfaceToken": @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
            @"accountId": @"synthetic-account", @"phone": phone, @"loginEpoch": @3,
            @"environment": @"test"};
        TrustedCallerSurfaceOwner *owner = [TrustedCallerSurfaceOwner ownerFromArguments:arguments];
        NSCAssert(owner != nil, @"Complete owner must parse");
        NSMutableDictionary *account = owner.metadata.mutableCopy;
        [account removeObjectForKey:@"surfaceToken"];
        NSCAssert([owner matchesAccountMetadata:account], @"Account scope does not need surface token");
        NSCAssert(![owner matchesAccountMetadata:nil], @"Signout must reject active surface");
        NSMutableDictionary *wireAccount = account.mutableCopy;
        [wireAccount removeObjectForKey:@"environment"];
        NSDictionary *request = [TrustedCallerSurfaceOwner accountRequestFromArguments:
            @{@"environment": @"test", @"owner": wireAccount} expectedEnvironment:@"test"];
        NSCAssert([owner matchesAccountMetadata:request[@"owner"]], @"Valid request freezes account metadata");
        NSCAssert(request[@"owner"][@"surfaceToken"] == nil, @"Account has no surface lifetime");
        NSCAssert(([TrustedCallerSurfaceOwner accountRequestFromArguments:
            @{@"environment": @"test", @"owner": NSNull.null} expectedEnvironment:@"test"] != nil),
            @"Only explicit null signs out");
        for (id invalid in @[@{}, @{@"environment": @"test"},
                @{@"environment": @"pro", @"owner": NSNull.null},
                @{@"environment": @"test", @"owner": @YES},
                @{@"environment": @"test", @"owner": @{}},
                @{@"environment": @"test", @"owner": owner.metadata}, @"invalid"]) {
            NSCAssert([TrustedCallerSurfaceOwner accountRequestFromArguments:invalid
                expectedEnvironment:@"test"] == nil, @"Malformed request must not sign out");
        }
        NSCAssert(([TrustedCallerSurfaceOwner accountRequestFromArguments:
            @{@"environment": @"unavailable", @"owner": NSNull.null} expectedEnvironment:@"unavailable"] == nil),
            @"Unconfigured environment cannot mutate account");
        for (NSDictionary *change in @[@{@"accountId": @"other"}, @{@"phone": @"other"},
                @{@"loginEpoch": @4}, @{@"environment": @"pro"}, @{@"loginEpoch": @YES}]) {
            NSMutableDictionary *changed = account.mutableCopy;
            [changed addEntriesFromDictionary:change];
            NSCAssert(![owner matchesAccountMetadata:changed], @"Account changes invalidate surface");
        }
        NSCAssert([owner matches:[TrustedCallerSurfaceOwner ownerFromArguments:arguments]], @"Same owner must match");
        [phone appendString:@"-changed"];
        NSCAssert(![owner matches:[TrustedCallerSurfaceOwner ownerFromArguments:arguments]], @"Input mutation must not mutate captured owner");
        for (NSDictionary *change in @[
            @{@"surfaceToken": @"bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"},
            @{@"accountId": @"other"}, @{@"phone": @"other"}, @{@"loginEpoch": @4},
            @{@"environment": @"pro"}]) {
            NSMutableDictionary *newArgs = owner.metadata.mutableCopy;
            [newArgs addEntriesFromDictionary:change];
            NSCAssert(![owner matches:[TrustedCallerSurfaceOwner ownerFromArguments:newArgs]], @"Changed owner must not match");
        }
        for (NSDictionary *invalid in @[@{}, @{@"surfaceToken": @"bad"},
                @{@"loginEpoch": @YES}, @{@"loginEpoch": @-1}, @{@"loginEpoch": @3.0}, @{@"accountId": @""},
                @{@"phone": @"synthetic\nphone"}, @{@"environment": @"unknown"}]) {
            NSMutableDictionary *newArgs = owner.metadata.mutableCopy;
            [newArgs addEntriesFromDictionary:invalid];
            if (invalid.count == 0) [newArgs removeObjectForKey:@"phone"];
            NSCAssert([TrustedCallerSurfaceOwner ownerFromArguments:newArgs] == nil, @"Invalid boundary must reject");
        }
        NSDictionary *report = [owner reportWithFields:@{@"accountId": @"foreign",
            @"appSecret": @"synthetic-secret", @"status": @"readyToConfigure"}];
        NSCAssert([report[@"accountId"] isEqual:owner.metadata[@"accountId"]], @"Fields must not overwrite owner");
        NSCAssert(report[@"appSecret"] == nil, @"Credentials must not cross report boundary");
        puts("Foundation immutable owner, stale surface and report whitelist cases passed; no SDK initialized.");
    }
    return 0;
}
