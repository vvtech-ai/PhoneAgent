#import "ClonePreviewAudioSession.h"
#import <AVFoundation/AVFoundation.h>
#import <CallKit/CallKit.h>
#import <UIKit/UIKit.h>

@implementation ClonePreviewAudioSession
+ (NSDictionary *)sessionState:(AVAudioSession *)session {
    NSDictionary *categories = @{
        AVAudioSessionCategoryPlayback: @"playback",
        AVAudioSessionCategoryPlayAndRecord: @"playAndRecord",
        AVAudioSessionCategoryRecord: @"record",
        AVAudioSessionCategoryAmbient: @"ambient",
        AVAudioSessionCategorySoloAmbient: @"soloAmbient",
        AVAudioSessionCategoryMultiRoute: @"multiRoute"
    };
    NSDictionary *modes = @{
        AVAudioSessionModeDefault: @"default",
        AVAudioSessionModeVoiceChat: @"voiceChat",
        AVAudioSessionModeVideoChat: @"videoChat",
        AVAudioSessionModeMeasurement: @"measurement"
    };
    return @{@"sessionCategory": categories[session.category] ?: @"other",
             @"sessionMode": modes[session.mode] ?: @"other",
             @"sessionOptions": @(session.categoryOptions)};
}
+ (void)prepareWithResult:(FlutterResult)result canPrepare:(BOOL (^)(void))canPrepare {
    [self prepareAttempt:0 result:result canPrepare:canPrepare];
}
+ (void)prepareAttempt:(NSUInteger)attempt result:(FlutterResult)result canPrepare:(BOOL (^)(void))canPrepare {
    // Called under the Flutter media lease, after actual capture release.
    CXCallObserver *observer = [CXCallObserver new];
    BOOL callActive = NO;
    for (CXCall *call in observer.calls) if (!call.hasEnded) callActive = YES;
    if (!canPrepare() || UIApplication.sharedApplication.applicationState != UIApplicationStateActive || callActive) {
        result([FlutterError errorWithCode:@"preview_audio_busy"
            message:@"Audio playback is currently unavailable" details:nil]);
        return;
    }
    AVAudioSession *session = AVAudioSession.sharedInstance;
    NSError *error = nil;
    NSString *step = @"setCategory";
    NSDictionary *state = [self sessionState:session];
    BOOL ready = YES;
    if ([session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord] ||
        [session.category isEqualToString:AVAudioSessionCategoryRecord]) {
        // The capture lease has ended. Deactivate its recording session before
        // changing category; never claim a failed deactivation released audio.
        step = @"deactivate";
        ready = [session setActive:NO
            withOptions:AVAudioSessionSetActiveOptionNotifyOthersOnDeactivation error:&error];
    }
    // Match the native AIAssistant preview's category-only configuration.
    if (ready) {
        step = @"setCategory";
        state = [self sessionState:session];
        ready = [session setCategory:AVAudioSessionCategoryPlayback error:&error];
    }
    if (ready) {
        step = @"setActive";
        state = [self sessionState:session];
        ready = [session setActive:YES error:&error];
    }
    if (ready) { result(nil); return; }
    if (attempt < 2 && error.code == AVAudioSessionErrorCodeInsufficientPriority) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 150 * NSEC_PER_MSEC), dispatch_get_main_queue(), ^{
            [self prepareAttempt:attempt + 1 result:result canPrepare:canPrepare];
        });
        return;
    }
    NSMutableDictionary *details = [state mutableCopy];
    details[@"nativeStep"] = step;
    details[@"nativeAttempt"] = @(attempt + 1);
    details[@"errorDomain"] = error.domain ?: @"";
    details[@"nativeCode"] = @(error.code);
    result([FlutterError errorWithCode:@"DarwinAudioError"
        message:@"Could not prepare preview audio session"
        details:details]);
}
@end
