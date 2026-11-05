#import "TrustedCallerSdkClient.h"
#import "TrustedCallerConfiguration.h"
#import "TrustedCallerSDKAvailability.h"
#import "TrustedCallerAuthorizationEvidence.h"
#import "TrustedCallerPhoneNumber.h"
#import "TrustedCallerIdentityEvidence.h"
#import <TargetConditionals.h>
#import "TrustedCallerIncomingDiagnostics.h"
#import "TrustedCallerAvatarLoader.h"
#if !TARGET_OS_SIMULATOR
#import <KXSDK/ChakenSdk.h>
#endif

@interface TrustedCallerSdkClient ()
@property (nonatomic) BOOL initialized;
@property (nonatomic) BOOL initializing;
@property (nonatomic) NSUInteger initializationGeneration;
@property (nonatomic, strong) NSMutableArray *pending;
@end

@implementation TrustedCallerSdkClient
+ (instancetype)sharedClient {
    static TrustedCallerSdkClient *client;
    static dispatch_once_t once;
    dispatch_once(&once, ^{ client = [[self alloc] init]; });
    return client;
}
- (instancetype)init {
    if ((self = [super init])) _pending = [NSMutableArray array];
    return self;
}
- (void)initializeWithCompletion:(void (^)(BOOL))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self initializeWithCompletion:completion]; });
        return;
    }
    if (self.initialized) { completion(YES); return; }
    NSDictionary *credentials = TrustedCallerConfiguration.credentials;
    if (!TrustedCallerSDKAvailability.isDeviceSDKLinked || !credentials) {
        completion(NO);
        return;
    }
    [self.pending addObject:[completion copy]];
    if (self.initializing) return;
    self.initializing = YES;
    NSUInteger generation = ++self.initializationGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        [self finishInitialization:NO generation:generation];
    });
#if !TARGET_OS_SIMULATOR
    @try {
        [[ChakenSdk sharedInstance] setAppKey:credentials[@"appKey"]
            AppSecret:credentials[@"appSecret"] callback:^(NSInteger code, NSDictionary *data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                [self finishInitialization:code == 1 generation:generation];
            });
        }];
    } @catch (NSException *exception) {
        [self finishInitialization:NO generation:generation];
    }
#else
    [self finishInitialization:NO generation:generation];
#endif
}
- (void)finishInitialization:(BOOL)success generation:(NSUInteger)generation {
    if (!self.initializing || generation != self.initializationGeneration) return;
    self.initializing = NO;
    self.initialized = success;
    NSArray *callbacks = self.pending.copy;
    [self.pending removeAllObjects];
    for (void (^callback)(BOOL) in callbacks) callback(success);
}
- (void)verifyIncomingPayload:(TrustedCallerIncomingPayload *)payload
    completion:(void (^)(NSInteger, NSDictionary *))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self verifyIncomingPayload:payload completion:completion]; });
        return;
    }
    if (!self.initialized || ![payload isKindOfClass:TrustedCallerIncomingPayload.class]) {
        completion(0, nil);
        return;
    }
    __block BOOL finished = NO;
    void (^finish)(NSInteger, NSDictionary *) = ^(NSInteger code, NSDictionary *evidence) {
        if (finished) return;
        finished = YES;
        completion(code, evidence);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        finish(0, nil);
    });
#if !TARGET_OS_SIMULATOR
    NSDictionary *arguments = payload.sdkArguments;
    @try {
        [[ChakenSdk sharedInstance] parseIdentityToken:arguments[@"token"]
            callerPhone:arguments[@"caller"] calledPhoneStr:arguments[@"called"]
            sequence:arguments[@"sequence"] callback:^(NSInteger code, NSDictionary *data) {
            dispatch_async(dispatch_get_main_queue(), ^{
                if (finished) return;
                NSDictionary *evidence = [TrustedCallerIdentityEvidence reportForCode:code data:data payload:payload];
                BOOL verified = [@[@"verified", @"uncertified"] containsObject:evidence[@"verification"]];
                NSDictionary *identity = [data isKindOfClass:NSDictionary.class] ? data : nil;
                if ([identity[@"data"] isKindOfClass:NSDictionary.class]) identity = identity[@"data"];
                id avatar = payload.avatarURL;
                if (verified) for (NSString *key in @[@"personalPhotoUrl", @"companyPhotoUrl", @"picUrl", @"avatarUrl"]) {
                    if ([identity[key] isKindOfClass:NSString.class] && [identity[key] length]) { avatar = identity[key]; break; }
                }
                [TrustedCallerAvatarLoader loadValue:avatar completion:^(NSData *image) {
                    if (finished) return;
                    NSMutableDictionary *display = evidence.mutableCopy;
                    if (image) display[@"avatarData"] = image;
                    [TrustedCallerIncomingDiagnostics.shared recordStage:@"incomingAvatar"
                        code:image ? @"IOS_AVATAR_SUCCEEDED" : @"IOS_AVATAR_FALLBACK" result:image ? @"succeeded" : @"received"];
                    finish(verified ? 1 : 0, display);
                }];
            });
        }];
    } @catch (NSException *exception) { finish(0, nil); }
