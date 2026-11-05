#import "IdentityCapturePlugin.h"
#import "IdentityCaptureAudioConfiguration.h"
#import "IdentityCaptureLoadingController.h"
#import "ClonePreviewAudioSession.h"
#import "IdentityCaptureTrace.h"
#import <PhoneAgentCrashDiagnostics/PAIdentityTrace.h>
#import <AliyunFaceAuthFacade/AliyunFaceAuthFacade.h>
#import <SystemConfiguration/SystemConfiguration.h>
#import <UIKit/UIKit.h>
#import <netinet/in.h>
#import <sys/utsname.h>

@interface IdentityCapturePlugin ()
@property(nonatomic, weak) UIViewController *host;
@property(nonatomic, strong) UIViewController *captureHost;
@property(nonatomic, strong) IdentityCaptureAudioConfiguration *audioConfiguration;
@property(nonatomic, copy) NSString *session;
@property(nonatomic, copy) NSString *meta;
@property(nonatomic, copy) FlutterResult pending;
@property(nonatomic, assign) BOOL inFlight;
@property(nonatomic, assign) BOOL cancelled;
@property(nonatomic, assign) BOOL detached;
@property(nonatomic, assign) BOOL finishing;
@property(nonatomic, strong) NSMutableArray *releaseWaiters;
@property(nonatomic, assign) BOOL dismissing;
@property(nonatomic, strong) NSMutableArray *dismissWaiters;
@property(nonatomic, copy) NSString *traceIdentity;
@property(nonatomic, strong) IdentityCaptureTrace *traceObserver;
@end

// Main-queue ownership survives engine teardown until the SDK actually finishes.
static IdentityCapturePlugin *captureOwner;

@implementation IdentityCapturePlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [self registerWithRegistrar:registrar host:nil];
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar host:(UIViewController *)host {
    IdentityCapturePlugin *plugin = [IdentityCapturePlugin new];
    plugin.traceIdentity = NSUUID.UUID.UUIDString.lowercaseString;
    plugin.releaseWaiters = [NSMutableArray new];
    plugin.dismissWaiters = [NSMutableArray new];
    plugin.host = host;
    FlutterMethodChannel *channel = [FlutterMethodChannel methodChannelWithName:@"phone_agent/identity_capture"
        binaryMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:plugin channel:channel];
    // Do not initialize the vendor SDK during registration or app startup.
}

- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqualToString:@"preparePreviewAudio"]) {
        NSString *previewTrace = NSUUID.UUID.UUIDString;
        [self note:@"preview.prepare" session:previewTrace code:0];
        if (self.detached || captureOwner) { [self busy:result]; return; }
        __weak IdentityCapturePlugin *weakSelf = self;
        NSString *actor = self.traceIdentity;
        [ClonePreviewAudioSession prepareWithResult:^(id reply) {
            [PAIdentityTrace record:@"preview.result" session:previewTrace actor:actor flags:0 code:reply ? 1 : 0];
            result(reply);
        } canPrepare:^BOOL {
            IdentityCapturePlugin *owner = weakSelf;
            return owner && !owner.detached && !captureOwner;
        }];
        return;
    }
    NSDictionary *args = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : nil;
    NSString *session = [args[@"session"] isKindOfClass:NSString.class] ? args[@"session"] : nil;
    if (self.detached || ![self validSession:session]) { [self unavailable:result]; return; }
    if ([call.method isEqualToString:@"prepare"]) {
        [self prepare:session result:result];
    } else if ([call.method isEqualToString:@"capture"]) {
        NSString *certify = [args[@"certifyId"] isKindOfClass:NSString.class] ? args[@"certifyId"] : nil;
        [self capture:session certify:certify result:result];
    } else if ([call.method isEqualToString:@"abort"]) {
        [self abort:session]; result(nil);
    } else if ([call.method isEqualToString:@"waitForRelease"]) {
        if (captureOwner == self && [self.session isEqualToString:session]) {
            [self note:@"release.wait" session:session code:0];
            [self.releaseWaiters addObject:[result copy]];
        } else { [self note:@"release.immediate" session:session code:0]; result(nil); }
    } else { result(FlutterMethodNotImplemented); }
}

