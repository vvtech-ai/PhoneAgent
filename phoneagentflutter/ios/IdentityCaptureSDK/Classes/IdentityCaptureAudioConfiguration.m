#import "IdentityCaptureAudioConfiguration.h"

@interface IdentityCaptureAudioConfiguration ()
@property(nonatomic, strong) id<IdentityCaptureAudioSession> session;
@property(nonatomic, assign) BOOL configured;
@end

@implementation IdentityCaptureAudioConfiguration
- (instancetype)initWithSession:(id<IdentityCaptureAudioSession>)session {
    if ((self = [super init])) _session = session;
    return self;
}
- (BOOL)prepare:(NSError **)error {
    if (self.configured) return YES;
    if (self.session.recordPermission != AVAudioSessionRecordPermissionGranted) return NO;
    // Match the native adapter; SDK owns activation. Never reuse VoiceChat,
    // Measurement or Bluetooth settings left by an earlier media consumer.
    self.configured = [self.session setCategory:AVAudioSessionCategoryPlayAndRecord
                                          mode:AVAudioSessionModeDefault
                                       options:AVAudioSessionCategoryOptionDefaultToSpeaker
                                         error:error];
    return self.configured;
}
- (void)releaseAfterCapture {
    // Restoring a stale snapshot could overwrite the next consumer's session.
    // The next lease owner must explicitly configure its own audio instead.
    self.configured = NO;
}
@end