#else
    finish(0, nil);
#endif
}
- (void)performPushBindingAction:(NSDictionary *)action completion:(void (^)(BOOL))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self performPushBindingAction:action completion:completion]; });
        return;
    }
    NSDictionary *binding = [action[@"binding"] isKindOfClass:NSDictionary.class] ? action[@"binding"] : nil;
    NSString *phone = TrustedCallerNormalizedPhone(binding[@"phone"]), *token = binding[@"deviceToken"];
    BOOL unbind = [action[@"operation"] isEqual:@"unbind"];
    BOOL bind = [action[@"operation"] isEqual:@"bind"];
    if (!self.initialized || (!bind && !unbind) ||
        ![binding[@"environment"] isEqual:TrustedCallerSDKAvailability.sdkEnvironment] ||
        ![phone isKindOfClass:NSString.class] || phone.length == 0 ||
        ![token isKindOfClass:NSString.class] || token.length != 64) {
        completion(NO);
        return;
    }
    [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding" code:unbind ? @"IOS_UNBIND_STARTED" : @"IOS_BIND_STARTED" result:@"started"];
    __block BOOL finished = NO;
    void (^finish)(BOOL) = ^(BOOL success) {
        if (finished) return;
        finished = YES;
        [TrustedCallerIncomingDiagnostics.shared recordStage:@"pushBinding"
            code:unbind ? (success ? @"IOS_UNBIND_SUCCEEDED" : @"IOS_UNBIND_FAILED") :
                (success ? @"IOS_BIND_SUCCEEDED" : @"IOS_BIND_FAILED")
            result:success ? @"succeeded" : @"failed"];
        completion(success);
    };
    // No timeout replay: an unresolved SDK request retains the serial account gate.
#if !TARGET_OS_SIMULATOR
    @try {
        [[ChakenSdk sharedInstance] bindRid:phone JiguangRid:unbind ? @" " : @""
            deviceToken:unbind ? @" " : token callback:^(NSInteger code, NSDictionary *data) {
            dispatch_async(dispatch_get_main_queue(), ^{ finish(code == 1); });
        }];
    } @catch (NSException *exception) { finish(NO); }
#else
    finish(NO);
#endif
}
- (void)readAuthorization:(void (^)(NSDictionary<NSString *, id> *))completion {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{ [self readAuthorization:completion]; });
        return;
    }
    if (!self.initialized) {
        completion([TrustedCallerAuthorizationEvidence reportForCode:0 data:nil]);
        return;
    }
    __block BOOL finished = NO;
    void (^finish)(NSDictionary *) = ^(NSDictionary *report) {
        if (finished) return;
        finished = YES;
        completion(report);
    };
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        finish([TrustedCallerAuthorizationEvidence reportForCode:0 data:nil]);
    });
#if !TARGET_OS_SIMULATOR
    @try {
        [[ChakenSdk sharedInstance] sdkAuthLogCallback:^(NSInteger code, NSDictionary *data) {
            NSDictionary *report = [TrustedCallerAuthorizationEvidence reportForCode:code data:data];
            dispatch_async(dispatch_get_main_queue(), ^{ finish(report); });
        }];
    } @catch (NSException *exception) {
        finish([TrustedCallerAuthorizationEvidence reportForCode:0 data:nil]);
    }
#else
    finish([TrustedCallerAuthorizationEvidence reportForCode:0 data:nil]);
#endif
}
@end