- (BOOL)validSession:(NSString *)session {
    return session && [session rangeOfString:@"^[A-Za-z0-9_-]{1,128}$" options:NSRegularExpressionSearch].location != NSNotFound;
}
- (void)prepare:(NSString *)session result:(FlutterResult)result {
    [self note:@"prepare.enter" session:session code:0];
    if (captureOwner == self && [self.session isEqualToString:session] && self.meta && !self.inFlight) {
        [self note:@"prepare.cached" session:session code:0]; result(self.meta); return;
    }
    if (captureOwner) { [self busy:result]; return; }
    captureOwner = self; self.session = session; self.cancelled = NO;
    @try { self.traceObserver = [[IdentityCaptureTrace alloc] initWithSession:session actor:self.traceIdentity]; }
    @catch (NSException *exception) { /* Optional observation cannot block SDK preparation. */ }
    [self note:@"prepare.claimed" session:session code:0];
    @try {
        [self note:@"sdk.init.enter" session:session code:0];
        [AliyunFaceAuthFacade initSDK];
        [self note:@"sdk.init.exit" session:session code:0];
        [self note:@"sdk.meta.enter" session:session code:0];
        NSDictionary *meta = [AliyunFaceAuthFacade getMetaInfo];
        [self note:@"sdk.meta.exit" session:session code:0];
        if (![NSJSONSerialization isValidJSONObject:meta]) { [self reset]; [self unavailable:result]; return; }
        NSData *data = [NSJSONSerialization dataWithJSONObject:meta options:0 error:nil];
        self.meta = data ? [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] : nil;
        if (self.meta.length == 0) { [self reset]; [self unavailable:result]; return; }
        [self note:@"prepare.ready" session:session code:0]; result(self.meta);
    } @catch (NSException *exception) { [self note:@"sdk.exception" session:session code:1]; [self reset]; [self unavailable:result]; }
}

- (void)capture:(NSString *)session certify:(NSString *)certify result:(FlutterResult)result {
    [self note:@"capture.enter" session:session code:0];
    if (captureOwner != self || ![self.session isEqualToString:session] || !self.meta || self.inFlight) {
        [self busy:result]; return;
    }
    if (!certify.length || certify.length > 4096 || !self.host.view.window || self.host.presentedViewController) {
        [self unavailable:result]; return;
    }
    self.pending = result; self.inFlight = YES;
    [self note:@"capture.accepted" session:session code:0];
    UIViewController *container = [IdentityCaptureLoadingController new];
    container.view.backgroundColor = UIColor.systemBackgroundColor;
    container.modalPresentationStyle = UIModalPresentationFullScreen;
    container.modalInPresentation = YES;
    self.captureHost = container;
    [self.host presentViewController:container animated:YES completion:^{
        [self note:@"container.presented" session:session code:0];
        if (self.cancelled || self.detached) { [self finish:nil error:nil]; return; }
        [self requestPermissions:^(BOOL granted) {
            [self note:@"permissions.result" session:session code:granted ? 1 : 0];
            if (self.cancelled || self.detached) { [self finish:nil error:nil]; return; }
            if (!granted) {
                [self finish:nil error:[FlutterError errorWithCode:@"capture_unavailable"
                    message:@"Camera and microphone permission required" details:nil]];
                return;
            }
            self.audioConfiguration = [[IdentityCaptureAudioConfiguration alloc]
                initWithSession:(id<IdentityCaptureAudioSession>)AVAudioSession.sharedInstance];
            NSError *audioError = nil;
            [self note:@"audio.prepare.enter" session:session code:0];
            if (![self.audioConfiguration prepare:&audioError]) {
                [self note:@"audio.prepare.exit" session:session code:audioError ? audioError.code : -1];
                [self finish:nil error:[FlutterError errorWithCode:@"capture_unavailable"
                    message:@"Identity audio preparation failed" details:nil]];
                return;
            }
            [self note:@"audio.prepare.exit" session:session code:0];
            @try {
                NSDictionary *params = @{@"currentCtr": container,
                    @"ext_params_key_use_video": @"false", @"ext_params_key_open_fullscreen": @"false",
                    @"ext_params_key_screen_orientation": @"ext_params_val_screen_port"};
                NSString *traceActor = self.traceIdentity;
                [self note:@"sdk.verify.enter" session:session code:0];
                [AliyunFaceAuthFacade verifyWith:certify extParams:params onCompletion:^(ZIMResponse *response) {
                    // Capture the original callback thread without reading plugin state off main.
                    [PAIdentityTrace record:@"sdk.callback" session:session actor:traceActor flags:0 code:0];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        if (captureOwner != self || ![self.session isEqualToString:session]) {
                            [self note:@"sdk.callback.stale" session:session code:0]; return;
                        }
                        NSMutableDictionary *payload = [[self environment] mutableCopy];
                        payload[@"code"] = response ? @(response.code) : @(-1);
                        [self note:@"sdk.callback.main" session:session code:[payload[@"code"] integerValue]];
                        // Keep only a diagnostic token, never images/deviceToken/bizData/raw reason.
                        payload[@"reason"] = [self subCode:response];
                        [self finish:payload error:nil];
                    });
                }];
                [self note:@"sdk.verify.return" session:session code:0];
            } @catch (NSException *exception) {
                [self note:@"sdk.exception" session:session code:2];
                [self finish:nil error:[FlutterError errorWithCode:@"capture_unavailable"
                    message:@"Identity capture failed" details:nil]];
            }
        }];
    }];
}

