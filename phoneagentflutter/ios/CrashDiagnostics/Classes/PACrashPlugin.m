#import "PACrashPlugin.h"
#import "PACrashStore.h"
#import "PACrashProjection.h"
#import "PAIdentityTrace.h"
#import "PACrashAccountBinding.h"
#import <CrashReporter/CrashReporter.h>
#import <sys/sysctl.h>
#import <unistd.h>

@interface PACrashPlugin ()
@property(nonatomic, strong) PLCrashReporter *reporter;
@property(nonatomic, strong) PACrashStore *store;
@property(nonatomic, strong) dispatch_queue_t queue;
@property(nonatomic, assign) BOOL enabled;
@property(nonatomic, strong) PACrashAccountBinding *binding;
@end

@implementation PACrashPlugin
+ (instancetype)shared {
    static PACrashPlugin *instance;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        instance = [PACrashPlugin new];
        instance.binding = [PACrashAccountBinding new];
        instance.queue = dispatch_queue_create("phoneagent.crash-diagnostics", DISPATCH_QUEUE_SERIAL);
        dispatch_async(instance.queue, ^{ [instance initializeReporter]; });
    });
    return instance;
}
+ (void)start { [self shared]; }
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"phone_agent/native_crash"
        binaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:[self shared] channel:channel];
}
- (void)initializeReporter {
    @try {
        // Mach exception capture must not compete with LLDB while debugging.
        struct kinfo_proc process = {0}; size_t length = sizeof(process);
        int query[] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, getpid()};
        if (sysctl(query, 4, &process, &length, NULL, 0) == 0 && (process.kp_proc.p_flag & P_TRACED)) return;
        NSFileManager *files = NSFileManager.defaultManager;
        NSURL *support = [files URLForDirectory:NSApplicationSupportDirectory inDomain:NSUserDomainMask
            appropriateForURL:nil create:YES error:nil];
        if (!support) return;
        NSURL *directory = [support URLByAppendingPathComponent:@"native-crashes-v1" isDirectory:YES];
        if (![files createDirectoryAtURL:directory withIntermediateDirectories:YES
            attributes:@{NSFileProtectionKey:NSFileProtectionCompleteUntilFirstUserAuthentication} error:nil]) return;
        if (![directory setResourceValue:@YES forKey:NSURLIsExcludedFromBackupKey error:nil]) return;
        self.store = [[PACrashStore alloc] initWithDirectory:directory];
        PLCrashReporterConfig *config = [[PLCrashReporterConfig alloc]
            initWithSignalHandlerType:PLCrashReporterSignalHandlerTypeMach
            symbolicationStrategy:PLCrashReporterSymbolicationStrategyNone
            shouldRegisterUncaughtExceptionHandler:YES basePath:directory.path maxReportBytes:1024 * 1024];
        self.reporter = [[PLCrashReporter alloc] initWithConfiguration:config];
        [self recoverAndEnable];
    } @catch (NSException *exception) {
        // Diagnostics failure must not change startup or authentication.
    }
}
- (BOOL)recoverAndEnable {
    if (!self.reporter || !self.store) return NO;
    if (!self.enabled && self.reporter.hasPendingCrashReport) {
        NSData *data = [self.reporter loadPendingCrashReportDataAndReturnError:nil];
        if (!data || data.length > 1024 * 1024) return NO;
        PLCrashReport *report = [[PLCrashReport alloc] initWithData:data error:nil];
        if (!report) return NO; // Do not overwrite an unread report.
        NSDictionary *row = [PACrashProjection project:report data:data];
        // Unbound startup reports cannot be attributed to a later account.
        if (row && ![self.store append:row error:nil]) return NO;
        if (![self.reporter purgePendingCrashReportAndReturnError:nil]) return NO;
    }
    if (!self.enabled) {
        self.enabled = [self.reporter enableCrashReporterAndReturnError:nil];
        if (self.enabled) {
            PLCrashReporter *ready = self.reporter;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self.binding publish:(id<PACrashMetadataSink>)ready];
            });
        }
    }
    return self.enabled;
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : @{};
    id rawScope = args[@"scope"];
    NSString *scope = [PACrashProjection validScope:rawScope] ? rawScope : nil;
    BOOL clearBinding = [call.method isEqualToString:@"bind"] && (!rawScope || rawScope == NSNull.null);
    if (!scope && !clearBinding) {
        result([FlutterError errorWithCode:@"crash_invalid_scope" message:@"Invalid diagnostic scope" details:nil]); return;
    }
    // Enqueue scope changes at channel receipt, before later capture events.
    // The crash IO queue may be busy; never make trace ownership wait for it.
    if ([call.method isEqualToString:@"bind"]) {
        @try {
            [PAIdentityTrace bind:scope];
            // Single main-thread setter owner, after enable. Never wait for IO
            // or let a delayed IO operation restore an earlier account.
            [self.binding bindScope:scope run:PAIdentityTrace.runId];
        }
        @catch (NSException *exception) { /* Optional observation cannot block login. */ }
    }
    dispatch_async(self.queue, ^{
        id response = nil;
        @try {
            // A locked/protected store can be retried after first unlock.
            if (!self.reporter) [self initializeReporter];
            if ([call.method isEqualToString:@"bind"]) {
                if (![self recoverAndEnable]) {
                    [PAIdentityTrace record:@"recorder.unavailable" session:nil actor:nil flags:0 code:0];
                    response = [self unavailable];
                } else if (scope) {
                    [PAIdentityTrace record:@"recorder.ready" session:nil actor:nil flags:0 code:0];
                }
            } else if ([call.method isEqualToString:@"read"]) {
                [self recoverAndEnable];
                NSArray *crashes = [self.store read:scope error:nil];
                if (crashes.count > 4) crashes = [crashes subarrayWithRange:NSMakeRange(0, 4)];
                NSArray *traces = [PAIdentityTrace read:scope];
                // Keep each channel independently usable if the other store fails.
                response = crashes || traces ? [(crashes ?: @[]) arrayByAddingObjectsFromArray:traces ?: @[]] : [self unavailable];
            } else if ([call.method isEqualToString:@"acknowledge"]) {
                id ids = args[@"ids"];
                BOOL valid = [ids isKindOfClass:NSArray.class] && [ids count] <= 32;
                if (valid) for (id value in ids) {
                    if (![value isKindOfClass:NSString.class] || ![[NSUUID alloc] initWithUUIDString:value]) { valid = NO; break; }
                }
                if (!valid) response = [self unavailable];
                else {
                    BOOL crashSaved = !self.store || [self.store acknowledge:scope ids:ids error:nil];
                    BOOL traceSaved = [PAIdentityTrace acknowledge:scope ids:ids];
                    if (!crashSaved || !traceSaved) response = [self unavailable];
                }
            } else response = FlutterMethodNotImplemented;
        } @catch (NSException *exception) { response = [self unavailable]; }
        dispatch_async(dispatch_get_main_queue(), ^{ result(response); });
    });
}
- (FlutterError *)unavailable {
    return [FlutterError errorWithCode:@"crash_storage_unavailable"
        message:@"Native diagnostics temporarily unavailable" details:nil];
}
@end
