#import "TrustedCallerPlugin.h"
#import "TrustedCallerSDKAvailability.h"
#import "TrustedCallerSettingsSurface.h"
#import "TrustedCallerPushRegistration.h"
#import "TrustedCallerIncomingSession.h"
#import "TrustedCallerSdkClient.h"
#import "TrustedCallerNotificationRelay.h"
#import "TrustedCallerSystemCallObserver.h"
#import "TrustedCallerIdentityLink.h"
#import "TrustedCallerIncomingDiagnostics.h"
static TrustedCallerIncomingSession *latestIncoming;
static NSUInteger latestConsumer;
static TrustedIncomingReport activityReportObserver;

@interface TrustedCallerPlugin () <FlutterStreamHandler>
@property (nonatomic, strong) TrustedCallerSettingsSurface *surface;
@property (nonatomic) NSUInteger accountConsumer;
@property (nonatomic, strong) TrustedCallerIncomingSession *incoming;
@property (nonatomic, strong) TrustedCallerSystemCallObserver *callObserver;
@end
@implementation TrustedCallerPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [self registerWithRegistrar:registrar host:nil];
}
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar host:(UIViewController *)host {
    FlutterMethodChannel *channel = [FlutterMethodChannel
        methodChannelWithName:@"phone_agent/trusted_caller" binaryMessenger:registrar.messenger];
    TrustedCallerPlugin *plugin = [[self alloc] init];
    plugin.surface = [[TrustedCallerSettingsSurface alloc] initWithHost:host];
    [plugin.surface configureIdentityOverlayWithMessenger:registrar.messenger];
    [registrar addMethodCallDelegate:plugin channel:channel];
    plugin.accountConsumer = [TrustedCallerPushRegistration.sharedRegistration attachConsumer];
    [TrustedCallerIncomingDiagnostics.shared attachConsumer:plugin.accountConsumer];
    static TrustedCallerIncomingSession *incoming;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        incoming = [[TrustedCallerIncomingSession alloc]
            initWithBootstrap:^(void (^completion)(BOOL)) {
                [TrustedCallerSdkClient.sharedClient initializeWithCompletion:completion];
            } parse:^(TrustedCallerIncomingPayload *payload, void (^completion)(NSInteger, id)) {
                [TrustedCallerSdkClient.sharedClient verifyIncomingPayload:payload completion:completion];
            }];
    });
    plugin.incoming = incoming;
    [incoming attachConsumer:plugin.accountConsumer];
    latestIncoming = incoming;
    latestConsumer = plugin.accountConsumer;
    [incoming setLifecycleListener:activityReportObserver forKey:@"activity" consumer:latestConsumer];
    plugin.callObserver = [[TrustedCallerSystemCallObserver alloc] initWithSession:incoming consumer:plugin.accountConsumer];
    __weak TrustedCallerPlugin *weakPlugin = plugin;
    [TrustedCallerNotificationRelay.sharedRelay attachConsumer:plugin.accountConsumer receive:^BOOL(NSDictionary *userInfo) {
        TrustedCallerPlugin *current = weakPlugin;
        if (!current) return NO;
        return [current.incoming receiveUserInfo:userInfo now:NSDate.date.timeIntervalSince1970
            consumer:current.accountConsumer completion:^(BOOL verified) {}];
    }];
    FlutterEventChannel *events = [FlutterEventChannel
        eventChannelWithName:@"phone_agent/trusted_caller_incoming" binaryMessenger:registrar.messenger];
    [events setStreamHandler:plugin];
    [registrar addApplicationDelegate:plugin];
    [registrar publish:plugin];
}
- (void)handleMethodCall:(FlutterMethodCall *)call result:(FlutterResult)result {
    if ([call.method isEqual:@"incomingEventsAvailable"]) {
        NSDictionary *arguments = [call.arguments isKindOfClass:NSDictionary.class] ? call.arguments : nil;
        BOOL available = [arguments[@"environment"] isEqual:TrustedCallerSDKAvailability.sdkEnvironment] &&
            TrustedCallerSDKAvailability.isDeviceSDKLinked;
        result(available ? @YES : @NO);
        return;
    }
    if ([call.method isEqual:@"updateAccount"]) {
        if (![TrustedCallerPushRegistration.sharedRegistration isCurrentConsumer:self.accountConsumer]) {
            result([FlutterError errorWithCode:@"SDK_ACCOUNT_INVALID" message:@"Invalid SDK account" details:nil]);
            return;
        }
        NSDictionary *request = [TrustedCallerSurfaceOwner accountRequestFromArguments:call.arguments
            expectedEnvironment:TrustedCallerSDKAvailability.sdkEnvironment];
        if (!request) {
            result([FlutterError errorWithCode:@"SDK_ACCOUNT_INVALID" message:@"Invalid SDK account" details:nil]);
            return;
        }
        NSDictionary *metadata = request[@"owner"] == NSNull.null ? nil : request[@"owner"];
        [self.surface updateAccount:metadata];
        [TrustedCallerPushRegistration.sharedRegistration updateOwner:metadata consumer:self.accountConsumer];
        [self.incoming updateOwner:metadata consumer:self.accountConsumer];
        result(nil);
        return;
    }
    if (![@[@"prepare", @"readStatus", @"markIntroductionSeen", @"openSettings", @"releaseSurface"]
            containsObject:call.method]) { result(FlutterMethodNotImplemented); return; }
    if (![call.method isEqual:@"releaseSurface"] &&
        ![TrustedCallerPushRegistration.sharedRegistration isCurrentConsumer:self.accountConsumer]) {
        result([FlutterError errorWithCode:@"SDK_ACCOUNT_INVALID" message:@"Invalid SDK account" details:nil]);
        return;
    }
    TrustedCallerSurfaceOwner *owner = [TrustedCallerSurfaceOwner ownerFromArguments:call.arguments];
    if (!owner || ![owner.metadata[@"environment"] isEqual:TrustedCallerSDKAvailability.sdkEnvironment]) {
        result([FlutterError errorWithCode:@"SDK_SURFACE_INVALID" message:@"Invalid SDK surface" details:nil]);
        return;
    }
    TrustedCallerSurfaceReply reply = ^(NSDictionary *report, NSString *error) {
        if (error) result([FlutterError errorWithCode:error message:@"SDK surface is unavailable" details:nil]);
        else result(report);
    };
    if ([call.method isEqualToString:@"prepare"]) {
        [self.surface prepare:owner linked:TrustedCallerSDKAvailability.isDeviceSDKLinked reply:reply];
    } else if ([call.method isEqualToString:@"readStatus"]) {
        [self.surface readStatus:owner reply:reply];
    } else if ([call.method isEqualToString:@"markIntroductionSeen"]) {
        [self.surface markIntroductionSeen:owner reply:reply];
    } else if ([call.method isEqualToString:@"openSettings"]) {
        [TrustedCallerPushRegistration.sharedRegistration retryForOwner:owner.metadata];
        [self.surface openSettings:owner reply:reply];
    } else {
        [self.surface releaseSurface:owner];
        result(nil);
    }
}
- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [TrustedCallerPushRegistration.sharedRegistration requestStartupAuthorization];
    id payload = launchOptions[UIApplicationLaunchOptionsRemoteNotificationKey];
    if ([payload isKindOfClass:NSDictionary.class]) {
        [TrustedCallerPlugin recordIncomingStage:@"incomingReceive" code:@"IOS_PUSH_COLD" result:@"received"];
        [self.incoming receiveUserInfo:payload now:NSDate.date.timeIntervalSince1970
            consumer:self.accountConsumer completion:^(BOOL verified) {}];
    }
    return YES;
}
- (void)application:(UIApplication *)application didRegisterForRemoteNotificationsWithDeviceToken:(NSData *)deviceToken {
    [TrustedCallerPushRegistration.sharedRegistration receivedDeviceToken:deviceToken];
}
+ (void)recordIncomingStage:(NSString *)stage code:(NSString *)code result:(NSString *)result {
    [TrustedCallerIncomingDiagnostics.shared recordStage:stage code:code result:result];
}
+ (void)installNotificationRelay { [TrustedCallerNotificationRelay.sharedRelay install]; }
+ (void)setActivityReportObserver:(void (^)(NSDictionary *))observer {
    activityReportObserver = [observer copy];
    [latestIncoming setLifecycleListener:activityReportObserver forKey:@"activity" consumer:latestConsumer];
}
+ (BOOL)reopenIncomingNotification:(NSDictionary *)userInfo {
    return [latestIncoming reopenNotification:userInfo consumer:latestConsumer];
}
+ (BOOL)handleTrustedIdentityURL:(NSURL *)url {
    NSString *eventId = TrustedCallerEventIdFromURL(url);
    return eventId && [latestIncoming requestPresentationForEventId:eventId consumer:latestConsumer now:NSDate.date.timeIntervalSince1970];
}
- (void)application:(UIApplication *)application didFailToRegisterForRemoteNotificationsWithError:(NSError *)error {
    [TrustedCallerPushRegistration.sharedRegistration receivedRegistrationError:error];
}
- (void)applicationDidBecomeActive:(UIApplication *)application {
    [TrustedCallerNotificationRelay.sharedRelay install];
}
- (FlutterError *)onListenWithArguments:(id)arguments eventSink:(FlutterEventSink)events {
    [TrustedCallerIncomingDiagnostics.shared listen:events consumer:self.accountConsumer];
    [TrustedCallerPushRegistration.sharedRegistration recordBindingSnapshotForConsumer:self.accountConsumer];
    [self.incoming listen:^(NSDictionary *report) {
        if (!report) { events(nil); return; }
        NSMutableDictionary *value = report.mutableCopy;
        NSMutableDictionary *identity = [report[@"identity"] mutableCopy];
        NSData *image = identity[@"avatarData"];
        if ([image isKindOfClass:NSData.class]) identity[@"avatarData"] = [FlutterStandardTypedData typedDataWithBytes:image];
        value[@"identity"] = identity;
        events(value);
    } consumer:self.accountConsumer];
    return nil;
}
- (FlutterError *)onCancelWithArguments:(id)arguments {
    [TrustedCallerIncomingDiagnostics.shared listen:nil consumer:self.accountConsumer];
    [self.incoming cancelListener:self.accountConsumer];
    return nil;
}
- (BOOL)application:(UIApplication *)application didReceiveRemoteNotification:(NSDictionary *)userInfo
    fetchCompletionHandler:(void (^)(UIBackgroundFetchResult))completionHandler {
    [TrustedCallerPlugin recordIncomingStage:@"incomingReceive" code:@"IOS_PUSH_BACKGROUND" result:@"received"];
    return [self.incoming receiveUserInfo:userInfo now:NSDate.date.timeIntervalSince1970
        consumer:self.accountConsumer completion:^(BOOL verified) {
            completionHandler(verified ? UIBackgroundFetchResultNewData : UIBackgroundFetchResultNoData);
        }];
}
- (void)detachFromEngineForRegistrar:(NSObject<FlutterPluginRegistrar> *)registrar {
    [self.callObserver stop];
    [self.surface close];
    [TrustedCallerPushRegistration.sharedRegistration detachConsumer:self.accountConsumer];
    [self.incoming attachConsumer:self.accountConsumer + 1];
    [TrustedCallerNotificationRelay.sharedRelay detachConsumer:self.accountConsumer];
}
@end