// Permission prompts are part of explicit capture, never registration/MetaInfo.
- (void)requestPermissions:(void (^)(BOOL))completion {
    [self note:@"permissions.enter" session:self.session code:0];
    void (^microphone)(void) = ^{
        if (self.cancelled || self.detached) { completion(NO); return; }
        AVAudioSession *session = AVAudioSession.sharedInstance;
        if (session.recordPermission == AVAudioSessionRecordPermissionGranted) {
            completion(YES);
        } else if (session.recordPermission == AVAudioSessionRecordPermissionDenied) {
            completion(NO);
        } else {
            [session requestRecordPermission:^(BOOL granted) {
                dispatch_async(dispatch_get_main_queue(), ^{ completion(granted); });
            }];
        }
    };
    AVAuthorizationStatus camera = [AVCaptureDevice authorizationStatusForMediaType:AVMediaTypeVideo];
    if (camera == AVAuthorizationStatusAuthorized) { microphone(); }
    else if (camera != AVAuthorizationStatusNotDetermined) { completion(NO); }
    else {
        [AVCaptureDevice requestAccessForMediaType:AVMediaTypeVideo completionHandler:^(BOOL granted) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (granted) microphone(); else completion(NO);
            });
        }];
    }
}

- (void)finish:(NSDictionary *)payload error:(FlutterError *)error {
    [self note:@"finish.enter" session:self.session code:error ? 1 : 0];
    if (self.finishing) { [self note:@"finish.duplicate" session:self.session code:0]; return; }
    self.finishing = YES;
    void (^complete)(void) = ^{
        FlutterResult reply = self.cancelled || self.detached ? nil : self.pending;
        [self note:@"finish.reply" session:self.session code:reply ? 1 : 0];
        [self reset];
        if (reply) reply(error ?: payload);
    };
    [self closeContainer:complete];
}
- (void)closeContainer:(void (^)(void))completion {
    [self note:@"container.close" session:self.session code:0];
    if (self.dismissing) {
        [self.dismissWaiters addObject:[completion copy]];
        return;
    }
    UIViewController *container = self.captureHost;
    if (!container.presentingViewController) { completion(); return; }
    self.dismissing = YES;
    [self.dismissWaiters addObject:[completion copy]];
    [container dismissViewControllerAnimated:NO completion:^{
        self.dismissing = NO;
        [self note:@"container.closed" session:self.session code:0];
        NSArray *waiters = [self.dismissWaiters copy];
        [self.dismissWaiters removeAllObjects];
        for (void (^done)(void) in waiters) { done(); }
    }];
}
- (void)abort:(NSString *)session {
    [self note:@"abort.enter" session:session code:0];
    if (captureOwner != self || ![self.session isEqualToString:session]) {
        [self note:@"abort.stale" session:session code:0]; return;
    }
    self.cancelled = YES; self.meta = nil;
    [self note:@"abort.accepted" session:session code:0];
    FlutterResult reply = self.pending; self.pending = nil;
    if (reply) reply([FlutterError errorWithCode:@"capture_cancelled" message:@"Identity capture cancelled" details:nil]);
    if (!self.finishing) [self closeContainer:^{}];
    // No public vendor abort API. Never pretend cancellation has released the
    // camera or admit another capture while an old vendor operation is running.
    if (!self.inFlight) [self reset];
}
- (void)reset {
    NSString *previousSession = self.session;
    [self note:@"reset.enter" session:previousSession code:0];
    @try { [self.traceObserver stop]; self.traceObserver = nil; }
    @catch (NSException *exception) { /* Observation cannot block audio/session release. */ }
    [self.audioConfiguration releaseAfterCapture];
    self.audioConfiguration = nil;
    self.pending = nil; self.meta = nil; self.session = nil; self.captureHost = nil;
    self.inFlight = NO;
    self.finishing = NO;
    if (captureOwner == self) captureOwner = nil;
    [self note:@"reset.exit" session:previousSession code:0];
    NSArray *waiters = [self.releaseWaiters copy];
    [self.releaseWaiters removeAllObjects];
    for (FlutterResult reply in waiters) { reply(nil); }
}
- (NSDictionary *)environment {
    struct utsname info; NSString *model = uname(&info) == 0 ? [NSString stringWithUTF8String:info.machine] : @"unknown";
    struct sockaddr_in address = {0}; address.sin_len = sizeof(address); address.sin_family = AF_INET;
    SCNetworkReachabilityRef reachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&address);
    SCNetworkReachabilityFlags flags = 0;
    BOOL reachable = reachability && SCNetworkReachabilityGetFlags(reachability, &flags)
        && (flags & kSCNetworkReachabilityFlagsReachable) && !(flags & kSCNetworkReachabilityFlagsConnectionRequired);
    if (reachability) CFRelease(reachability);
    NSString *network = !reachable ? @"NONE" : (flags & kSCNetworkReachabilityFlagsIsWWAN) ? @"CELLULAR" : @"WIFI";
    // Reachability does not prove validated Internet connectivity on iOS.
    return @{@"deviceModel": model ?: @"unknown", @"networkType": network, @"networkValidated": @NO};
}
- (NSString *)subCode:(ZIMResponse *)response {
    NSString *reason = [NSString stringWithFormat:@"%@ %@", response.retCodeSub ?: @"", response.reason ?: @""];
    NSRegularExpression *pattern = [NSRegularExpression regularExpressionWithPattern:@"(?<![A-Z0-9_])[ZA]\\d{4}(?:_\\d+)?(?![A-Z0-9_])" options:0 error:nil];
    NSString *text = reason.uppercaseString;
    NSTextCheckingResult *match = [pattern firstMatchInString:text options:0 range:NSMakeRange(0, text.length)];
    return match ? [text substringWithRange:match.range] : @"";
}
- (void)busy:(FlutterResult)result { [self note:@"busy" session:self.session code:0]; result([FlutterError errorWithCode:@"capture_busy" message:@"Identity capture is busy" details:nil]); }
- (void)unavailable:(FlutterResult)result { [self note:@"unavailable" session:self.session code:0]; result([FlutterError errorWithCode:@"capture_unavailable" message:@"Identity capture unavailable" details:nil]); }
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [self note:@"engine.detach" session:self.session code:0];
    self.detached = YES; [self abort:self.session];
}
- (void)note:(NSString *)event session:(NSString *)session code:(NSInteger)code {
    NSUInteger flags = (captureOwner == self ? 1 : 0) | (self.inFlight ? 2 : 0) |
        (self.cancelled ? 4 : 0) | (self.detached ? 8 : 0) | (self.finishing ? 16 : 0) |
        (self.dismissing ? 32 : 0) | (self.captureHost ? 64 : 0) | (self.pending ? 128 : 0);
    [PAIdentityTrace record:event session:session actor:self.traceIdentity flags:flags code:code];
}
- (void)dealloc {
    [PAIdentityTrace record:@"plugin.dealloc" session:self.session actor:self.traceIdentity flags:0 code:0];
}
@end
