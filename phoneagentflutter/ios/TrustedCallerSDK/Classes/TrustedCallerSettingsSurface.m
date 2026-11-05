#import "TrustedCallerSettingsSurface.h"
#import "TrustedIdentityOverlaySurface.h"
#import "TrustedCallerNativeIntroduction.h"
#import "TrustedCallerPhoneNumber.h"
#import "TrustedCallerSdkClient.h"
#import "TrustedCallerPushRegistration.h"
#import "TrustedCallerSDKAvailability.h"
#import <CommonCrypto/CommonDigest.h>
#import <TargetConditionals.h>
#if !TARGET_OS_SIMULATOR
#import <KXSDK/KXSSDK-Swift.h>
#endif

@interface TrustedCallerDismissProxy : NSObject <UIAdaptivePresentationControllerDelegate
#if !TARGET_OS_SIMULATOR
    , KXSetViewControllerDelete
#endif
>
@property (nonatomic, copy, nullable) dispatch_block_t onExit;
@end
@implementation TrustedCallerDismissProxy
- (void)presentationControllerDidDismiss:(UIPresentationController *)presentationController {
    if (self.onExit) self.onExit();
}
- (void)dissSetViewControllerClick { if (self.onExit) self.onExit(); }
@end

@interface TrustedCallerSettingsSurface ()
@property (nonatomic, weak) UIViewController *host;
@property (nonatomic, strong) TrustedIdentityOverlaySurface *identityOverlay;
@property (nonatomic, strong, nullable) TrustedCallerSurfaceOwner *owner;
@property (nonatomic, strong, nullable) TrustedCallerSurfaceOwner *accountOwner;
@property (nonatomic) BOOL ready;
@property (nonatomic, strong) NSMutableArray<TrustedCallerSurfaceRequest *> *pending;
@property (nonatomic, strong, nullable) TrustedCallerSurfaceRequest *openRequest;
@property (nonatomic, strong, nullable) UINavigationController *navigation;
@property (nonatomic, strong, nullable) TrustedCallerDismissProxy *dismissProxy;
@end

