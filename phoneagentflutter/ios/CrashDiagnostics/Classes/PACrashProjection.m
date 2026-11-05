#import "PACrashProjection.h"
#import <CrashReporter/CrashReporter.h>
#import <CommonCrypto/CommonDigest.h>
#import <mach/machine.h>

@implementation PACrashProjection
+ (BOOL)validScope:(id)value {
    return [value isKindOfClass:NSString.class] &&
        [value rangeOfString:@"^[a-f0-9]{64}$" options:NSRegularExpressionSearch].location != NSNotFound;
}
+ (NSString *)safeToken:(id)value {
    if (![value isKindOfClass:NSString.class]) return nil;
    return [value rangeOfString:@"^[A-Za-z0-9_.+,()-]{1,96}$" options:NSRegularExpressionSearch].location != NSNotFound ? value : nil;
}
+ (NSString *)identity:(NSData *)data {
    unsigned char bytes[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(data.bytes, (CC_LONG)data.length, bytes);
    return [[NSUUID alloc] initWithUUIDBytes:bytes].UUIDString.lowercaseString;
}
+ (NSString *)imageUUID:(NSString *)value {
    if (value.length == 32) {
        value = [NSString stringWithFormat:@"%@-%@-%@-%@-%@", [value substringToIndex:8],
          [value substringWithRange:NSMakeRange(8, 4)], [value substringWithRange:NSMakeRange(12, 4)],
          [value substringWithRange:NSMakeRange(16, 4)], [value substringFromIndex:20]];
    }
    return [[NSUUID alloc] initWithUUIDString:value ?: @""].UUIDString.lowercaseString ?: @"unknown";
}
+ (NSDictionary *)frame:(PLCrashReportStackFrameInfo *)frame report:(PLCrashReport *)report
                 thread:(NSInteger)thread crashed:(BOOL)crashed {
    uint64_t pc = frame.instructionPointer;
    PLCrashReportBinaryImageInfo *image = [report imageForAddress:pc];
    uint64_t base = image ? image.imageBaseAddress : 0;
    return @{@"thread":@(thread), @"crashed":@(crashed),
        @"image":[self safeToken:image.imageName.lastPathComponent] ?: @"unknown",
        @"uuid":[self imageUUID:image.imageUUID],
        @"base":[NSString stringWithFormat:@"%llx", (unsigned long long)base],
        @"pc":[NSString stringWithFormat:@"%llx", (unsigned long long)pc],
        @"offset":[NSString stringWithFormat:@"%llx", (unsigned long long)(pc - base)]};
}
+ (NSDictionary *)project:(PLCrashReport *)report data:(NSData *)data {
    if (!report || !report.customData || report.customData.length > 1024) return nil;
    id metadata = [NSJSONSerialization JSONObjectWithData:report.customData options:0 error:nil];
    if (![metadata isKindOfClass:NSDictionary.class] || ![self validScope:metadata[@"scope"]]) return nil;
    NSMutableArray *frames = [NSMutableArray new];
    NSUInteger count = 0;
    // ObjC exception origin precedes the later SIGABRT stack.
    for (PLCrashReportStackFrameInfo *frame in report.exceptionInfo.stackFrames) {
        count++;
        if (frames.count < 48) [frames addObject:[self frame:frame report:report thread:-1 crashed:YES]];
    }
    for (NSNumber *crashed in @[@YES, @NO]) {
        for (PLCrashReportThreadInfo *thread in report.threads) {
            if (thread.crashed != crashed.boolValue || thread.threadNumber < 0 || thread.threadNumber > 65535) continue;
            NSUInteger limit = MIN(frames.count + (thread.crashed ? 64 : 32), 1024);
            for (PLCrashReportStackFrameInfo *frame in thread.stackFrames) {
                count++;
                if (frames.count < limit) [frames addObject:[self frame:frame report:report
                    thread:thread.threadNumber crashed:thread.crashed]];
            }
        }
    }
    NSArray *exceptions = @[@"NSInvalidArgumentException", @"NSRangeException", @"NSInternalInconsistencyException",
        @"NSGenericException", @"NSMallocException", @"NSInvalidUnarchiveOperationException"];
    NSString *exception = [exceptions containsObject:report.exceptionInfo.exceptionName ?: @""] ? report.exceptionInfo.exceptionName : @"other";
    NSArray *signals = @[@"SIGABRT", @"SIGBUS", @"SIGFPE", @"SIGILL", @"SIGSEGV", @"SIGTRAP", @"SIGSYS"];
    NSString *signal = [signals containsObject:report.signalInfo.name ?: @""] ? report.signalInfo.name : @"other";
    uint64_t cpu = report.machineInfo.processorInfo.type;
    NSString *architecture = cpu == CPU_TYPE_ARM64 ? @"arm64" : cpu == CPU_TYPE_X86_64 ? @"x86_64" : @"unknown";
    NSString *run = [[NSUUID alloc] initWithUUIDString:metadata[@"runId"] ?: @""].UUIDString.lowercaseString ?: @"unknown";
    NSDictionary *details = @{@"schema":@2, @"signal":signal, @"exception":exception,
        @"runId":run, @"signalCode":[self safeToken:report.signalInfo.code] ?: @"unknown",
        @"faultAddress":[NSString stringWithFormat:@"%llx", (unsigned long long)report.signalInfo.address],
        @"threadCount":@(report.threads.count), @"frameCount":@(count),
        @"appVersion":[self safeToken:report.applicationInfo.applicationMarketingVersion] ?: @"unknown",
        @"appBuild":[self safeToken:report.applicationInfo.applicationVersion] ?: @"unknown",
        @"osVersion":[self safeToken:report.systemInfo.operatingSystemVersion] ?: @"unknown",
        @"deviceModel":[self safeToken:report.machineInfo.modelName] ?: @"unknown",
        @"architecture":architecture, @"frames":frames, @"truncated":@(count > frames.count)};
    NSTimeInterval timestamp = report.systemInfo.timestamp.timeIntervalSince1970;
    if (timestamp < 946684800 || timestamp > 4102444800) return nil;
    return @{@"id":[self identity:data], @"scope":metadata[@"scope"], @"platform":@"ios",
        @"time":@((long long)(timestamp * 1000)), @"mainThread":@NO, @"kind":@"other", @"iosCrash":details};
}
@end
