#import <Foundation/Foundation.h>
#import "IdentityCaptureAudioConfiguration.h"

@interface SessionFake : NSObject <IdentityCaptureAudioSession>
@property(nonatomic) AVAudioSessionRecordPermission recordPermission;
@property(nonatomic) NSUInteger calls;
@property(nonatomic) BOOL fail;
@property(nonatomic, copy) NSString *category;
@property(nonatomic, copy) NSString *mode;
@property(nonatomic) AVAudioSessionCategoryOptions options;
@end
@implementation SessionFake
- (BOOL)setCategory:(AVAudioSessionCategory)category mode:(AVAudioSessionMode)mode
            options:(AVAudioSessionCategoryOptions)options error:(NSError **)error {
    self.calls++;
    self.category = category; self.mode = mode; self.options = options;
    if (self.fail && error) *error = [NSError errorWithDomain:@"synthetic" code:1 userInfo:nil];
    return !self.fail;
}
@end

static void check(BOOL value, NSString *message) {
    if (!value) { fprintf(stderr, "FAIL: %s\n", message.UTF8String); exit(1); }
}
int main(void) {
    @autoreleasepool {
        SessionFake *session = [SessionFake new];
        IdentityCaptureAudioConfiguration *audio = [[IdentityCaptureAudioConfiguration alloc] initWithSession:session];
        check(session.calls == 0, @"construction is inert");
        session.recordPermission = AVAudioSessionRecordPermissionUndetermined;
        check(![audio prepare:nil] && session.calls == 0, @"unrequested permission cannot configure");
        session.recordPermission = AVAudioSessionRecordPermissionDenied;
        check(![audio prepare:nil] && session.calls == 0, @"denied permission cannot configure");
        session.recordPermission = AVAudioSessionRecordPermissionGranted;
        session.category = AVAudioSessionCategoryPlayback;
        session.mode = AVAudioSessionModeVoiceChat;
        session.options = AVAudioSessionCategoryOptionAllowBluetooth;
        check([audio prepare:nil] && session.calls == 1, @"authorized capture configures once");
        check([session.category isEqualToString:AVAudioSessionCategoryPlayAndRecord] &&
              [session.mode isEqualToString:AVAudioSessionModeDefault] &&
              session.options == AVAudioSessionCategoryOptionDefaultToSpeaker, @"old playback/chat/bluetooth settings replaced");
        check([audio prepare:nil] && session.calls == 1, @"no reconfiguration while SDK owns audio");
        [audio releaseAfterCapture];
        check(session.calls == 1, @"release never restores stale global audio");
        session.fail = YES;
        NSError *error = nil;
        check(![audio prepare:&error] && error != nil && session.calls == 2, @"config failure prevents successful admission");
        session.fail = NO;
        check([audio prepare:nil] && session.calls == 3, @"explicit subsequent capture can retry");
        [audio releaseAfterCapture];
        check([audio prepare:nil] && session.calls == 4, @"next SDK session configures freshly");
        printf("Identity audio: 10 assertions passed; no SDK or real audio accessed.\n");
    }
    return 0;
}
