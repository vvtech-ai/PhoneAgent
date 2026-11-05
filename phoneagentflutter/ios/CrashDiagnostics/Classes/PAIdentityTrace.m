#import "PAIdentityTrace.h"
#import "PAIdentityTraceStore.h"
#import "PAIdentityTraceScope.h"
#import "PACrashProjection.h"
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>
#import <mach-o/dyld.h>
#import <mach-o/loader.h>
#import <mach/mach_time.h>
#import <pthread.h>
#import <stdatomic.h>
#import <sys/utsname.h>

@interface PAIdentityTrace () {
    atomic_uint _pending, _dropped, _failures, _unbound;
}
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, strong) PAIdentityTraceStore *store;
@property(nonatomic, strong) PAIdentityTraceScope *scope;
@property(nonatomic, strong) NSDictionary *context;
@property(nonatomic) uint64_t sequence;
@end

@implementation PAIdentityTrace
+ (instancetype)shared {
    static PAIdentityTrace *instance; static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [PAIdentityTrace new];
        atomic_init(&instance->_pending, 0); atomic_init(&instance->_dropped, 0);
        atomic_init(&instance->_failures, 0); atomic_init(&instance->_unbound, 0);
        instance.queue = dispatch_queue_create("phoneagent.identity-diagnostics", DISPATCH_QUEUE_SERIAL);
        instance.scope = [PAIdentityTraceScope new];
        struct utsname machine; NSString *model = uname(&machine) == 0 ? [NSString stringWithUTF8String:machine.machine] : @"unknown";
        instance.context = @{@"schema":@1, @"runId":NSUUID.UUID.UUIDString.lowercaseString,
            @"runnerUUID":[self runnerUUID], @"configuredSdk":@"2.3.50",
            @"appVersion":[PACrashProjection safeToken:[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"]] ?: @"unknown",
            @"appBuild":[PACrashProjection safeToken:[NSBundle.mainBundle objectForInfoDictionaryKey:@"CFBundleVersion"]] ?: @"unknown",
            @"osVersion":[PACrashProjection safeToken:UIDevice.currentDevice.systemVersion] ?: @"unknown",
            @"deviceModel":[PACrashProjection safeToken:model] ?: @"unknown"};
        NSURL *support = [NSFileManager.defaultManager URLsForDirectory:NSApplicationSupportDirectory inDomains:NSUserDomainMask].firstObject;
        if (support) instance.store = [[PAIdentityTraceStore alloc] initWithDirectory:
            [support URLByAppendingPathComponent:@"identity-trace-v1" isDirectory:YES]];
    });
    return instance;
}
+ (NSString *)runnerUUID {
    const struct mach_header *header = _dyld_get_image_header(0);
    if (!header || header->magic != MH_MAGIC_64) return @"unknown";
    const struct mach_header_64 *wide = (const struct mach_header_64 *)header;
    const uint8_t *cursor = (const uint8_t *)(wide + 1);
    const uint8_t *end = cursor + wide->sizeofcmds;
    for (uint32_t i = 0; i < wide->ncmds && cursor + sizeof(struct load_command) <= end; i++) {
        const struct load_command *command = (const struct load_command *)cursor;
        if (command->cmdsize < sizeof(*command) || command->cmdsize > (size_t)(end - cursor)) break;
        if (command->cmd == LC_UUID && command->cmdsize >= sizeof(struct uuid_command)) {
            return [[NSUUID alloc] initWithUUIDBytes:((const struct uuid_command *)command)->uuid].UUIDString.lowercaseString;
        }
        cursor += command->cmdsize;
    }
    return @"unknown";
}
+ (NSString *)runId { return [self shared].context[@"runId"]; }
+ (void)bind:(NSString *)scope {
    PAIdentityTrace *trace = [self shared];
    dispatch_async(trace.queue, ^{ [trace.scope bind:scope]; });
}
+ (void)record:(NSString *)event session:(NSString *)session actor:(NSString *)actor flags:(NSUInteger)flags code:(NSInteger)code {
    @try {
        if (![PACrashProjection safeToken:event]) return;
        PAIdentityTrace *trace = [self shared];
        uint64_t thread = 0; pthread_threadid_np(NULL, &thread);
        mach_timebase_info_data_t timebase; mach_timebase_info(&timebase);
        uint64_t micros = (uint64_t)((long double)mach_continuous_time() * timebase.numer / timebase.denom / 1000);
        NSMutableDictionary *row = [@{@"event":event,
            @"time":@((long long)(NSDate.date.timeIntervalSince1970 * 1000)), @"monotonicUs":@(micros),
            @"thread":[NSString stringWithFormat:@"%llu", (unsigned long long)thread], @"main":@(NSThread.isMainThread),
            @"session":[PAIdentityTraceScope identityForSession:session],
            @"actor":[[NSUUID alloc] initWithUUIDString:actor ?: @""].UUIDString.lowercaseString ?: @"",
            @"flags":@(flags & 255), @"code":@(MAX(INT32_MIN, MIN(INT32_MAX, code)))} mutableCopy];
        AVAudioSession *audio = AVAudioSession.sharedInstance;
        row[@"category"] = [PACrashProjection safeToken:audio.category] ?: @"unknown";
        row[@"mode"] = [PACrashProjection safeToken:audio.mode] ?: @"unknown";
        row[@"sampleRate"] = @((NSInteger)MAX(0, MIN(384000, audio.sampleRate)));
        row[@"inputs"] = [self ports:audio.currentRoute.inputs];
        row[@"outputs"] = [self ports:audio.currentRoute.outputs];
        if (atomic_fetch_add(&trace->_pending, 1) >= 256) {
            atomic_fetch_sub(&trace->_pending, 1); atomic_fetch_add(&trace->_dropped, 1); return;
        }
        dispatch_async(trace.queue, ^{
            @try { [trace persist:row]; }
            @catch (NSException *exception) { atomic_fetch_add(&trace->_failures, 1); }
            @finally { atomic_fetch_sub(&trace->_pending, 1); }
        });
    } @catch (NSException *exception) { /* Observation never changes the business result. */ }
}
+ (NSArray *)ports:(NSArray<AVAudioSessionPortDescription *> *)ports {
    NSMutableArray *result = [NSMutableArray new];
    for (AVAudioSessionPortDescription *port in ports) {
        [result addObject:[PACrashProjection safeToken:port.portType] ?: @"unknown"];
        if (result.count == 8) break;
    }
    return result; // No device names, UIDs, or audio contents.
}
- (void)persist:(NSMutableDictionary *)row {
    mach_timebase_info_data_t timebase; mach_timebase_info(&timebase);
    uint64_t micros = (uint64_t)((long double)mach_continuous_time() * timebase.numer / timebase.denom / 1000);
    row[@"queueLagUs"] = @(micros - [row[@"monotonicUs"] unsignedLongLongValue]);
    // A late callback stays with the scope that first prepared this session.
    NSString *scope = [_scope resolve:row[@"event"] session:row[@"session"]];
    if (![PACrashProjection validScope:scope]) { atomic_fetch_add(&_unbound, 1); return; }
    row[@"seq"] = @(++_sequence);
    NSMutableDictionary *context = [_context mutableCopy];
    context[@"dropped"] = @(atomic_load(&_dropped));
    context[@"writeFailures"] = @(atomic_load(&_failures));
    context[@"unbound"] = @(atomic_load(&_unbound));
    if (![_store append:row context:context scope:scope]) atomic_fetch_add(&_failures, 1);
}
+ (NSArray<NSDictionary *> *)read:(NSString *)scope {
    PAIdentityTrace *trace = [self shared]; __block NSArray *rows;
    dispatch_sync(trace.queue, ^{ rows = [trace.store read:scope]; });
    return rows;
}
+ (BOOL)acknowledge:(NSString *)scope ids:(NSArray<NSString *> *)ids {
    PAIdentityTrace *trace = [self shared]; __block BOOL done;
    dispatch_sync(trace.queue, ^{ done = [trace.store acknowledge:scope ids:ids]; });
    return done;
}
@end
