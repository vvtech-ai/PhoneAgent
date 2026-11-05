#import "IdentityCaptureTrace.h"
#import <PhoneAgentCrashDiagnostics/PAIdentityTrace.h>
#import <UIKit/UIKit.h>
#import <AVFoundation/AVFoundation.h>

// Observe only: never activate, deactivate, interrupt, or reconfigure audio.
@implementation IdentityCaptureTrace {
    NSMutableArray *_tokens;
}
- (instancetype)initWithSession:(NSString *)session actor:(NSString *)actor {
    if ((self = [super init])) {
        _tokens = [NSMutableArray new];
        NSDictionary *names = @{
            UIApplicationWillResignActiveNotification:@"app.inactive",
            UIApplicationDidEnterBackgroundNotification:@"app.background",
            UIApplicationWillEnterForegroundNotification:@"app.foreground",
            UIApplicationDidBecomeActiveNotification:@"app.active",
            UIApplicationWillTerminateNotification:@"app.terminate",
            UIApplicationDidReceiveMemoryWarningNotification:@"app.memoryWarning",
            AVAudioSessionInterruptionNotification:@"audio.interruption",
            AVAudioSessionRouteChangeNotification:@"audio.routeChange",
            AVAudioSessionMediaServicesWereLostNotification:@"audio.mediaLost",
            AVAudioSessionMediaServicesWereResetNotification:@"audio.mediaReset"};
        for (NSString *name in names) {
            NSString *event = names[name];
            id token = [NSNotificationCenter.defaultCenter addObserverForName:name object:nil queue:nil usingBlock:^(NSNotification *notification) {
                NSInteger code = 0; NSUInteger flags = 0;
                if ([name isEqual:AVAudioSessionInterruptionNotification]) {
                    code = [notification.userInfo[AVAudioSessionInterruptionTypeKey] integerValue];
                    flags = [notification.userInfo[AVAudioSessionInterruptionOptionKey] unsignedIntegerValue] & 255;
                } else if ([name isEqual:AVAudioSessionRouteChangeNotification]) {
                    code = [notification.userInfo[AVAudioSessionRouteChangeReasonKey] integerValue];
                }
                [PAIdentityTrace record:event session:session actor:actor flags:flags code:code];
            }];
            [_tokens addObject:token];
        }
    }
    return self;
}
- (void)stop {
    for (id token in _tokens) [NSNotificationCenter.defaultCenter removeObserver:token];
    [_tokens removeAllObjects];
}
- (void)dealloc { [self stop]; }
@end
