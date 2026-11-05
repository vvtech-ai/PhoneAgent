#import <Foundation/Foundation.h>
#import "PAIdentityTraceStore.h"
#import "PAIdentityTraceScope.h"
#import "PACrashAccountBinding.h"

@interface PATestMetadataSink : NSObject <PACrashMetadataSink>
@property(nonatomic, strong) NSData *customData;
@end
@implementation PATestMetadataSink
@end

void testIdentityTraceStore(void) {
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory() stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    PAIdentityTraceStore *store = [[PAIdentityTraceStore alloc] initWithDirectory:root];
    NSString *a = [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0];
    NSString *b = [@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0];
    NSString *run = NSUUID.UUID.UUIDString;
    PACrashAccountBinding *binding = [PACrashAccountBinding new];
    PATestMetadataSink *sink = [PATestMetadataSink new];
    [binding bindScope:a run:run];
    [binding bindScope:b run:run];
    [binding publish:sink];
    NSDictionary *(^metadata)(void) = ^NSDictionary * { return sink.customData ? [NSJSONSerialization JSONObjectWithData:sink.customData options:0 error:nil] : nil; };
    NSCAssert([metadata()[@"scope"] isEqual:b], @"late reporter publish uses latest binding");
    [binding bindScope:a run:run];
    NSCAssert([metadata()[@"scope"] isEqual:a], @"A-B-A updates immediately without IO queue");
    [binding bindScope:nil run:run];
    NSCAssert(sink.customData == nil, @"logout clears immediately without IO queue");
    [binding publish:[PATestMetadataSink new]];
    [binding bindScope:b run:run];
    NSCAssert([metadata()[@"scope"] isEqual:b], @"ready reporter never replaced");
    PAIdentityTraceScope *scope = [PAIdentityTraceScope new];
    NSString *real = @"identity-1792400329982000-3";
    NSString *session = [PAIdentityTraceScope identityForSession:real];
    NSCAssert(session.length == 36 && [session isEqual:[PAIdentityTraceScope identityForSession:real]], @"real port session has stable diagnostic identity");
    NSCAssert(![session isEqual:[PAIdentityTraceScope identityForSession:@"identity-1792400329982000-4"]], @"distinct attempts remain distinct");
    [scope bind:a];
    NSCAssert([[scope resolve:@"prepare.enter" session:session] isEqual:a], @"first prepare binds account");
    NSString *preview = [PAIdentityTraceScope identityForSession:NSUUID.UUID.UUIDString];
    NSCAssert([[scope resolve:@"preview.prepare" session:preview] isEqual:a], @"preview operation binds account");
    [scope bind:b];
    NSCAssert([[scope resolve:@"sdk.callback" session:session] isEqual:a], @"late SDK callback stays with old account");
    NSCAssert([[scope resolve:@"preview.result" session:preview] isEqual:a], @"late preview result stays with old account");
    NSString *unknown = [PAIdentityTraceScope identityForSession:@"identity-1792400329982000-5"];
    NSCAssert([scope resolve:@"sdk.callback" session:unknown] == nil, @"unknown session cannot inherit a new login");
    [scope bind:nil];
    [scope resolve:@"prepare.enter" session:unknown];
    [scope bind:b];
    NSCAssert([scope resolve:@"prepare.enter" session:unknown] == nil, @"unbound attempt cannot be reassigned after login");
    NSDictionary *context = @{@"schema":@1, @"runId":NSUUID.UUID.UUIDString.lowercaseString, @"dropped":@0};
    long long now = (long long)(NSDate.date.timeIntervalSince1970 * 1000);
    NSDictionary *(^event)(NSUInteger) = ^NSDictionary *(NSUInteger sequence) {
        return @{@"seq":@(sequence), @"time":@(now), @"event":@"sdk.callback"};
    };
    NSCAssert([store append:event(1) context:context scope:a], @"first event durable");
    NSCAssert([store read:b].count == 0, @"scope isolation");
    NSDictionary *first = [store read:a].firstObject;
    NSString *identity = first[@"id"];
    NSCAssert([identity isEqual:[store read:a].firstObject[@"id"]], @"same snapshot stable");
    NSCAssert([store append:event(2) context:context scope:a], @"event after upload snapshot");
    NSCAssert([store acknowledge:b ids:@[identity]], @"foreign receipt ignored");
    NSCAssert([[store read:a].firstObject[@"iosTrace"][@"events"] count] == 2, @"foreign acknowledgement cannot delete");
    NSCAssert([store acknowledge:a ids:@[identity]], @"ack old snapshot only");
    NSArray *remaining = [store read:a].firstObject[@"iosTrace"][@"events"];
    NSCAssert(remaining.count == 1 && [remaining.firstObject[@"seq"] integerValue] == 2, @"new event survives old ack");
    store = [[PAIdentityTraceStore alloc] initWithDirectory:root];
    NSCAssert([[store read:a].firstObject[@"iosTrace"][@"events"] count] == 1, @"restart keeps evidence");
    NSString *pending = [store read:a].firstObject[@"id"];
    NSCAssert([store acknowledge:a ids:@[pending]], @"commit persisted snapshot");
    NSCAssert([store read:a].count == 0, @"no repeated snapshot after ack");
    for (NSUInteger i = 3; i < 133; i++) NSCAssert([store append:event(i) context:context scope:a], @"bounded append");
    NSDictionary *bounded = [store read:a].firstObject[@"iosTrace"];
    NSCAssert([bounded[@"events"] count] == 128, @"bounded trace ring");
    NSCAssert([bounded[@"dropped"] integerValue] == 2, @"explicit overwritten event count");
    NSString *old = [store read:a].firstObject[@"id"];
    [store append:event(133) context:context scope:a];
    [store acknowledge:a ids:@[old]];
    NSCAssert([[store read:a].firstObject[@"iosTrace"][@"events"] count] == 1, @"late event survives full ring snapshot ack");
    NSCAssert(![store append:event(134) context:context scope:@"../escape"], @"unsafe scope rejected");
    NSURL *blocker = [root URLByAppendingPathComponent:@"occupied"];
    [@"occupied" writeToURL:blocker atomically:YES encoding:NSUTF8StringEncoding error:nil];
    PAIdentityTraceStore *failed = [[PAIdentityTraceStore alloc] initWithDirectory:blocker];
    NSCAssert(![failed append:event(1) context:context scope:a], @"write failure is not success");
    [NSFileManager.defaultManager removeItemAtURL:root error:nil];
}
