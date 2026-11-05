#import <AVFoundation/AVFoundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Only the owning capture may configure, immediately before starting the SDK.
@protocol IdentityCaptureAudioSession <NSObject>
@property(nonatomic, readonly) AVAudioSessionRecordPermission recordPermission;
- (BOOL)setCategory:(AVAudioSessionCategory)category
               mode:(AVAudioSessionMode)mode
            options:(AVAudioSessionCategoryOptions)options
              error:(NSError * _Nullable * _Nullable)error;
@end

@interface IdentityCaptureAudioConfiguration : NSObject
- (instancetype)initWithSession:(id<IdentityCaptureAudioSession>)session;
- (BOOL)prepare:(NSError * _Nullable * _Nullable)error;
/// Clear ownership after actual SDK release. Do not reconfigure global audio.
- (void)releaseAfterCapture;
@end

NS_ASSUME_NONNULL_END