@implementation TrustedCallerSettingsSurface
- (instancetype)initWithHost:(UIViewController *)host {
    if ((self = [super init])) { _host = host; _pending = [NSMutableArray array]; }
    return self;
}
- (void)configureIdentityOverlayWithMessenger:(NSObject<FlutterBinaryMessenger> *)messenger {
    __weak typeof(self) weakSelf = self;
    self.identityOverlay = [[TrustedIdentityOverlaySurface alloc] initWithMessenger:messenger
        presenter:^UIViewController * { return weakSelf.navigation; }
        acceptsOwner:^BOOL(NSDictionary *metadata) {
            TrustedCallerSettingsSurface *surface = weakSelf;
            return surface.accountOwner &&
                [surface.accountOwner matchesAccountMetadata:metadata] &&
                (!surface.owner || [surface.owner matchesAccountMetadata:metadata]);
        }];
}
- (void)updateAccount:(NSDictionary *)account {
    NSMutableDictionary *arguments = account.mutableCopy;
    arguments[@"surfaceToken"] = @"aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
    self.accountOwner = [TrustedCallerSurfaceOwner ownerFromArguments:arguments];
    if (self.owner && ![self.owner matchesAccountMetadata:self.accountOwner.metadata]) [self close];
}
- (TrustedCallerSurfaceRequest *)request:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    TrustedCallerSurfaceRequest *request = [[TrustedCallerSurfaceRequest alloc] initWithOwner:owner reply:reply];
    [self.pending addObject:request];
    return request;
}
- (void)finish:(TrustedCallerSurfaceRequest *)request fields:(NSDictionary *)fields error:(NSString *)error {
    [self.pending removeObject:request];
    [request finishWithFields:fields errorCode:error];
}
- (void)prepare:(TrustedCallerSurfaceOwner *)owner linked:(BOOL)linked reply:(TrustedCallerSurfaceReply)reply {
    if (![owner matchesAccountMetadata:self.accountOwner.metadata]) {
        reply(nil, @"SDK_ACCOUNT_INVALID");
        return;
    }
    if (![self.owner matches:owner]) { [self close]; self.owner = owner; }
    self.ready = NO;
    TrustedCallerSurfaceRequest *request = [self request:owner reply:reply];
    if (!linked) {
        [self finish:request fields:@{@"linked": @NO, @"configured": @NO,
            @"sdkVersion": TrustedCallerSDKAvailability.sdkVersion} error:nil];
        return;
    }
    __weak typeof(self) weakSelf = self;
    __weak TrustedCallerSurfaceRequest *weakRequest = request;
    [TrustedCallerSdkClient.sharedClient initializeWithCompletion:^(BOOL success) {
        TrustedCallerSettingsSurface *surface = weakSelf;
        TrustedCallerSurfaceRequest *current = weakRequest;
        if (!surface || !current || current.completed) return;
        if (![surface.owner matches:current.owner] ||
            ![current.owner matchesAccountMetadata:surface.accountOwner.metadata]) {
            [surface finish:current fields:nil error:@"SDK_SURFACE_CLOSED"];
            return;
        }
        surface.ready = success;
        [surface finish:current fields:@{@"linked": @YES, @"configured": @(success),
            @"needsIntroduction": @NO, // Native flow owns first-use introduction.
            @"sdkVersion": TrustedCallerSDKAvailability.sdkVersion} error:nil];
    }];
}
- (BOOL)readyFor:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    if (self.ready && [self.owner matches:owner] &&
        [owner matchesAccountMetadata:self.accountOwner.metadata]) return YES;
    reply(nil, @"SDK_NOT_CONFIGURED");
    return NO;
}
- (NSString *)legacyGuideKey:(TrustedCallerSurfaceOwner *)owner {
    NSData *scope = [[NSString stringWithFormat:@"%@:%@", owner.metadata[@"environment"],
        owner.metadata[@"accountId"]] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(scope.bytes, (CC_LONG)scope.length, digest);
    NSMutableString *key = [@"trusted_caller.guide.v1." mutableCopy];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [key appendFormat:@"%02x", digest[i]];
    return key;
}
- (NSString *)guideKey:(TrustedCallerSurfaceOwner *)owner {
    NSData *scope = [owner.metadata[@"accountId"] dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(scope.bytes, (CC_LONG)scope.length, digest);
    NSMutableString *key = [@"trusted_caller.guide.v2." mutableCopy];
    for (NSUInteger i = 0; i < sizeof(digest); i++) [key appendFormat:@"%02x", digest[i]];
    return key;
}
- (BOOL)needsIntroduction:(TrustedCallerSurfaceOwner *)owner {
    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    if ([defaults boolForKey:[self legacyGuideKey:owner]]) {
        [defaults setBool:YES forKey:[self guideKey:owner]];
    }
    return ![defaults boolForKey:[self guideKey:owner]];
}
- (void)readStatus:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    if (![self readyFor:owner reply:reply]) return;
    TrustedCallerSurfaceRequest *request = [self request:owner reply:reply];
    __weak typeof(self) weakSelf = self;
    __weak TrustedCallerSurfaceRequest *weakRequest = request;
    [TrustedCallerSdkClient.sharedClient readAuthorization:^(NSDictionary *report) {
        TrustedCallerSettingsSurface *surface = weakSelf;
        TrustedCallerSurfaceRequest *current = weakRequest;
        if (!surface || !current || current.completed) return;
        if (![surface.owner matches:current.owner]) {
            [surface finish:current fields:nil error:@"SDK_SURFACE_CLOSED"];
            return;
        }
        NSMutableDictionary *fields = report.mutableCopy;
        fields[@"needsIntroduction"] = @NO;
        [surface finish:current fields:fields error:nil];
    }];
}
- (void)markIntroductionSeen:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    if (![self readyFor:owner reply:reply]) return;
    [NSUserDefaults.standardUserDefaults setBool:YES forKey:[self guideKey:owner]];
    reply([owner reportWithFields:@{@"needsIntroduction": @NO}], nil);
}
- (void)openSettings:(TrustedCallerSurfaceOwner *)owner reply:(TrustedCallerSurfaceReply)reply {
    if (![self readyFor:owner reply:reply]) return;
    if (self.openRequest || !self.host.viewIfLoaded.window || self.host.presentedViewController) {
        reply(nil, @"SDK_SURFACE_BUSY");
        return;
    }
#if !TARGET_OS_SIMULATOR
    NSString *phone = TrustedCallerNormalizedPhone(owner.metadata[@"phone"]);
    if (phone.length == 0) { reply(nil, @"SDK_PHONE_INVALID"); return; }
    TrustedCallerSurfaceRequest *request = [self request:owner reply:reply];
    self.openRequest = request;
    __weak typeof(self) weakSelf = self;
    __weak TrustedCallerSurfaceRequest *weakRequest = request;
    TrustedCallerDismissProxy *proxy = [[TrustedCallerDismissProxy alloc] init];
    proxy.onExit = ^{
        TrustedCallerSettingsSurface *surface = weakSelf;
        TrustedCallerSurfaceRequest *current = weakRequest;
        if (current && !current.completed && surface.openRequest == current &&
            [surface.owner matches:current.owner]) [surface finishPresentation:current];
    };
    @try {
        UIViewController *(^makeSettings)(void) = ^UIViewController * {
            KXSetViewController *controller = [[KXSetViewController alloc] init];
            controller.delegate = proxy;
            [controller setInitKxSDKWithIsShowIntroPage:NO isMobileNumber:YES
                mobileNumber:phone jiguangRid:@""
                deviceToken:TrustedCallerPushRegistration.sharedRegistration.deviceToken ?: @""];
            return controller;
        };
        BOOL firstUse = [self needsIntroduction:owner];
        UIViewController *root = firstUse ? nil : makeSettings();
        if (firstUse) {
            [NSUserDefaults.standardUserDefaults setBool:YES forKey:[self guideKey:owner]];
            TrustedCallerNativeIntroduction *intro = [[TrustedCallerNativeIntroduction alloc] init];
            __weak TrustedCallerNativeIntroduction *weakIntro = intro;
            intro.isCurrent = ^BOOL {
                TrustedCallerSettingsSurface *surface = weakSelf;
                return surface && [surface.owner matches:owner] &&
                    [owner matchesAccountMetadata:surface.accountOwner.metadata];
            };
            intro.onStart = ^{
                @try {
                    UIViewController *controller = makeSettings();
                    controller.hidesBottomBarWhenPushed = YES;
                    [weakIntro.navigationController pushViewController:controller animated:YES];
                } @catch (NSException *exception) {
                    TrustedCallerSettingsSurface *surface = weakSelf;
                    [surface close];
                }
            };
            intro.onExit = proxy.onExit;
            root = intro;
        }
        UINavigationController *navigation = [[UINavigationController alloc] initWithRootViewController:root];
        navigation.navigationBarHidden = YES;
        navigation.modalPresentationStyle = UIModalPresentationFullScreen;
        self.navigation = navigation;
        self.dismissProxy = proxy;
        navigation.presentationController.delegate = proxy;
        [self.host presentViewController:navigation animated:YES completion:nil];
    } @catch (NSException *exception) {
        UINavigationController *navigation = self.navigation;
        [self closePresentation];
        if (navigation.presentingViewController) [navigation dismissViewControllerAnimated:NO completion:nil];
        [self finish:request fields:nil error:@"SDK_OPEN_FAILED"];
    }
#else
    reply(nil, @"SDK_NOT_CONFIGURED");
#endif
}
- (void)finishPresentation:(TrustedCallerSurfaceRequest *)request {
    UINavigationController *navigation = self.navigation;
    [self closePresentation];
    void (^finish)(void) = ^{
        if (request.completed) return;
        if ([self.owner matches:request.owner]) [self finish:request fields:@{} error:nil];
        else [self finish:request fields:nil error:@"SDK_SURFACE_CLOSED"];
    };
    if (navigation.presentingViewController) [navigation dismissViewControllerAnimated:YES completion:finish];
    else finish();
}
- (void)closePresentation {
    [self.identityOverlay close];
    self.dismissProxy.onExit = nil;
    self.dismissProxy = nil;
    self.navigation = nil;
    self.openRequest = nil;
}
- (void)releaseSurface:(TrustedCallerSurfaceOwner *)owner { if ([self.owner matches:owner]) [self close]; }
- (void)close {
    UINavigationController *navigation = self.navigation;
    [self closePresentation];
    self.owner = nil;
    self.ready = NO;
    NSArray *requests = self.pending.copy;
    [self.pending removeAllObjects];
    for (TrustedCallerSurfaceRequest *request in requests) {
        [request finishWithFields:nil errorCode:@"SDK_SURFACE_CLOSED"];
    }
    if (navigation.presentingViewController) [navigation dismissViewControllerAnimated:NO completion:nil];
}
@end
