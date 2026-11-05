#import <Foundation/Foundation.h>
#import "PACrashStore.h"
#import "PACrashProjection.h"
#import <CrashReporter/CrashReporter.h>
void testIdentityTraceStore(void);

// Run on macOS against the same production projection/store; no real account,
// capture SDK, network or deliberate crash is used by this executable.
int main(void) {
  @autoreleasepool {
    testIdentityTraceStore();
    NSURL *root = [NSURL fileURLWithPath:[NSTemporaryDirectory()
      stringByAppendingPathComponent:NSUUID.UUID.UUIDString] isDirectory:YES];
    PACrashStore *store = [[PACrashStore alloc] initWithDirectory:root];
    NSString *a = [@"a" stringByPaddingToLength:64 withString:@"a" startingAtIndex:0];
    NSString *b = [@"b" stringByPaddingToLength:64 withString:@"b" startingAtIndex:0];
    NSString *identity = @"11111111-1111-4111-8111-111111111111";
    NSDictionary *row = @{ @"id":identity, @"scope":a,
      @"time":@((long long)(NSDate.date.timeIntervalSince1970 * 1000)) };
    NSCAssert([store append:row error:nil], @"save before ack");
    NSCAssert([store append:row error:nil], @"same raw report idempotent");
    NSCAssert([store read:a error:nil].count == 1, @"one record");
    NSCAssert([store read:b error:nil].count == 0, @"account isolation");
    NSCAssert([store acknowledge:b ids:@[identity] error:nil], @"foreign ack harmless");
    NSCAssert([store read:a error:nil].count == 1, @"foreign ack cannot delete");
    store = [[PACrashStore alloc] initWithDirectory:root];
    NSCAssert([store read:a error:nil].count == 1, @"restart durable");
    NSCAssert([store acknowledge:a ids:@[identity] error:nil], @"ack");
    NSCAssert([store append:row error:nil], @"late raw reimport idempotent");
    NSCAssert([store read:a error:nil].count == 0, @"ack tombstone retained");
    NSCAssert([PACrashProjection safeToken:@"/private/token"] == nil, @"path redaction");
    NSCAssert([[PACrashProjection safeToken:@"iPhone15,2"] isEqual:@"iPhone15,2"], @"model");
    NSCAssert([PACrashProjection validScope:a] && ![PACrashProjection validScope:@"account@example.com"], @"hashed scope");
    PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc]
      initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeMach
      symbolicationStrategy:PLCrashReporterSymbolicationStrategyNone];
    PLCrashReporter *reporter = [[PLCrashReporter alloc] initWithConfiguration:config];
    NSString *runId = NSUUID.UUID.UUIDString.lowercaseString;
    reporter.customData = [NSJSONSerialization dataWithJSONObject:@{@"scope":a, @"runId":runId} options:0 error:nil];
    NSData *live = [reporter generateLiveReportAndReturnError:nil];
    NSCAssert(live != nil, @"real PLCrashReporter format without enabling crash handlers");
    PLCrashReport *parsed = [[PLCrashReport alloc] initWithData:live error:nil];
    NSDictionary *projected = [PACrashProjection project:parsed data:live];
    NSCAssert([projected[@"scope"] isEqual:a], @"crash account carried by report");
    NSCAssert([projected[@"platform"] isEqual:@"ios"], @"platform");
    NSCAssert([projected[@"iosCrash"][@"frames"] count] > 0, @"native frames retained");
    NSCAssert([projected[@"iosCrash"][@"schema"] integerValue] == 2, @"expanded crash schema");
    NSCAssert([projected[@"iosCrash"][@"runId"] isEqual:runId], @"run correlation survives crash format");
    NSCAssert([projected[@"iosCrash"][@"threadCount"] unsignedIntegerValue] == parsed.threads.count, @"all-thread count");
    NSCAssert(projected[@"iosCrash"][@"faultAddress"] != nil && projected[@"iosCrash"][@"signalCode"] != nil, @"signal evidence retained");
    NSCAssert([projected[@"id"] isEqual:[PACrashProjection project:parsed data:live][@"id"]], @"stable identity");
    NSCAssert(projected[@"iosCrash"][@"reason"] == nil, @"reason never exported");
    NSMutableDictionary *expired = [row mutableCopy];
    expired[@"id"] = NSUUID.UUID.UUIDString;
    expired[@"time"] = @((long long)((NSDate.date.timeIntervalSince1970 - 8 * 86400) * 1000));
    NSCAssert([store append:expired error:nil] && [store read:a error:nil].count == 0, @"seven day retention");
    for (NSUInteger index = 0; index < 40; index++) {
      NSMutableDictionary *next = [row mutableCopy]; next[@"id"] = NSUUID.UUID.UUIDString;
      NSCAssert([store append:next error:nil], @"bounded append");
    }
    NSCAssert([store read:a error:nil].count == 32, @"bounded queue");
    NSURL *badFile = [root URLByAppendingPathComponent:@"not-a-directory"];
    NSCAssert([[@"occupied" dataUsingEncoding:NSUTF8StringEncoding] writeToURL:badFile atomically:YES], @"fixture");
    PACrashStore *unavailable = [[PACrashStore alloc] initWithDirectory:badFile];
    NSCAssert(![unavailable append:row error:nil], @"IO failure is not success");
    [[NSFileManager defaultManager] removeItemAtURL:root error:nil];
    NSLog(@"iOS crash store/projection tests passed");
  }
}
